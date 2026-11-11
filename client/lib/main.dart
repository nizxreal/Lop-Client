import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert';

// Global server URL config (persists during runtime)
String serverUrl = 'http://192.168.111.98:3000'; // Default to PC LAN IP

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
          primary: Color(0xFF10B981), // Emerald
          secondary: Color(0xFF6366F1), // Indigo
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
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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

  void onLogin(String mail) {
    setState(() {
      email = mail;
      isAdmin = mail == 'admin@lop.com';
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
    return Dashboard(email: email!, isAdmin: isAdmin, onLogout: logout);
  }
}

// -------------------------------------------------------------
// 1. SCREEN: AUTH / LOGIN
// -------------------------------------------------------------
class AuthScreen extends StatefulWidget {
  final Function(String) onLogin;
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
        widget.onLogin(account.email);
        return;
      }
    } catch (e) {
      // Fallback modal for dev/emulator environments without Google Play services configured
      _showManualEmailDialog();
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showManualEmailDialog() {
    final ctrl = TextEditingController(text: 'admin@lop.com');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131B2E),
        title: const Text('Input Akun Google (Dev / Fallback)'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Email Akun Google'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (ctrl.text.isNotEmpty) widget.onLogin(ctrl.text.trim());
            },
            child: const Text('Lanjutkan'),
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
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF94A3B8)),
            onPressed: _showServerSettings,
          )
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: const Icon(Icons.bolt, size: 52, color: Colors.black),
              ),
              const SizedBox(height: 24),
              const Text(
                'Lop-Client',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5),
              ),
              const SizedBox(height: 8),
              const Text(
                'Secure WhatsApp Automation Gateway',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : signInWithGoogle,
                  icon: const Icon(Icons.account_circle, color: Colors.black),
                  label: Text(isLoading ? 'Menghubungkan...' : 'Masuk dengan Google'),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _showManualEmailDialog,
                child: const Text(
                  'Atau gunakan email manual',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
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
    } catch (e) {
      setState(() => error = 'Gagal terhubung ke server backend');
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
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(20),
                ),
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
              const Text(
                'Aktivasi Lisensi',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Masukkan token eksklusif Anda. Setiap 1 token hanya berlaku untuk 1 Akun Google.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: ctrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'KODE TOKEN',
                  hintText: 'Misal: LOP-VIP-999',
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
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : verify,
                  child: Text(isLoading ? 'Memverifikasi...' : 'Aktivasi & Lanjutkan'),
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
// 3. SCREEN: DASHBOARD & PAIRING
// -------------------------------------------------------------
class Dashboard extends StatefulWidget {
  final String email;
  final bool isAdmin;
  final VoidCallback onLogout;
  const Dashboard({super.key, required this.email, required this.isAdmin, required this.onLogout});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int currentTabIndex = 0; // 0: Status & Pairing, 1: Fitur Bot, 2: Admin Panel
  bool isConnected = false;
  String? pairingCode;
  String customPrefix = '!';
  final phoneCtrl = TextEditingController(text: '6285871087187');
  bool isPairingLoading = false;

  final Map<String, bool> activeFeatures = {
    'Auto Downloader (TikTok/IG)': true,
    'AI Assistant (Gemini Flash)': true,
    'Group Protection (Anti-Link)': true,
    'Sticker Maker Automated': true,
  };

  @override
  void initState() {
    super.initState();
    checkStatus();
  }

  Future<void> checkStatus() async {
    try {
      final res = await http.get(Uri.parse('$serverUrl/api/whatsapp/status/${widget.email}'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          isConnected = data['connected'] == true;
          pairingCode = data['pairingCode'];
        });
      }
    } catch (_) {}
  }

  Future<void> requestPairing() async {
    setState(() => isPairingLoading = true);
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
      if (mounted) setState(() => isPairingLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text('Lop-Client', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isConnected ? const Color(0xFF064E3B) : const Color(0xFF3F1D28),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isConnected ? const Color(0xFF10B981) : Colors.redAccent, width: 0.8),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 4,
                  backgroundColor: isConnected ? const Color(0xFF10B981) : Colors.redAccent,
                ),
                const SizedBox(width: 6),
                Text(
                  isConnected ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: isConnected ? const Color(0xFF10B981) : Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF0F172A),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF131B2E)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFF10B981),
                    radius: 24,
                    child: Icon(Icons.smart_toy, color: Colors.black),
                  ),
                  const SizedBox(height: 12),
                  Text(widget.email, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(widget.isAdmin ? 'Role: Super Admin' : 'Role: Standard User',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.qr_code, color: Color(0xFF10B981)),
              title: const Text('Pairing & Status WA'),
              selected: currentTabIndex == 0,
              onTap: () {
                setState(() => currentTabIndex = 0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.extension, color: Color(0xFF6366F1)),
              title: const Text('Fitur & Prefix Bot'),
              selected: currentTabIndex == 1,
              onTap: () {
                setState(() => currentTabIndex = 1);
                Navigator.pop(context);
              },
            ),
            if (widget.isAdmin)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings, color: Colors.amber),
                title: const Text('Admin Panel'),
                selected: currentTabIndex == 2,
                onTap: () {
                  setState(() => currentTabIndex = 2);
                  Navigator.pop(context);
                },
              ),
            const Divider(color: Color(0xFF1E293B)),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Logout'),
              onTap: widget.onLogout,
            ),
          ],
        ),
      ),
      body: currentTabIndex == 0
          ? _buildPairingView()
          : currentTabIndex == 1
              ? _buildFeaturesView()
              : _buildAdminView(),
    );
  }

  Widget _buildPairingView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isConnected ? Icons.check_circle : Icons.sync_problem,
                        color: isConnected ? const Color(0xFF10B981) : Colors.orangeAccent,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isConnected ? 'WhatsApp Terhubung' : 'WhatsApp Belum Tertaut',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isConnected
                      ? 'Bot sedang aktif berjalan di server 24/7 di latar belakang.'
                      : 'Masukkan nomor WhatsApp bot Anda untuk meminta kode pairing.',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (!isConnected) ...[
            const Text('Nomor WhatsApp Bot', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: '628xxxxxxxxxx (Format Internasional)',
                prefixIcon: Icon(Icons.phone, color: Color(0xFF94A3B8)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isPairingLoading ? null : requestPairing,
                icon: const Icon(Icons.vpn_key, color: Colors.black),
                label: Text(isPairingLoading ? 'Meminta Kode...' : 'Dapatkan Pairing Code'),
              ),
            ),
            if (pairingCode != null) ...[
              const SizedBox(height: 24),
              Card(
                color: const Color(0xFF0F172A),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text('MASUKKAN KODE INI DI WHATSAPP HP:',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, letterSpacing: 1)),
                      const SizedBox(height: 12),
                      SelectableText(
                        pairingCode!,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                          color: Color(0xFF10B981),
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF334155)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: pairingCode!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Kode pairing disalin ke clipboard!')),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 16, color: Color(0xFFCBD5E1)),
                        label: const Text('Salin Kode', style: TextStyle(color: Color(0xFFCBD5E1))),
                      )
                    ],
                  ),
                ),
              )
            ]
          ]
        ],
      ),
    );
  }

  Widget _buildFeaturesView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Custom Prefix', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: ['!', '.', '/', '#'].map((p) {
              final isSelected = customPrefix == p;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(p, style: TextStyle(color: isSelected ? Colors.black : Colors.white)),
                  selected: isSelected,
                  selectedColor: const Color(0xFF10B981),
                  backgroundColor: const Color(0xFF1E293B),
                  onSelected: (val) => setState(() => customPrefix = p),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text('Fitur Bawaan Bot', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...activeFeatures.entries.map((entry) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: SwitchListTile(
                title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                value: entry.value,
                activeColor: const Color(0xFF10B981),
                onChanged: (val) => setState(() => activeFeatures[entry.key] = val),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAdminView() {
    return const AdminPanel();
  }
}

// -------------------------------------------------------------
// 4. ADMIN PANEL (TOKEN MANAGEMENT & GENERATOR)
// -------------------------------------------------------------
class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});
  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  final tokenCtrl = TextEditingController();
  int expiryDays = 30;
  List<dynamic> tokens = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchTokens();
  }

  Future<void> fetchTokens() async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(Uri.parse('$serverUrl/api/admin/tokens?adminKey=LOP_SUPER_ADMIN_SECRET'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() => tokens = data['tokens'] ?? []);
      }
    } catch (_) {}
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> generateToken() async {
    if (tokenCtrl.text.isEmpty) return;
    try {
      await http.post(
        Uri.parse('$serverUrl/api/admin/token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'adminKey': 'LOP_SUPER_ADMIN_SECRET',
          'token': tokenCtrl.text.trim().toUpperCase(),
          'expiresInDays': expiryDays
        }),
      );
      tokenCtrl.clear();
      fetchTokens();
    } catch (_) {}
  }

  Future<void> deleteToken(String token) async {
    try {
      await http.post(
        Uri.parse('$serverUrl/api/admin/token/delete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'adminKey': 'LOP_SUPER_ADMIN_SECRET', 'token': token}),
      );
      fetchTokens();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Panel Administrator', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Kelola token aktivasi dan masa aktif user.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Buat Token Baru', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tokenCtrl,
                    decoration: const InputDecoration(labelText: 'Kode Token (Misal: LOP-USER-01)'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Masa Aktif: ', style: TextStyle(color: Color(0xFF94A3B8))),
                      DropdownButton<int>(
                        value: expiryDays,
                        dropdownColor: const Color(0xFF1E293B),
                        items: [7, 30, 90, 365].map((d) => DropdownMenuItem(value: d, child: Text('$d Hari'))).toList(),
                        onChanged: (v) => setState(() => expiryDays = v ?? 30),
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: generateToken,
                      child: const Text('Generate Token'),
                    ),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Daftar Token Aktif', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else if (tokens.isEmpty)
            const Text('Belum ada token tersimpan', style: TextStyle(color: Color(0xFF64748B)))
          else
            ...tokens.map((t) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(t['token'], style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                  subtitle: Text('User: ${t['email'] ?? 'Belum diklaim'}\nExpires: ${t['expires_at'] ?? 'Lifetime'}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () => deleteToken(t['token']),
                  ),
                ),
              );
            })
        ],
      ),
    );
  }
}
