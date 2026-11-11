require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { DatabaseSync } = require('node:sqlite');
const pino = require('pino');
const crypto = require('crypto');
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

// Serve static admin web panel
app.use(express.static(path.join(__dirname, 'public')));

// Database setup
const db = new DatabaseSync(path.join(__dirname, 'database.sqlite'));
db.exec(`
    CREATE TABLE IF NOT EXISTS tokens (
        token TEXT PRIMARY KEY,
        assigned_user TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        expires_at DATETIME,
        is_active INTEGER DEFAULT 1
    );
    CREATE TABLE IF NOT EXISTS admin_config (
        key TEXT PRIMARY KEY,
        value TEXT
    );
`);

// Pastikan kolom-kolom baru ada jika database dibuat dengan skema lama
const existingColumns = db.prepare('PRAGMA table_info(tokens)').all().map(c => c.name);
if (!existingColumns.includes('assigned_user')) {
    db.exec('ALTER TABLE tokens ADD COLUMN assigned_user TEXT;');
}
if (!existingColumns.includes('is_active')) {
    db.exec('ALTER TABLE tokens ADD COLUMN is_active INTEGER DEFAULT 1;');
}
if (!existingColumns.includes('expires_at')) {
    db.exec('ALTER TABLE tokens ADD COLUMN expires_at DATETIME;');
}

// Inisialisasi Master Admin Token jika belum ada
const ADMIN_MASTER_TOKEN = (process.env.ADMIN_TOKEN || 'LOPADMIN-MASTER-9999').trim().toUpperCase();
const existingAdmin = db.prepare('SELECT * FROM tokens WHERE token = ?').get(ADMIN_MASTER_TOKEN);
if (!existingAdmin) {
    db.prepare('INSERT INTO tokens (token, assigned_user, is_active) VALUES (?, ?, 1)').run(ADMIN_MASTER_TOKEN, 'admin');
}

// Admin secret password
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'lindo.1629';

// Middleware: Batasi endpoint admin hanya untuk localhost / private loopback
function requireLocalhost(req, res, next) {
    const ip = req.ip || req.connection?.remoteAddress || '';
    const isLoopback = ip === '127.0.0.1' || ip === '::1' || ip === '::ffff:127.0.0.1' || req.hostname === 'localhost';
    if (!isLoopback) {
        return res.status(403).json({ error: 'Akses ditolak: Admin Panel hanya dapat diakses dari Localhost server.' });
    }
    next();
}

// In-memory state for WhatsApp instances
const sessions = new Map(); 
const pairingCodes = new Map();
const statuses = new Map();
const userLogs = new Map();

function addLog(user, message) {
    if (!userLogs.has(user)) userLogs.set(user, []);
    const logs = userLogs.get(user);
    const timestamp = new Date().toLocaleTimeString();
    logs.push(`[${timestamp}] ${message}`);
    if (logs.length > 50) logs.shift();
}

// Generator token LOPCLIENT-XXXX-YYYY
function generateRandomToken() {
    const part1 = crypto.randomBytes(2).toString('hex').toUpperCase();
    const part2 = crypto.randomBytes(2).toString('hex').toUpperCase();
    return `LOPCLIENT-${part1}-${part2}`;
}

async function connectToWhatsApp(user, phoneNumber = null) {
    if (sessions.has(user)) return sessions.get(user);

    addLog(user, 'Menginisialisasi sesi WhatsApp Baileys...');
    const sessionDir = path.join(__dirname, 'sessions', user.replace(/[^a-zA-Z0-9]/g, '_'));
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

    sessions.set(user, sock);
    sock.ev.on('creds.update', saveCreds);

    sock.ev.on('connection.update', async ({ connection, lastDisconnect }) => {
        if (connection === 'open') {
            statuses.set(user, 'connected');
            pairingCodes.delete(user);
            addLog(user, 'STATUS: WhatsApp Terhubung (ONLINE)!');
        }
        if (connection === 'close') {
            const statusCode = lastDisconnect?.error?.output?.statusCode;
            sessions.delete(user);
            addLog(user, `STATUS: Koneksi terputus (Kode: ${statusCode || 'unknown'})`);
            
            if (statusCode === DisconnectReason.loggedOut) {
                statuses.set(user, 'logged_out');
                addLog(user, 'STATUS: Perangkat telah di-logout.');
                try { fs.rmSync(sessionDir, { recursive: true, force: true }); } catch (e) {}
                return;
            }
            if (statusCode === 515 || statusCode === DisconnectReason.restartRequired) {
                statuses.set(user, 'reconnecting');
                addLog(user, 'STATUS: Handshake 515 restartRequired. Menghubungkan ulang...');
                setTimeout(() => connectToWhatsApp(user, phoneNumber), 1500);
                return;
            }
            statuses.set(user, 'reconnecting');
            setTimeout(() => connectToWhatsApp(user, phoneNumber), 2000);
        }
    });

    if (!sock.authState.creds.registered && phoneNumber) {
        addLog(user, `Meminta kode pairing untuk nomor ${phoneNumber}...`);
        setTimeout(async () => {
            try {
                const cleanPhone = phoneNumber.replace(/\D/g, '');
                const code = await sock.requestPairingCode(cleanPhone);
                const formatted = code?.match(/.{1,4}/g)?.join('-') || code;
                pairingCodes.set(user, formatted);
                statuses.set(user, 'pairing');
                addLog(user, `Kode Pairing diperoleh: ${formatted}`);
            } catch (e) {
                addLog(user, `Gagal meminta pairing: ${e.message}`);
            }
        }, 3000);
    }
    return sock;
}

// -------------------------------------------------------------
// 1. PUBLIC API UNTUK APLIKASI CLIENT (FLUTTER)
// -------------------------------------------------------------

// Verifikasi & Binding Token ke Akun Device ID / Username
app.post('/api/auth/verify', (req, res) => {
    const { username, token } = req.body;
    if (!username || !token) return res.status(400).json({ error: 'Device ID dan Token wajib diisi.' });

    const cleanUser = username.trim().toLowerCase();
    const cleanToken = token.trim().toUpperCase();

    // Check if token is Admin Master Token
    if (cleanToken === ADMIN_MASTER_TOKEN) {
        return res.json({
            success: true,
            isAdmin: true,
            message: 'Login sebagai Super Admin berhasil.',
            username: 'admin',
            token: ADMIN_MASTER_TOKEN,
            expiresAt: null
        });
    }

    const row = db.prepare('SELECT * FROM tokens WHERE token = ?').get(cleanToken);
    if (!row) {
        return res.status(401).json({ error: 'Kode Token tidak ditemukan di database.' });
    }

    if (row.is_active !== 1) {
        return res.status(403).json({ error: 'Token ini telah dinonaktifkan oleh Admin.' });
    }

    if (row.expires_at && new Date(row.expires_at) < new Date()) {
        return res.status(403).json({ error: 'Token ini sudah kedaluwarsa (Expired).' });
    }

    // Jika token sudah terikat ke device lain
    if (row.assigned_user && row.assigned_user !== cleanUser) {
        return res.status(403).json({ error: 'Token ini sudah digunakan pada perangkat lain.' });
    }

    // Periksa apakah device ini sudah punya token lain
    const existingBinding = db.prepare('SELECT * FROM tokens WHERE assigned_user = ?').get(cleanUser);
    if (existingBinding && existingBinding.token !== cleanToken) {
        return res.status(403).json({ error: `Perangkat ini sudah terikat ke token lain (${existingBinding.token}). 1 perangkat hanya berhak 1 token.` });
    }

    // Bind token ke device jika belum ada pemilik
    if (!row.assigned_user) {
        db.prepare('UPDATE tokens SET assigned_user = ? WHERE token = ?').run(cleanUser, cleanToken);
    }

    res.json({ 
        success: true, 
        isAdmin: false,
        message: 'Aktivasi berhasil.', 
        username: cleanUser,
        token: cleanToken,
        expiresAt: row.expires_at 
    });
});

app.post('/api/whatsapp/pair', async (req, res) => {
    const { email, phoneNumber } = req.body;
    if (!email || !phoneNumber) return res.status(400).json({ error: 'Data tidak lengkap' });

    const user = email.trim().toLowerCase();
    const sessionDir = path.join(__dirname, 'sessions', user.replace(/[^a-zA-Z0-9]/g, '_'));
    if (sessions.has(user)) {
        try { sessions.get(user).end(); } catch (e) {}
        sessions.delete(user);
    }
    if (fs.existsSync(sessionDir)) {
        try { fs.rmSync(sessionDir, { recursive: true, force: true }); } catch (e) {}
    }
    
    pairingCodes.delete(user);
    statuses.set(user, 'initiating');
    addLog(user, `Memulai sesi pairing baru untuk ${phoneNumber}`);
    await connectToWhatsApp(user, phoneNumber);
    
    for (let i = 0; i < 20; i++) {
        await new Promise(r => setTimeout(r, 500));
        if (pairingCodes.get(user)) {
            return res.json({ success: true, pairingCode: pairingCodes.get(user) });
        }
    }
    res.json({ success: false, message: 'Timeout meminta kode pairing' });
});

app.post('/api/whatsapp/disconnect', (req, res) => {
    const { email } = req.body;
    const user = (email || '').trim().toLowerCase();
    if (sessions.has(user)) {
        try { sessions.get(user).end(); } catch (e) {}
        sessions.delete(user);
    }
    statuses.set(user, 'disconnected');
    pairingCodes.delete(user);
    addLog(user, 'WhatsApp diputuskan secara manual (DISCONNECTED).');
    res.json({ success: true, message: 'Disconnected' });
});

app.get('/api/whatsapp/status/:email', (req, res) => {
    const user = (req.params.email || '').trim().toLowerCase();
    res.json({ 
        connected: statuses.get(user) === 'connected', 
        status: statuses.get(user) || 'disconnected',
        pairingCode: pairingCodes.get(user) || null 
    });
});

app.get('/api/whatsapp/logs/:email', (req, res) => {
    const user = (req.params.email || '').trim().toLowerCase();
    res.json({ logs: userLogs.get(user) || ['[SYS] Terminal log siap.'] });
});

// -------------------------------------------------------------
// 2. ADMIN PANEL API (TERLINDUNGI LOCALHOST & PASSWORD)
// -------------------------------------------------------------

// Halaman web admin (hanya boleh dibuka di localhost)
app.get('/admin', requireLocalhost, (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'admin.html'));
});

// Verifikasi password admin
app.post('/api/admin/login', requireLocalhost, (req, res) => {
    const { password } = req.body;
    if (password === ADMIN_PASSWORD) {
        return res.json({ success: true, message: 'Login Admin Berhasil' });
    }
    res.status(401).json({ error: 'Password Admin Salah' });
});

// Generate Token LOPCLIENT-XXXX-YYYY (Dukungan token Admin)
app.post('/api/admin/tokens/generate', (req, res) => {
    const { password, count = 1, days = 30, adminToken } = req.body;
    if (password !== ADMIN_PASSWORD && adminToken !== ADMIN_MASTER_TOKEN) {
        return res.status(401).json({ error: 'Autentikasi Admin Gagal' });
    }

    const createdTokens = [];
    const expiresAt = new Date(Date.now() + days * 24 * 60 * 60 * 1000).toISOString();

    for (let i = 0; i < count; i++) {
        let tok = generateRandomToken();
        try {
            db.prepare('INSERT INTO tokens (token, expires_at, is_active) VALUES (?, ?, 1)').run(tok, expiresAt);
            createdTokens.push(tok);
        } catch (_) {
            tok = generateRandomToken();
            db.prepare('INSERT INTO tokens (token, expires_at, is_active) VALUES (?, ?, 1)').run(tok, expiresAt);
            createdTokens.push(tok);
        }
    }

    res.json({ success: true, tokens: createdTokens, expiresAt });
});

// List semua token (Dukungan token Admin)
app.post('/api/admin/tokens/list', (req, res) => {
    const { password, adminToken } = req.body;
    if (password !== ADMIN_PASSWORD && adminToken !== ADMIN_MASTER_TOKEN) {
        return res.status(401).json({ error: 'Autentikasi Admin Gagal' });
    }

    const rows = db.prepare('SELECT * FROM tokens ORDER BY created_at DESC').all();
    res.json({ success: true, tokens: rows });
});

// Reset user / Hapus binding akun dari token
app.post('/api/admin/tokens/reset-user', (req, res) => {
    const { password, token, adminToken } = req.body;
    if (password !== ADMIN_PASSWORD && adminToken !== ADMIN_MASTER_TOKEN) {
        return res.status(401).json({ error: 'Autentikasi Admin Gagal' });
    }

    db.prepare('UPDATE tokens SET assigned_user = NULL WHERE token = ?').run(token);
    res.json({ success: true, message: 'User binding berhasil di-reset.' });
});

// Hapus token
app.post('/api/admin/tokens/delete', (req, res) => {
    const { password, token, adminToken } = req.body;
    if (password !== ADMIN_PASSWORD && adminToken !== ADMIN_MASTER_TOKEN) {
        return res.status(401).json({ error: 'Autentikasi Admin Gagal' });
    }

    db.prepare('DELETE FROM tokens WHERE token = ?').run(token);
    res.json({ success: true, message: 'Token dihapus.' });
});

// Toggle status aktif/nonaktif token
app.post('/api/admin/tokens/toggle', (req, res) => {
    const { password, token, isActive, adminToken } = req.body;
    if (password !== ADMIN_PASSWORD && adminToken !== ADMIN_MASTER_TOKEN) {
        return res.status(401).json({ error: 'Autentikasi Admin Gagal' });
    }

    db.prepare('UPDATE tokens SET is_active = ? WHERE token = ?').run(isActive ? 1 : 0, token);
    res.json({ success: true, message: 'Status token diperbarui.' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => console.log(`Lop-Client backend running on port ${PORT}`));
