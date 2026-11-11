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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

  Future<void> login() async {
    setState(() { isLoading = true; error = null; });
    try {
      final res = await http.post(
        Uri.parse('$serverUrl/api/auth/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': userCtrl.text.trim(), 'token': tokenCtrl.text.trim()}),
      );
      final body = jsonDecode(res.body);
      if (res.statusCode == 200) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => DashboardScreen(username: body['username'], isAdmin: body['isAdmin'])),
        );
      } else {
        setState(() => error = body['error'] ?? 'Login gagal');
      }
    } catch (_) {
      setState(() => error = 'Gagal ke server');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Icon(Icons.bolt, size: 60, color: Color(0xFF10B981)),
              const SizedBox(height: 20),
              const Text('Lop-Client', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              TextField(controller: userCtrl, decoration: const InputDecoration(labelText: 'Username')),
              const SizedBox(height: 12),
              TextField(controller: tokenCtrl, decoration: const InputDecoration(labelText: 'Kode Token')),
              if (error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(error!, style: const TextStyle(color: Colors.red))),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: isLoading ? null : login, child: const Text('MASUK'))),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final String username;
  final bool isAdmin;
  const DashboardScreen({super.key, required this.username, required this.isAdmin});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool isConnected = false;
  String? pairingCode;
  List<String> terminalLogs = ['[SYS] Terminal siap.'];
  Timer? pollTimer;

  @override
  void initState() {
    super.initState();
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
        if (mounted) setState(() { isConnected = data['connected']; pairingCode = data['pairingCode']; });
      }
      final logRes = await http.get(Uri.parse('$serverUrl/api/whatsapp/logs/${widget.username}'));
      if (logRes.statusCode == 200) setState(() => terminalLogs = List<String>.from(jsonDecode(logRes.body)['logs']));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Dashboard: ${widget.username}'), actions: [if(widget.isAdmin) IconButton(icon: const Icon(Icons.settings), onPressed: (){})]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Card(child: ListTile(title: Text('Status: ${isConnected ? "ONLINE" : "OFFLINE"}'), trailing: Switch(value: isConnected, onChanged: (_){}))),
            if (pairingCode != null) Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('Pairing: $pairingCode', style: const TextStyle(fontSize: 20, color: Color(0xFF10B981))))),
            const SizedBox(height: 20),
            Container(height: 200, color: Colors.black, child: ListView(children: terminalLogs.map((l) => Text(l)).toList())),
          ],
        ),
      ),
    );
  }
}
