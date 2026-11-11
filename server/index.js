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
    CREATE TABLE IF NOT EXISTS config (
        key TEXT PRIMARY KEY,
        value TEXT
    );
    CREATE TABLE IF NOT EXISTS bot_configs (
        email TEXT PRIMARY KEY,
        phone TEXT,
        prefix TEXT DEFAULT '!',
        custom_features TEXT
    );
`);

function getConfig(key, defaultValue = '') {
    const row = db.prepare('SELECT value FROM config WHERE key = ?').get(key);
    return row ? row.value : defaultValue;
}

function setConfig(key, value) {
    db.prepare('INSERT OR REPLACE INTO config (key, value) VALUES (?, ?)').run(key, value);
}

const sessions = new Map(); 
const pairingCodes = new Map();
const statuses = new Map();
const userLogs = new Map();

function addLog(email, message) {
    if (!userLogs.has(email)) userLogs.set(email, []);
    const logs = userLogs.get(email);
    const timestamp = new Date().toLocaleTimeString();
    logs.push(`[${timestamp}] ${message}`);
    if (logs.length > 50) logs.shift();
}

async function connectToWhatsApp(email, phoneNumber = null) {
    if (sessions.has(email)) return sessions.get(email);

    addLog(email, 'Menginisialisasi sesi WhatsApp Baileys...');
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
            addLog(email, 'STATUS: WhatsApp Terhubung (ONLINE)!');
        }
        if (connection === 'close') {
            const statusCode = lastDisconnect?.error?.output?.statusCode;
            sessions.delete(email);
            addLog(email, `STATUS: Koneksi terputus (Kode: ${statusCode || 'unknown'})`);
            
            if (statusCode === DisconnectReason.loggedOut) {
                statuses.set(email, 'logged_out');
                addLog(email, 'STATUS: Perangkat telah di-logout.');
                try { fs.rmSync(sessionDir, { recursive: true, force: true }); } catch (e) {}
                return;
            }
            if (statusCode === 515 || statusCode === DisconnectReason.restartRequired) {
                statuses.set(email, 'reconnecting');
                addLog(email, 'STATUS: Handshake 515 restartRequired. Menghubungkan ulang...');
                setTimeout(() => connectToWhatsApp(email, phoneNumber), 1500);
                return;
            }
            statuses.set(email, 'reconnecting');
            setTimeout(() => connectToWhatsApp(email, phoneNumber), 2000);
        }
    });

    if (!sock.authState.creds.registered && phoneNumber) {
        addLog(email, `Meminta kode pairing untuk nomor ${phoneNumber}...`);
        setTimeout(async () => {
            try {
                const cleanPhone = phoneNumber.replace(/\D/g, '');
                const code = await sock.requestPairingCode(cleanPhone);
                const formatted = code?.match(/.{1,4}/g)?.join('-') || code;
                pairingCodes.set(email, formatted);
                statuses.set(email, 'pairing');
                addLog(email, `Kode Pairing diperoleh: ${formatted}`);
            } catch (e) {
                addLog(email, `Gagal meminta pairing: ${e.message}`);
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
    addLog(email, `Memulai sesi pairing baru untuk ${phoneNumber}`);
    await connectToWhatsApp(email, phoneNumber);
    
    for (let i = 0; i < 20; i++) {
        await new Promise(r => setTimeout(r, 500));
        if (pairingCodes.get(email)) {
            return res.json({ success: true, pairingCode: pairingCodes.get(email) });
        }
    }
    res.json({ success: false, message: 'Timeout' });
});

app.post('/api/whatsapp/disconnect', (req, res) => {
    const { email } = req.body;
    if (sessions.has(email)) {
        try { sessions.get(email).end(); } catch (e) {}
        sessions.delete(email);
    }
    statuses.set(email, 'disconnected');
    pairingCodes.delete(email);
    addLog(email, 'WhatsApp diputuskan secara manual (DISCONNECTED).');
    res.json({ success: true, message: 'Disconnected' });
});

app.get('/api/whatsapp/status/:email', (req, res) => {
    const { email } = req.params;
    res.json({ 
        connected: statuses.get(email) === 'connected', 
        status: statuses.get(email) || 'disconnected',
        pairingCode: pairingCodes.get(email) || null 
    });
});

app.get('/api/whatsapp/logs/:email', (req, res) => {
    const { email } = req.params;
    res.json({ logs: userLogs.get(email) || ['[SYS] Terminal log siap.'] });
});

// AUTH VERIFY via Google Apps Script Web App (with default fallback test tokens)
app.post('/api/auth/verify', async (req, res) => {
    const { username, token } = req.body;
    if (!username || !token) return res.status(400).json({ error: 'Username dan Token wajib diisi' });

    const appsScriptUrl = getConfig('apps_script_url', '');

    if (appsScriptUrl) {
        try {
            const fetch = (await import('node-fetch')).default || global.fetch;
            const resp = await fetch(`${appsScriptUrl}?token=${encodeURIComponent(token)}&username=${encodeURIComponent(username)}`);
            const data = await resp.json();
            if (data.valid && data.active && !data.expired) {
                return res.json({ success: true, isAdmin: !!data.isAdmin, username: data.username || username });
            } else {
                return res.status(401).json({ error: data.error || 'Token tidak valid, expired, atau tidak aktif di AppsScript' });
            }
        } catch (e) {
            return res.status(500).json({ error: 'Gagal menghubungi Google Apps Script: ' + e.message });
        }
    } else {
        // Built-in fallback for out-of-the-box testing before Apps Script URL is set
        if (token === 'LOP-ADMIN-MASTER') {
            return res.json({ success: true, isAdmin: true, username: username || 'admin' });
        }
        if (token === 'LOP-USER-TEST') {
            return res.json({ success: true, isAdmin: false, username: username || 'user' });
        }
        return res.status(401).json({ error: 'Token tidak valid. (Belum set Apps Script URL atau token salah)' });
    }
});

// Admin configuration endpoints
app.post('/api/admin/config', (req, res) => {
    const { adminKey, appsScriptUrl } = req.body;
    if (adminKey !== 'LOP_SUPER_ADMIN_SECRET') return res.status(403).json({ error: 'Unauthorized' });
    setConfig('apps_script_url', appsScriptUrl || '');
    res.json({ success: true, appsScriptUrl: getConfig('apps_script_url') });
});

app.get('/api/admin/config', (req, res) => {
    const { adminKey } = req.query;
    if (adminKey !== 'LOP_SUPER_ADMIN_SECRET') return res.status(403).json({ error: 'Unauthorized' });
    res.json({ success: true, appsScriptUrl: getConfig('apps_script_url') });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Lop-Client backend running on port ${PORT}`));
