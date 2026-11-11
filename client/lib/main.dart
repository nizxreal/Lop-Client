import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert';
import 'dart:async';

String serverUrl = 'http://192.168.111.98:3000'; // Sesuaikan IP backend LAN / VPS

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LopClientApp());
}

class LopClientApp extends StatelessWidget {
  const LopClientApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lop-Client',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090D16),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF10B981),
          secondary: Color(0xFF6366F1),
          surface: Color(0xFF131B2E),
          background: Color(0xFF090D16),
        ),
        fontFamily: 'Roboto',
        cardTheme: CardThemeData(
          color: const Color(0xFF131B2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF1E293B)),
          ),
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E293B),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      ),
      home: const MainNavigator(),
    );
  }
}

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});
  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  String? email;
  String? token;
  bool isVerified = false;
  bool isAdmin = false;

  Future<void> onLogin(String mail, {bool adminUnlocked = false}) async {
    bool adminStatus = adminUnlocked;
    if (!adminStatus) {
      try {
        final res = await http.get(Uri.parse('$serverUrl/api/auth/is-admin?email=$mail'));
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body);
          adminStatus = body['isAdmin'] == true;
        }
      } catch (_) {}
    }

    setState(() {
      email = mail;
      isAdmin = adminStatus;
    });
  }

  void onVerified(String tok) {
    setState(() {
      token = tok;
      isVerified = true;
    });
  }

  void logout() {
    setState(() {
      email = null;
      token = null;
      isVerified = false;
      isAdmin = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (email == null) return AuthScreen(onLogin: onLogin);
    if (!isVerified) return TokenScreen(email: email!, onVerified: onVerified, onLogout: logout);
    return DashboardOnePage(email: email!, isAdmin: isAdmin, onLogout: logout);
  }
}

// -------------------------------------------------------------
// 1. SCREEN: AUTH / LOGIN DENGAN OPSI ADMIN PASSWORD lindo.1629
// -------------------------------------------------------------
class AuthScreen extends StatefulWidget {
  final Function(String, {bool adminUnlocked}) onLogin;
  const AuthScreen({super.key, required this.onLogin});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLoading = false;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  Future<void> signInWithGoogle() async {
    setState(() => isLoading = true);
    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        await widget.onLogin(account.email);
        return;
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
    _showManualEmailDialog();
  }

  void _showManualEmailDialog() {
    final emailCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131B2E),
        title: const Text('Login Email Akun Google'),
        content: TextField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Alamat Email', hintText: 'nama@gmail.com'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (emailCtrl.text.isNotEmpty) widget.onLogin(emailCtrl.text.trim());
            },
            child: const Text('Masuk'),
          )
        ],
      ),
    );
  }

  void _showAdminLoginDialog() {
    final emailCtrl = TextEditingController(text: 'admin@lop.com');
    final passCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131B2E),
        title: const Row(
          children: [
            Icon(Icons.shield, color: Colors.amber, size: 20),
            SizedBox(width: 8),
            Text('Login Admin Panel', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email Admin')),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password Admin'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              if (passCtrl.text.trim() == 'lindo.1629') {
                Navigator.pop(ctx);
                widget.onLogin(emailCtrl.text.trim(), adminUnlocked: true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password Admin Salah! Gunakan lindo.1629')),
                );
              }
            },
            child: const Text('Buka Admin'),
          )
        ],
      ),
    );
  }

  void _showServerSettings() {
    final ctrl = TextEditingController(text: serverUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131B2E),
        title: const Text('Server Host Config'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'URL Server Backend', hintText: 'http://192.168.1.x:3000'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              setState(() => serverUrl = ctrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.settings_outlined, color: Color(0xFF94A3B8)), onPressed: _showServerSettings)
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF10B981).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))
                  ],
                ),
                child: const Icon(Icons.bolt, size: 48, color: Colors.black),
              ),
              const SizedBox(height: 20),
              const Text('Lop-Client', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              const SizedBox(height: 6),
              const Text('Self-Host WhatsApp Automation UI', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : signInWithGoogle,
                  icon: const Icon(Icons.g_mobiledata, size: 32, color: Colors.black),
                  label: Text(isLoading ? 'Menghubungkan...' : 'Masuk dengan Google'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _showManualEmailDialog,
                child: const Text('Masukkan email secara manual', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF334155)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _showAdminLoginDialog,
                icon: const Icon(Icons.lock_outline, size: 16, color: Colors.amber),
                label: const Text('Masuk Mode Admin (Password)', style: TextStyle(color: Colors.amber, fontSize: 13)),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 2. SCREEN: TOKEN GATING
// -------------------------------------------------------------
class TokenScreen extends StatefulWidget {
  final String email;
  final Function(String) onVerified;
  final VoidCallback onLogout;
  const TokenScreen({super.key, required this.email, required this.onVerified, required this.onLogout});

  @override
  State<TokenScreen> createState() => _TokenScreenState();
}

class _TokenScreenState extends State<TokenScreen> {
  final ctrl = TextEditingController();
  bool isLoading = false;
  String? error;

  Future<void> verify() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final res = await http.post(
        Uri.parse('$serverUrl/api/auth/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.email, 'token': ctrl.text.trim()}),
      );
      final body = jsonDecode(res.body);
      if (res.statusCode == 200) {
        widget.onVerified(ctrl.text.trim());
      } else {
        setState(() => error = body['error'] ?? 'Token tidak valid');
      }
    } catch (_) {
      setState(() => error = 'Gagal menghubungi server validasi token');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.logout, color: Color(0xFF94A3B8)), onPressed: widget.onLogout)
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_user, size: 16, color: Color(0xFF10B981)),
                    const SizedBox(width: 6),
                    Text(widget.email, style: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1))),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('Aktivasi Lisensi Token', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Masukkan token eksklusif Anda dari Admin.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
              const SizedBox(height: 28),
              TextField(
                controller: ctrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'KODE TOKEN',
                  hintText: 'Misal: LOP-USER-01',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.paste, color: Color(0xFF94A3B8)),
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      if (data?.text != null) ctrl.text = data!.text!.trim();
                    },
                  ),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : verify,
                  child: Text(isLoading ? 'Memverifikasi...' : 'Aktivasi Lisensi'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 3. DASHBOARD 1-PAGE: CONNECT, DISCONNECT, RE-PAIR, LOG TERMINAL
// -------------------------------------------------------------
class DashboardOnePage extends StatefulWidget {
  final String email;
  final bool isAdmin;
  final VoidCallback onLogout;
  const DashboardOnePage({super.key, required this.email, required this.isAdmin, required this.onLogout});

  @override
  State<DashboardOnePage> createState() => _DashboardOnePageState();
}

class _DashboardOnePageState extends State<DashboardOnePage> {
  bool isConnected = false;
  String? pairingCode;
  final phoneCtrl = TextEditingController(text: '6285871087187');
  bool isActionLoading = false;
  List<String> terminalLogs = ['[SYS] Inisialisasi Terminal Lop-Client...'];
  Timer? pollTimer;

  // Admin Token Form
  final adminTokenCtrl = TextEditingController();
  int adminExpiryDays = 30;
  List<dynamic> adminTokensList = [];

  @override
  void initState() {
    super.initState();
    refreshAll();
    pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => refreshAll());
  }

  @override
  void dispose() {
    pollTimer?.cancel();
    super.dispose();
  }

  Future<void> refreshAll() async {
    try {
      final res = await http.get(Uri.parse('$serverUrl/api/whatsapp/status/${widget.email}'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            isConnected = data['connected'] == true;
            pairingCode = data['pairingCode'];
          });
        }
      }
      final logRes = await http.get(Uri.parse('$serverUrl/api/whatsapp/logs/${widget.email}'));
      if (logRes.statusCode == 200) {
        final logData = jsonDecode(logRes.body);
        if (mounted && logData['logs'] != null) {
          setState(() => terminalLogs = List<String>.from(logData['logs']));
        }
      }
    } catch (_) {}
  }

  Future<void> handlePairOrConnect() async {
    if (phoneCtrl.text.isEmpty) return;
    setState(() => isActionLoading = true);
    try {
      final res = await http.post(
        Uri.parse('$serverUrl/api/whatsapp/pair'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.email, 'phoneNumber': phoneCtrl.text.trim()}),
      );
      final body = jsonDecode(res.body);
      if (body['pairingCode'] != null) {
        setState(() => pairingCode = body['pairingCode']);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => isActionLoading = false);
      refreshAll();
    }
  }

  Future<void> handleDisconnect() async {
    setState(() => isActionLoading = true);
    try {
      await http.post(
        Uri.parse('$serverUrl/api/whatsapp/disconnect'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.email}),
      );
      setState(() {
        isConnected = false;
        pairingCode = null;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => isActionLoading = false);
      refreshAll();
    }
  }

  // Admin Generate Token
  Future<void> adminGenerateToken() async {
    if (adminTokenCtrl.text.isEmpty) return;
    try {
      await http.post(
        Uri.parse('$serverUrl/api/admin/token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'adminKey': 'LOP_SUPER_ADMIN_SECRET',
          'token': adminTokenCtrl.text.trim().toUpperCase(),
          'expiresInDays': adminExpiryDays,
        }),
      );
      adminTokenCtrl.clear();
      adminFetchTokens();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token baru berhasil di-generate!')),
      );
    } catch (_) {}
  }

  Future<void> adminFetchTokens() async {
    try {
      final res = await http.get(Uri.parse('$serverUrl/api/admin/tokens?adminKey=LOP_SUPER_ADMIN_SECRET'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() => adminTokensList = data['tokens'] ?? []);
      }
    } catch (_) {}
  }

  Future<void> adminDeleteToken(String tok) async {
    try {
      await http.post(
        Uri.parse('$serverUrl/api/admin/token/delete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'adminKey': 'LOP_SUPER_ADMIN_SECRET', 'token': tok}),
      );
      adminFetchTokens();
    } catch (_) {}
  }

  void openAdminModal() {
    adminFetchTokens();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131B2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => Container(
          padding: EdgeInsets.only(top: 24, left: 20, right: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Admin Token Manager', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: adminTokenCtrl,
                  decoration: const InputDecoration(labelText: 'Kode Token Baru (Contoh: LOP-USER-VIP)'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Durasi Expired: ', style: TextStyle(color: Color(0xFF94A3B8))),
                    DropdownButton<int>(
                      value: adminExpiryDays,
                      dropdownColor: const Color(0xFF1E293B),
                      items: [7, 30, 90, 365].map((d) => DropdownMenuItem(value: d, child: Text('$d Hari'))).toList(),
                      onChanged: (v) => setMState(() => adminExpiryDays = v ?? 30),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () async {
                        await adminGenerateToken();
                        setMState(() {});
                      },
                      child: const Text('Buat Token'),
                    )
                  ],
                ),
                const Divider(height: 32, color: Color(0xFF334155)),
                const Text('Daftar Token Tersimpan:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (adminTokensList.isEmpty)
                  const Text('Belum ada token', style: TextStyle(color: Color(0xFF64748B)))
                else
                  ...adminTokensList.map((t) => Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          title: Text(t['token'], style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                          subtitle: Text('User: ${t['email'] ?? 'Belum dipakai'}\nExp: ${t['expires_at'] ?? 'Lifetime'}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.copy, size: 18),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: t['token']));
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Token disalin!')));
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                onPressed: () async {
                                  await adminDeleteToken(t['token']);
                                  setMState(() {});
                                },
                              ),
                            ],
                          ),
                        ),
                      ))
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasPhone = phoneCtrl.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text('Lop-Client Bot', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          if (widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings, color: Colors.amber),
              tooltip: 'Admin Panel',
              onPressed: openAdminModal,
            ),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF94A3B8)),
            onPressed: widget.onLogout,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 8,
                      backgroundColor: isConnected ? const Color(0xFF10B981) : Colors.redAccent,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isConnected ? 'Status: ONLINE (TERHUBUNG)' : 'Status: OFFLINE (BELUM KONEK)',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isConnected ? const Color(0xFF10B981) : Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.email,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Nomor HP Field
            const Text('Nomor WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: '628xxxxxxxxxx',
                prefixIcon: Icon(Icons.phone, color: Color(0xFF94A3B8)),
              ),
            ),
            const SizedBox(height: 16),

            // Tombol Connect / Disconnect + Re-pair
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isConnected
                          ? Colors.redAccent
                          : (hasPhone ? const Color(0xFF10B981) : const Color(0xFF334155)),
                      foregroundColor: isConnected || !hasPhone ? Colors.white : Colors.black,
                    ),
                    onPressed: isActionLoading || (!isConnected && !hasPhone)
                        ? null
                        : (isConnected ? handleDisconnect : handlePairOrConnect),
                    icon: Icon(isConnected ? Icons.power_settings_new : Icons.link),
                    label: Text(
                      isActionLoading
                          ? 'Memproses...'
                          : (isConnected ? 'Disconnect' : 'Connect'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF334155)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: isActionLoading || !hasPhone ? null : handlePairOrConnect,
                    icon: const Icon(Icons.refresh, size: 18, color: Color(0xFFCBD5E1)),
                    label: const Text('Re-Pair', style: TextStyle(color: Color(0xFFCBD5E1))),
                  ),
                ),
              ],
            ),

            // Card Pairing Code (jika sedang pairing)
            if (pairingCode != null && !isConnected) ...[
              const SizedBox(height: 20),
              Card(
                color: const Color(0xFF0F172A),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      const Text('KODE PAIRING WHATSAPP:',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, letterSpacing: 1)),
                      const SizedBox(height: 10),
                      SelectableText(
                        pairingCode!,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                          color: Color(0xFF10B981),
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF334155))),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: pairingCode!));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kode pairing disalin!')));
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Salin Kode'),
                      )
                    ],
                  ),
                ),
              )
            ],

            const SizedBox(height: 24),

            // Live Terminal Console Box
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.terminal, size: 18, color: Color(0xFF10B981)),
                    SizedBox(width: 8),
                    Text('Log Terminal Bot', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: terminalLogs.join('\n')));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Semua log disalin!')));
                  },
                  icon: const Icon(Icons.copy, size: 14, color: Color(0xFF94A3B8)),
                  label: const Text('Salin Log', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                )
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 200,
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF030712),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: ListView.builder(
                itemCount: terminalLogs.length,
                itemBuilder: (ctx, i) {
                  final log = terminalLogs[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      log,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Color(0xFF4ADE80),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
