import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const String serverUrl = 'http://localhost:3000'; // ponytail: replace with actual VPS IP

void main() => runApp(const LopClientApp());

class LopClientApp extends StatelessWidget {
  const LopClientApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lop-Client',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
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
      isAdmin = mail == 'admin@lop.com'; // ponytail: hardcoded admin check
    });
  }

  void onVerified(String tok) {
    setState(() { 
      token = tok;
      isVerified = true; 
    });
  }

  @override
  Widget build(BuildContext context) {
    if (email == null) return AuthScreen(onLogin: onLogin);
    if (!isVerified) return TokenScreen(email: email!, onVerified: onVerified);
    return Dashboard(email: email!, isAdmin: isAdmin);
  }
}

class AuthScreen extends StatelessWidget {
  final Function(String) onLogin;
  const AuthScreen({super.key, required this.onLogin});

  @override
  Widget build(BuildContext context) {
    final ctrl = TextEditingController();
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Lop-Client', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Email Google', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () => onLogin(ctrl.text), child: const Text('Login dengan Google'))
          ]),
        ),
      ),
    );
  }
}

class TokenScreen extends StatefulWidget {
  final String email;
  final Function(String) onVerified;
  const TokenScreen({super.key, required this.email, required this.onVerified});

  @override
  State<TokenScreen> createState() => _TokenScreenState();
}

class _TokenScreenState extends State<TokenScreen> {
  final ctrl = TextEditingController();
  String? error;

  Future<void> verify() async {
    try {
      final res = await http.post(
        Uri.parse('$serverUrl/api/auth/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.email, 'token': ctrl.text}),
      );
      if (res.statusCode == 200) {
        widget.onVerified(ctrl.text);
      } else {
        setState(() => error = jsonDecode(res.body)['error']);
      }
    } catch (e) {
      setState(() => error = 'Connection failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Token')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Text('Halo, ${widget.email}. Masukkan Token dari Admin.'),
          const SizedBox(height: 16),
          TextField(controller: ctrl, decoration: InputDecoration(labelText: 'Token', errorText: error, border: const OutlineInputBorder())),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: verify, child: const Text('Aktivasi'))
        ]),
      ),
    );
  }
}

class Dashboard extends StatefulWidget {
  final String email;
  final bool isAdmin;
  const Dashboard({super.key, required this.email, required this.isAdmin});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      PairingPage(email: widget.email),
      const BotSettingsPage(),
      if (widget.isAdmin) AdminPanel() else const Center(child: Text('Coming Soon')),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Lop-Client Dashboard')),
      drawer: Drawer(
        child: ListView(children: [
          UserAccountsDrawerHeader(accountName: Text(widget.email), accountEmail: null),
          ListTile(leading: const Icon(Icons.link), title: const Text('WA Pairing'), onTap: () => setState(() { _index = 0; Navigator.pop(context); })),
          ListTile(leading: const Icon(Icons.settings), title: const Text('Bot Settings'), onTap: () => setState(() { _index = 1; Navigator.pop(context); })),
          if (widget.isAdmin) ListTile(leading: const Icon(Icons.admin_panel_settings), title: const Text('Admin Panel'), onTap: () => setState(() { _index = 2; Navigator.pop(context); })),
        ]),
      ),
      body: pages[_index],
    );
  }
}

class PairingPage extends StatefulWidget {
  final String email;
  const PairingPage({super.key, required this.email});
  @override
  State<PairingPage> createState() => _PairingPageState();
}

class _PairingPageState extends State<PairingPage> {
  final phoneCtrl = TextEditingController();
  String? pairingCode;
  bool loading = false;

  Future<void> requestPairing() async {
    setState(() => loading = true);
    try {
      final res = await http.post(
        Uri.parse('$serverUrl/api/whatsapp/pair'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.email, 'phoneNumber': phoneCtrl.text}),
      );
      if (res.statusCode == 200) {
        setState(() => pairingCode = jsonDecode(res.body)['pairingCode']);
      }
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        if (pairingCode == null) ...[
          TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Nomor WA (628xxx)', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: loading ? null : requestPairing, child: Text(loading ? 'Minta Kode...' : 'Dapatkan Pairing Code')),
        ] else ...[
          const Text('Masukkan kode ini di WhatsApp Anda:', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
            child: Text(pairingCode!, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4)),
          ),
          const SizedBox(height: 32),
          const CircularProgressIndicator(),
          const Text('Menunggu koneksi...')
        ]
      ]),
    );
  }
}

class BotSettingsPage extends StatelessWidget {
  const BotSettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Column(children: [
        TextField(decoration: InputDecoration(labelText: 'Custom Prefix', hintText: '!', border: OutlineInputBorder())),
        SizedBox(height: 16),
        ListTile(title: Text('Fitur Bawaan'), trailing: Icon(Icons.check_circle, color: Colors.green)),
        Divider(),
        Text('Fitur Custom (Coming Soon)'),
      ]),
    );
  }
}

class AdminPanel extends StatelessWidget {
  final tokenCtrl = TextEditingController();
  final emailCtrl = TextEditingController();

  AdminPanel({super.key});

  Future<void> createToken() async {
    await http.post(
      Uri.parse('$serverUrl/api/admin/token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'adminKey': 'LOP_SUPER_ADMIN_SECRET',
        'token': tokenCtrl.text,
        'email': emailCtrl.text.isEmpty ? null : emailCtrl.text,
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const Text('Admin: Generate Token', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextField(controller: tokenCtrl, decoration: const InputDecoration(labelText: 'New Token', border: OutlineInputBorder())),
        const SizedBox(height: 16),
        TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Target Email (Optional)', border: OutlineInputBorder())),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: createToken, child: const Text('Generate & Save')),
      ]),
    );
  }
}
