import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math';

// Default backend server URL (dapat diganti lewat ikon settings di login)
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
// 1. SCREEN: AUTH / LOGIN DENGAN TOKEN (PERSISTENT DEVICE ID)
// -------------------------------------------------------------
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final tokenCtrl = TextEditingController();
  bool isLoading = false;
  String? error;

  // ponytail: fallback file storage untuk persist Device ID tanpa dependensi pihak ketiga
  Future<String> _getOrGenerateDeviceId() async {
    try {
      final appDir = Directory.systemTemp;
      final file = File('${appDir.path}/lop_device_id.txt');
      if (await file.exists()) {
        final id = (await file.readAsString()).trim();
        if (id.isNotEmpty) return id;
      }
      final rand = Random.secure();
      final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
      final generated = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      final deviceId = 'dev_$generated';
      await file.writeAsString(deviceId);
      return deviceId;
    } catch (_) {
      return 'dev_${Platform.operatingSystem}_default';
    }
  }

  Future<void> submitLogin() async {
    final token = tokenCtrl.text.trim();
    if (token.isEmpty) {
      setState(() => error = 'Kode Token lisensi / admin wajib diisi');
      return;
    }

    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final deviceId = await _getOrGenerateDeviceId();
      final res = await http.post(
        Uri.parse('$serverUrl/api/auth/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': deviceId, 'token': token}),
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
              isAdmin: body['isAdmin'] == true,
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

              TextField(
                controller: tokenCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Kode Token Lisensi / Admin',
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
              const SizedBox(height: 20),
              const Text('Device ID otomatis di-bind ke token Anda.', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 2. DASHBOARD SATU HALAMAN + ADMIN GENERATOR DI DRAWER
// -------------------------------------------------------------
class DashboardOnePage extends StatefulWidget {
  final String username;
  final String token;
  final bool isAdmin;

  const DashboardOnePage({
    super.key,
    required this.username,
    required this.token,
    this.isAdmin = false,
  });

  @override
  State<DashboardOnePage> createState() => _DashboardOnePageState();
}

class _DashboardOnePageState extends State<DashboardOnePage> {
  bool isConnected = false;
  String? pairingCode;
  bool isPairing = false;
  final phoneCtrl = TextEditingController(text: '6285871087187');
  List<String> terminalLogs = ['[SYS] Terminal log siap.'];
  Timer? pollTimer;
  Map<String, bool> features = {'ping': true};

  // State Generator Token (Jika Login Sebagai Admin)
  List<String> generatedTokens = [];
  bool isGenerating = false;

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
            if (isConnected) isPairing = false;
          });
        }
      }

      final logRes = await http.get(Uri.parse('$serverUrl/api/whatsapp/logs/${widget.username}'));
      if (logRes.statusCode == 200) {
        final logData = jsonDecode(logRes.body);
        if (mounted) {
          setState(() {
            terminalLogs = List<String>.from(logData['logs'] ?? []);
          });
        }
      }

      final featRes = await http.get(Uri.parse('$serverUrl/api/bot/features/${widget.username}'));
      if (featRes.statusCode == 200) {
        final fData = jsonDecode(featRes.body);
        if (mounted) {
          setState(() {
            features = Map<String, bool>.from(fData['features'] ?? {'ping': true});
          });
        }
      }
    } catch (_) {}
  }

  Future<void> toggleFeature(String key, bool val) async {
    final updated = Map<String, bool>.from(features);
    updated[key] = val;
    setState(() => features = updated);
    try {
      await http.post(
        Uri.parse('$serverUrl/api/bot/features'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.username, 'features': updated}),
      );
    } catch (_) {}
  }

  Future<void> requestPairing() async {
    final phone = phoneCtrl.text.trim();
    if (phone.isEmpty) return;
    setState(() => isPairing = true);
    try {
      await http.post(
        Uri.parse('$serverUrl/api/whatsapp/pair'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.username, 'phoneNumber': phone}),
      );
    } catch (_) {
      if (mounted) setState(() => isPairing = false);
    }
  }

  Future<void> disconnectWhatsApp() async {
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
    } catch (_) {}
  }

  Future<void> generateTokenFromApp() async {
    setState(() => isGenerating = true);
    try {
      final res = await http.post(
        Uri.parse('$serverUrl/api/admin/tokens/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'adminToken': widget.token, 'count': 1, 'days': 30}),
      );
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        setState(() {
          generatedTokens.insert(0, data['tokens'][0]);
        });
      }
    } catch (_) {}
    if (mounted) setState(() => isGenerating = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isAdmin ? 'Lop-Client (Super Admin)' : 'Lop-Client'),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF131B2E)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Menu & Fitur Bot', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                    widget.isAdmin ? 'Role: SUPER ADMIN' : 'ID: ${widget.username}',
                    style: TextStyle(color: widget.isAdmin ? const Color(0xFF10B981) : const Color(0xFF94A3B8), fontSize: 12),
                  ),
                ],
              ),
            ),

            // Fitur Toggle
            SwitchListTile(
              title: const Text('Fitur Ping'),
              subtitle: const Text('Balas .ping dengan Pong!'),
              value: features['ping'] ?? false,
              onChanged: (v) => toggleFeature('ping', v),
            ),
            const Divider(),

            // Panel Generator Khusus Admin
            if (widget.isAdmin) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('PANEL ADMIN (TOKEN GENERATOR)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
              ),
              ListTile(
                leading: const Icon(Icons.add_moderator, color: Color(0xFF10B981)),
                title: const Text('Generate Token Baru'),
                subtitle: const Text('Format LOPCLIENT-XXXX-YYYY (30 Hari)'),
                trailing: isGenerating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null,
                onTap: isGenerating ? null : generateTokenFromApp,
              ),
              if (generatedTokens.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    children: generatedTokens.map((t) => Card(
                      color: const Color(0xFF1E293B),
                      child: ListTile(
                        dense: true,
                        title: Text(t, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                        trailing: IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: t));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Token disalin ke Clipboard!')));
                          },
                        ),
                      ),
                    )).toList(),
                  ),
                ),
              const Divider(),
            ],

            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Logout / Ganti Token'),
              onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen())),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    CircleAvatar(radius: 6, backgroundColor: isConnected ? Colors.green : Colors.red),
                    const SizedBox(width: 12),
                    Text(
                      isConnected ? 'Status: ONLINE' : 'Status: OFFLINE',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Nomor Bot WhatsApp
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Nomor WhatsApp Bot', prefixIcon: Icon(Icons.phone)),
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: isConnected ? disconnectWhatsApp : (isPairing ? null : requestPairing),
                    child: Text(isConnected ? 'Disconnect' : (isPairing ? 'Meminta Kode...' : 'Hubungkan')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: requestPairing,
                    child: const Text('Re-Pair'),
                  ),
                ),
              ],
            ),

            // Pairing Code Card
            if (pairingCode != null && !isConnected)
              Card(
                margin: const EdgeInsets.only(top: 20),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text('KODE PAIRING WHATSAPP', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                      const SizedBox(height: 8),
                      SelectableText(
                        pairingCode!,
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 4, color: Color(0xFF10B981)),
                      ),
                      const SizedBox(height: 8),
                      const Text('Masukkan di WhatsApp: Perangkat Tertaut > Tautkan dengan nomor telepon', style: TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),
            const Text('Terminal / Live Logs:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
            const SizedBox(height: 8),

            // Terminal Screen
            Container(
              height: 220,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: ListView(
                children: terminalLogs.map((l) => Text(
                  l,
                  style: const TextStyle(fontFamily: 'monospace', color: Colors.greenAccent, fontSize: 11),
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
