const express = require('express');
const cors = require('cors');
const { DatabaseSync } = require('node:sqlite');
const pino = require('pino');
const { 
    default: makeWASocket, 
    useMultiFileAuthState, 
    DisconnectReason 
} = require('@whiskeysockets/baileys');
const fs = require('fs');
const path = require('path');

const app = express();
app.use(express.json());
app.use(cors());

// ponytail: single-node SQLite DB; upgrade to PostgreSQL when scaling multi-server.
const db = new DatabaseSync(path.join(__dirname, 'database.sqlite'));
db.exec(`
    CREATE TABLE IF NOT EXISTS tokens (
        token TEXT PRIMARY KEY,
        email TEXT UNIQUE,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
    CREATE TABLE IF NOT EXISTS bot_configs (
        email TEXT PRIMARY KEY,
        phone TEXT,
        prefix TEXT DEFAULT '!',
        custom_features TEXT
    );
`);

const sessions = {}; // email -> socket
const pairingCodes = {}; // email -> code

// Admin Token generator / Token validator endpoints
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
    
    // Bind token to email if unassigned
    if (!row.email) {
        db.prepare('UPDATE tokens SET email = ? WHERE token = ?').run(email, token);
    }
    res.json({ success: true, message: 'Verified' });
});

// Baileys WhatsApp Pairing Endpoint
app.post('/api/whatsapp/pair', async (req, res) => {
    const { email, phoneNumber } = req.body;
    if (!email || !phoneNumber) return res.status(400).json({ error: 'Missing email or phone' });

    const sessionDir = path.join(__dirname, 'sessions', email.replace(/[^a-zA-Z0-9]/g, '_'));
    if (!fs.existsSync(sessionDir)) fs.mkdirSync(sessionDir, { recursive: true });

    const { state, saveCreds } = await useMultiFileAuthState(sessionDir);

    const sock = makeWASocket({
        auth: state,
        logger: pino({ level: 'silent' }),
        printQRInTerminal: false
    });

    sessions[email] = sock;

    sock.ev.on('creds.update', saveCreds);

    sock.ev.on('connection.update', async (update) => {
        const { connection } = update;
        if (connection === 'open') {
            console.log(`WhatsApp connected for ${email}`);
        }
    });

    if (!sock.authState.creds.registered) {
        // Wait a second for socket initialization before requesting pairing code
        await new Promise(resolve => setTimeout(resolve, 2000));
        try {
            let code = await sock.requestPairingCode(phoneNumber);
            code = code?.match(/.{1,4}/g)?.join('-') || code;
            pairingCodes[email] = code;
            return res.json({ success: true, pairingCode: code });
        } catch (e) {
            return res.status(500).json({ error: e.message });
        }
    } else {
        return res.json({ success: true, message: 'Already connected' });
    }
});

app.get('/api/whatsapp/status/:email', (req, res) => {
    const { email } = req.params;
    const sock = sessions[email];
    const isConnected = sock?.user ? true : false;
    res.json({ connected: isConnected, pairingCode: pairingCodes[email] || null });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Lop-Client backend running on port ${PORT}`));
