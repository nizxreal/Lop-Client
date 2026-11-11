const express = require('express');
const cors = require('cors');
const { DatabaseSync } = require('node:sqlite');
const pino = require('pino');
const { 
    default: makeWASocket, 
    useMultiFileAuthState, 
    DisconnectReason,
    fetchLatestBaileysVersion
} = require('@whiskeysockets/baileys');
const fs = require('fs');
const path = require('path');

const app = express();
app.use(express.json());
app.use(cors());

// ponytail: SQLite for local; migrate to Postgres/Supabase when deploying to multi-instance cloud.
const db = new DatabaseSync(path.join(__dirname, 'database.sqlite'));
db.exec(`
    CREATE TABLE IF NOT EXISTS tokens (token TEXT PRIMARY KEY, email TEXT UNIQUE);
    CREATE TABLE IF NOT EXISTS bot_configs (email TEXT PRIMARY KEY, phone TEXT, prefix TEXT DEFAULT '!', custom_features TEXT);
`);

const sessions = new Map(); 
const pairingCodes = new Map();
const statuses = new Map();

async function connectToWhatsApp(email, phoneNumber = null) {
    if (sessions.has(email)) {
        return sessions.get(email);
    }

    const sessionDir = path.join(__dirname, 'sessions', email.replace(/[^a-zA-Z0-9]/g, '_'));
    if (!fs.existsSync(sessionDir)) fs.mkdirSync(sessionDir, { recursive: true });

    const { state, saveCreds } = await useMultiFileAuthState(sessionDir);
    const { version } = await fetchLatestBaileysVersion();

    const sock = makeWASocket({
        version,
        auth: state,
        logger: pino({ level: 'silent' }),
        browser: ['Ubuntu', 'Chrome', '120.0.0'],
        syncFullHistory: false
    });

    sessions.set(email, sock);
    sock.ev.on('creds.update', saveCreds);

    sock.ev.on('connection.update', async ({ connection, lastDisconnect }) => {
        if (connection === 'open') {
            console.log(`[WA] Terhubung ke WhatsApp untuk ${email}!`);
            statuses.set(email, 'connected');
            pairingCodes.delete(email);
        }

        if (connection === 'close') {
            const statusCode = lastDisconnect?.error?.output?.statusCode;
            console.log(`[WA] Sesi ${email} terputus (status code: ${statusCode})`);
            sessions.delete(email);

            if (statusCode === DisconnectReason.loggedOut) {
                statuses.set(email, 'logged_out');
                try { fs.rmSync(sessionDir, { recursive: true, force: true }); } catch (e) {}
                return;
            }

            statuses.set(email, 'reconnecting');
            console.log(`[WA] Menghubungkan ulang sesi ${email}...`);
            setTimeout(() => connectToWhatsApp(email, phoneNumber), 2000);
        }
    });

    if (!sock.authState.creds.registered && phoneNumber) {
        setTimeout(async () => {
            try {
                const cleanPhone = phoneNumber.replace(/\D/g, '');
                const code = await sock.requestPairingCode(cleanPhone);
                const formatted = code?.match(/.{1,4}/g)?.join('-') || code;
                pairingCodes.set(email, formatted);
                statuses.set(email, 'pairing');
                console.log(`[WA] Pairing code untuk ${email} (${cleanPhone}): ${formatted}`);
            } catch (e) {
                console.error('[WA Pairing Error]:', e.message);
            }
        }, 3000);
    }

    return sock;
}

app.post('/api/whatsapp/pair', async (req, res) => {
    const { email, phoneNumber } = req.body;
    if (!email || !phoneNumber) return res.status(400).json({ error: 'Data tidak lengkap' });

    const sessionDir = path.join(__dirname, 'sessions', email.replace(/[^a-zA-Z0-9]/g, '_'));
    if (sessions.has(email)) {
        try { sessions.get(email).end(); } catch (e) {}
        sessions.delete(email);
    }
    if (fs.existsSync(sessionDir)) {
        try { fs.rmSync(sessionDir, { recursive: true, force: true }); } catch (e) {}
    }
    
    pairingCodes.delete(email);
    statuses.set(email, 'initiating');
    
    await connectToWhatsApp(email, phoneNumber);
    
    for (let i = 0; i < 20; i++) {
        await new Promise(r => setTimeout(r, 500));
        if (pairingCodes.get(email)) {
            return res.json({ success: true, pairingCode: pairingCodes.get(email) });
        }
    }
    res.json({ success: false, message: 'Gagal membuat kode pairing, coba lagi' });
});

app.get('/api/whatsapp/status/:email', (req, res) => {
    const { email } = req.params;
    const isConnected = statuses.get(email) === 'connected';
    res.json({ 
        connected: isConnected, 
        status: statuses.get(email) || 'disconnected',
        pairingCode: pairingCodes.get(email) || null 
    });
});

app.post('/api/admin/token', (req, res) => {
    const { adminKey, token, email } = req.body;
    if (adminKey !== 'LOP_SUPER_ADMIN_SECRET') return res.status(403).json({ error: 'Unauthorized' });
    try {
        db.prepare('INSERT OR REPLACE INTO tokens (token, email) VALUES (?, ?)').run(token, email || null);
        res.json({ success: true, token });
    } catch (e) {
        res.status(400).json({ error: e.message });
    }
});

app.post('/api/auth/verify', (req, res) => {
    const { email, token } = req.body;
    const row = db.prepare('SELECT * FROM tokens WHERE token = ?').get(token);
    if (!row) return res.status(401).json({ error: 'Invalid token' });
    if (row.email && row.email !== email) return res.status(401).json({ error: 'Token bound to another email' });
    if (!row.email) {
        db.prepare('UPDATE tokens SET email = ? WHERE token = ?').run(email, token);
    }
    res.json({ success: true, message: 'Verified' });
});

const PORT = 3000;
app.listen(PORT, () => console.log(`Lop-Client backend running on port ${PORT}`));
