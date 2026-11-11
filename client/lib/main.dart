import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

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
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E293B),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.black),
        ),
      ),
      home: const AuthScreen(),
    );
  }
}

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
    setState(() { isLoading = true; error = null; });
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
          MaterialPageRoute(builder: (_) => DashboardOnePage(username: body['username'], token: body['token'])),
        );
      } else {
        setState(() => error = body['error'] ?? 'Autentikasi gagal');
      }
    } catch (_) {
      setState(() => error = 'Gagal menghubungi server');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, actions: [
        IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => _showServerSettings())
      ]),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Icon(Icons.bolt, size: 60, color: Color(0xFF10B981)),
              const SizedBox(height: 18),
              const Text('Lop-Client', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 32),
              TextField(controller: userCtrl, decoration: const InputDecoration(labelText: 'Gmail / Username', prefixIcon: Icon(Icons.person_outline))),
              const SizedBox(height: 14),
              TextField(controller: tokenCtrl, decoration: const InputDecoration(labelText: 'Kode Token', prefixIcon: Icon(Icons.key_outlined))),
              if (error != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(error!, style: const TextStyle(color: Colors.redAccent))),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: isLoading ? null : submitLogin, child: const Text('MASUK DASHBOARD'))),
            ],
          ),
        ),
      ),
    );
  }

  void _showServerSettings() {
    final ctrl = TextEditingController(text: serverUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Server URL'),
        content: TextField(controller: ctrl),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(onPressed: () { setState(() => serverUrl = ctrl.text.trim()); Navigator.pop(ctx); }, child: const Text('Simpan')),
        ],
      ),
    );
  }
}

class DashboardOnePage extends StatefulWidget {
  final String username;
  final String token;
  const DashboardOnePage({super.key, required this.username, required this.token});
  @override
  State<DashboardOnePage> createState() => _DashboardOnePageState();
}

class _DashboardOnePageState extends State<DashboardOnePage> {
  bool isConnected = false;
  String? pairingCode;
  final phoneCtrl = TextEditingController(text: '6285871087187');
  List<String> terminalLogs = ['[SYS] Terminal siap.'];
  Timer? pollTimer;
  Map<String, bool> features = {'ping': true};

  @override
  void initState() {
    super.initState();
    refreshAll();
    pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => refreshAll());
  }

  @override
  void dispose() { pollTimer?.cancel(); super.dispose(); }

  Future<void> refreshAll() async {
    try {
      final res = await http.get(Uri.parse('$serverUrl/api/whatsapp/status/${widget.username}'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) setState(() { isConnected = data['connected']; pairingCode = data['pairingCode']; });
      }
      final logRes = await http.get(Uri.parse('$serverUrl/api/whatsapp/logs/${widget.username}'));
      if (logRes.statusCode == 200) {
        final logData = jsonDecode(logRes.body);
        if (mounted) setState(() => terminalLogs = List<String>.from(logData['logs']));
      }
      final featRes = await http.get(Uri.parse('$serverUrl/api/bot/features/${widget.username}'));
      if (featRes.statusCode == 200) {
        final fData = jsonDecode(featRes.body);
        if (mounted) setState(() => features = Map<String, bool>.from(fData['features']));
      }
    } catch (_) {}
  }

  Future<void> toggleFeature(String key, bool val) async {
    final updated = Map<String, bool>.from(features);
    updated[key] = val;
    setState(() => features = updated);
    await http.post(
      Uri.parse('$serverUrl/api/bot/features'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': widget.username, 'features': updated}),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lop-Client'), backgroundColor: const Color(0xFF0F172A), elevation: 0),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(decoration: BoxDecoration(color: Color(0xFF131B2E)), child: Text('Menu Fitur Bot', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
            SwitchListTile(
              title: const Text('Fitur Ping'),
              subtitle: const Text('Balas .ping dengan Pong!'),
              value: features['ping'] ?? false,
              onChanged: (v) => toggleFeature('ping', v),
            ),
            const Divider(),
            ListTile(leading: const Icon(Icons.logout), title: const Text('Logout'), onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen()))),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
              CircleAvatar(radius: 6, backgroundColor: isConnected ? Colors.green : Colors.red),
              const SizedBox(width: 12),
              Text(isConnected ? 'Status: ONLINE' : 'Status: OFFLINE', style: const TextStyle(fontWeight: FontWeight.bold)),
            ]))),
            const SizedBox(height: 18),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Nomor Bot', prefixIcon: Icon(Icons.phone))),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: ElevatedButton(onPressed: () {}, child: Text(isConnected ? 'Disconnect' : 'Connect'))),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton(onPressed: () {}, child: const Text('Re-Pair'))),
            ]),
            if (pairingCode != null && !isConnected) Card(margin: const EdgeInsets.only(top: 20), child: Padding(padding: const EdgeInsets.all(20), child: Text(pairingCode!, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4, color: Color(0xFF10B981))))),
            const SizedBox(height: 24),
            Container(height: 200, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12)), child: ListView(children: terminalLogs.map((l) => Text(l, style: const TextStyle(fontFamily: 'monospace', color: Colors.green, fontSize: 11))).toList())),
          ],
        ),
      ),
    );
  }
}
