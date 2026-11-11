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

const db = new DatabaseSync(path.join(__dirname, 'database.sqlite'));
db.exec(`
    CREATE TABLE IF NOT EXISTS tokens (
        token TEXT PRIMARY KEY,
        email TEXT UNIQUE,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        expires_at DATETIME
    );
    CREATE TABLE IF NOT EXISTS bot_configs (
        email TEXT PRIMARY KEY,
        phone TEXT,
        prefix TEXT DEFAULT '!',
        custom_features TEXT
    );
`);

const sessions = new Map(); 
const pairingCodes = new Map();
const statuses = new Map();

async function connectToWhatsApp(email, phoneNumber = null) {
    if (sessions.has(email)) return sessions.get(email);

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
            statuses.set(email, 'connected');
            pairingCodes.delete(email);
        }
        if (connection === 'close') {
            const statusCode = lastDisconnect?.error?.output?.statusCode;
            sessions.delete(email);
            if (statusCode === DisconnectReason.loggedOut) {
                statuses.set(email, 'logged_out');
                try { fs.rmSync(sessionDir, { recursive: true, force: true }); } catch (e) {}
                return;
            }
            statuses.set(email, 'reconnecting');
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
    res.json({ success: false, message: 'Timeout' });
});

app.get('/api/whatsapp/status/:email', (req, res) => {
    const { email } = req.params;
    res.json({ 
        connected: statuses.get(email) === 'connected', 
        status: statuses.get(email) || 'disconnected',
        pairingCode: pairingCodes.get(email) || null 
    });
});

app.post('/api/admin/token', (req, res) => {
    const { adminKey, token, email, expiresInDays = 30 } = req.body;
    if (adminKey !== 'LOP_SUPER_ADMIN_SECRET') return res.status(403).json({ error: 'Unauthorized' });
    try {
        const expiresAt = new Date(Date.now() + expiresInDays * 24 * 60 * 60 * 1000).toISOString();
        db.prepare('INSERT OR REPLACE INTO tokens (token, email, expires_at) VALUES (?, ?, ?)').run(token, email || null, expiresAt);
        res.json({ success: true, token, expiresAt });
    } catch (e) {
        res.status(400).json({ error: e.message });
    }
});

app.get('/api/admin/tokens', (req, res) => {
    const { adminKey } = req.query;
    if (adminKey !== 'LOP_SUPER_ADMIN_SECRET') return res.status(403).json({ error: 'Unauthorized' });
    try {
        const rows = db.prepare('SELECT * FROM tokens').all();
        res.json({ success: true, tokens: rows });
    } catch (e) {
        res.status(400).json({ error: e.message });
    }
});

app.post('/api/admin/token/delete', (req, res) => {
    const { adminKey, token } = req.body;
    if (adminKey !== 'LOP_SUPER_ADMIN_SECRET') return res.status(403).json({ error: 'Unauthorized' });
    db.prepare('DELETE FROM tokens WHERE token = ?').run(token);
    res.json({ success: true });
});

app.post('/api/auth/verify', (req, res) => {
    const { email, token } = req.body;
    const row = db.prepare('SELECT * FROM tokens WHERE token = ?').get(token);
    if (!row) return res.status(401).json({ error: 'Token tidak valid' });
    
    if (row.expires_at && new Date(row.expires_at) < new Date()) {
        return res.status(401).json({ error: 'Token sudah kedaluwarsa (expired)' });
    }

    if (row.email && row.email !== email) return res.status(401).json({ error: 'Token terikat ke akun Google lain' });
    
    if (!row.email) {
        db.prepare('UPDATE tokens SET email = ? WHERE token = ?').run(email, token);
    }
    res.json({ success: true, message: 'Verified' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Lop-Client backend running on port ${PORT}`));
