import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

// Default backend server URL (bisa diubah lewat ikon settings)
String serverUrl = 'http://192.168.111.98:3000';

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
      home: const AuthScreen(),
    );
  }
}

// -------------------------------------------------------------
// 1. SCREEN: AUTH / LOGIN DENGAN USERNAME/EMAIL & TOKEN
// -------------------------------------------------------------
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final userCtrl = TextEditingController();
  final tokenCtrl = TextEditingController();
  bool isLoading = false;
  String? error;

  Future<void> submitLogin() async {
    final username = userCtrl.text.trim();
    final token = tokenCtrl.text.trim();

    if (username.isEmpty || token.isEmpty) {
      setState(() => error = 'Email/Username dan Token wajib diisi');
      return;
    }

    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final res = await http.post(
        Uri.parse('$serverUrl/api/auth/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'token': token}),
      );

      final body = jsonDecode(res.body);
      if (res.statusCode == 200 && body['success'] == true) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DashboardOnePage(
              username: body['username'],
              token: body['token'],
              expiresAt: body['expiresAt'],
            ),
          ),
        );
      } else {
        setState(() => error = body['error'] ?? 'Autentikasi gagal');
      }
    } catch (_) {
      setState(() => error = 'Gagal menghubungi server ($serverUrl)');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showServerSettings() {
    final ctrl = TextEditingController(text: serverUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131B2E),
        title: const Text('Server Backend URL'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'URL Server', hintText: 'http://IP-SERVER:3000'),
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
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF10B981).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))
                  ],
                ),
                child: const Icon(Icons.bolt, size: 44, color: Colors.black),
              ),
              const SizedBox(height: 18),
              const Text('Lop-Client', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              const Text('Self-Host WhatsApp Automation UI', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
              const SizedBox(height: 32),

              // Username / Gmail Input
              TextField(
                controller: userCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Gmail / Username Akun',
                  hintText: 'nama@gmail.com',
                  prefixIcon: Icon(Icons.person_outline, color: Color(0xFF94A3B8)),
                ),
              ),
              const SizedBox(height: 14),

              // Token Input
              TextField(
                controller: tokenCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Kode Token Lisensi',
                  hintText: 'LOPCLIENT-XXXX-YYYY',
                  prefixIcon: const Icon(Icons.key_outlined, color: Color(0xFF94A3B8)),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.paste, color: Color(0xFF94A3B8)),
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      if (data?.text != null) tokenCtrl.text = data!.text!.trim();
                    },
                  ),
                ),
              ),

              if (error != null) ...[
                const SizedBox(height: 14),
                Text(error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13), textAlign: TextAlign.center),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : submitLogin,
                  child: Text(isLoading ? 'Memvalidasi...' : 'Masuk Dashboard'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 2. SCREEN: DASHBOARD 1-PAGE (CONNECT, DISCONNECT, RE-PAIR, LOGS)
// -------------------------------------------------------------
class DashboardOnePage extends StatefulWidget {
  final String username;
  final String token;
  final String? expiresAt;

  const DashboardOnePage({
    super.key,
    required this.username,
    required this.token,
    this.expiresAt,
  });

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
      final res = await http.get(Uri.parse('$serverUrl/api/whatsapp/status/${widget.username}'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            isConnected = data['connected'] == true;
            pairingCode = data['pairingCode'];
          });
        }
      }
      final logRes = await http.get(Uri.parse('$serverUrl/api/whatsapp/logs/${widget.username}'));
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
        body: jsonEncode({'email': widget.username, 'phoneNumber': phoneCtrl.text.trim()}),
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
        body: jsonEncode({'email': widget.username}),
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

  void logout() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
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
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF94A3B8)),
            onPressed: logout,
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
                            'User: ${widget.username} (${widget.token})',
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
            const Text('Nomor WhatsApp Bot', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
