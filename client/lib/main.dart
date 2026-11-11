import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math';

// Default backend server URL (dapat diganti via ikon settings di login)
String serverUrl = 'http://192.168.111.98:3000';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Cek apakah ada saved token sebelumnya agar langsung masuk dashboard (tidak reset saat restart app)
  final prefs = await SharedPreferences.getInstance();
  final savedToken = prefs.getString('saved_token');
  final savedUsername = prefs.getString('saved_username');
  final savedIsAdmin = prefs.getBool('saved_is_admin') ?? false;

  runApp(LopClientApp(
    initialToken: savedToken,
    initialUsername: savedUsername,
    initialIsAdmin: savedIsAdmin,
  ));
}

class LopClientApp extends StatelessWidget {
  final String? initialToken;
  final String? initialUsername;
  final bool initialIsAdmin;

  const LopClientApp({
    super.key,
    this.initialToken,
    this.initialUsername,
    this.initialIsAdmin = false,
  });

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
      home: (initialToken != null && initialUsername != null)
          ? DashboardOnePage(username: initialUsername!, token: initialToken!, isAdmin: initialIsAdmin)
          : const AuthScreen(),
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
        // Simpan sesi login agar tidak reset saat restart app
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_token', body['token']);
        await prefs.setString('saved_username', body['username']);
        await prefs.setBool('saved_is_admin', body['isAdmin'] == true);

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
// 2. DASHBOARD SATU HALAMAN + ADMIN GENERATOR & TABEL TOKEN DI DRAWER
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

  // Disconnect UI saja TANPA menghapus pairing / session Baileys di latar belakang
  void disconnectUIOnly() {
    setState(() {
      isConnected = false;
      pairingCode = null;
      isPairing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tampilan ditutup. Bot tetap berjalan di latar belakang server.')));
  }

  Future<void> logoutApp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_token');
    await prefs.remove('saved_username');
    await prefs.remove('saved_is_admin');

    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
  }

  void _openAdminTokenManager() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminTokenManagerScreen(adminToken: widget.token)),
    );
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

            // Panel Generator & Tabel Token Khusus Admin
            if (widget.isAdmin) ...[
              ListTile(
                leading: const Icon(Icons.admin_panel_settings, color: Color(0xFF10B981)),
                title: const Text('Kelola & Generate Token'),
                subtitle: const Text('Opsi 7 hari, 2 minggu, 1 bulan, custom'),
                onTap: () {
                  Navigator.pop(context);
                  _openAdminTokenManager();
                },
              ),
              const Divider(),
            ],

            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Logout / Ganti Token'),
              onTap: logoutApp,
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
                      isConnected ? 'Status: ONLINE (Latar Belakang)' : 'Status: OFFLINE',
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
                    onPressed: isPairing ? null : requestPairing,
                    child: Text(isPairing ? 'Meminta Kode...' : 'Hubungkan / Re-Pair'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: disconnectUIOnly,
                    child: const Text('Disconnect (Background Run)'),
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

// -------------------------------------------------------------
// 3. ADMIN TOKEN MANAGER SCREEN (TABEL TOKEN & OPSI GENERATE)
// -------------------------------------------------------------
class AdminTokenManagerScreen extends StatefulWidget {
  final String adminToken;
  const AdminTokenManagerScreen({super.key, required this.adminToken});

  @override
  State<AdminTokenManagerScreen> createState() => _AdminTokenManagerScreenState();
}

class _AdminTokenManagerScreenState extends State<AdminTokenManagerScreen> {
  List<dynamic> tokensList = [];
  bool isLoading = true;
  String selectedDuration = '30'; // Default 1 bulan (30 hari)
  final customDaysCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchTokens();
  }

  Future<void> fetchTokens() async {
    setState(() => isLoading = true);
    try {
      final res = await http.post(
        Uri.parse('$serverUrl/api/admin/tokens/list'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'adminToken': widget.adminToken}),
      );
      final body = jsonDecode(res.body);
      if (body['success'] == true) {
        setState(() => tokensList = body['tokens']);
      }
    } catch (_) {}
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> generateNewToken(int days) async {
    try {
      final res = await http.post(
        Uri.parse('$serverUrl/api/admin/tokens/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'adminToken': widget.adminToken, 'count': 1, 'days': days}),
      );
      final body = jsonDecode(res.body);
      if (body['success'] == true) {
        fetchTokens();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Token Berhasil Dibuat: ${body['tokens'][0]}')));
      }
    } catch (_) {}
  }

  Future<void> deleteToken(String token) async {
    try {
      await http.post(
        Uri.parse('$serverUrl/api/admin/tokens/delete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'adminToken': widget.adminToken, 'token': token}),
      );
      fetchTokens();
    } catch (_) {}
  }

  Future<void> resetUserBinding(String token) async {
    try {
      await http.post(
        Uri.parse('$serverUrl/api/admin/tokens/reset-user'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'adminToken': widget.adminToken, 'token': token}),
      );
      fetchTokens();
    } catch (_) {}
  }

  void _showGenerateDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF131B2E),
          title: const Text('Generate Token Baru'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedDuration,
                dropdownColor: const Color(0xFF1E293B),
                decoration: const InputDecoration(labelText: 'Masa Aktif'),
                items: const [
                  DropdownMenuItem(value: '7', child: Text('7 Hari (1 Minggu)')),
                  DropdownMenuItem(value: '14', child: Text('14 Hari (2 Minggu)')),
                  DropdownMenuItem(value: '30', child: Text('30 Hari (1 Bulan)')),
                  DropdownMenuItem(value: 'custom', child: Text('Custom Hari')),
                ],
                onChanged: (v) => setState(() => selectedDuration = v ?? '30'),
              ),
              if (selectedDuration == 'custom') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: customDaysCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Jumlah Hari', hintText: 'Contoh: 45'),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                int days = 30;
                if (selectedDuration == 'custom') {
                  days = int.tryParse(customDaysCtrl.text.trim()) ?? 30;
                } else {
                  days = int.tryParse(selectedDuration) ?? 30;
                }
                generateNewToken(days);
              },
              child: const Text('Generate'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Token & Masa Aktif'),
        backgroundColor: const Color(0xFF0F172A),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showGenerateDialog,
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('Buat Token'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tokensList.length,
              itemBuilder: (context, index) {
                final item = tokensList[index];
                final token = item['token'];
                final assignedUser = item['assigned_user'] ?? 'Belum Digunakan';
                final expiresAt = item['expires_at'] ?? 'Selamanya';
                final isActive = item['is_active'] == 1;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(token, style: const TextStyle(fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 18),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: token));
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Token disalin!')));
                              },
                            ),
                          ],
                        ),
                        const Divider(),
                        Text('Perangkat: $assignedUser', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                        const SizedBox(height: 4),
                        Text('Expired: $expiresAt', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (item['assigned_user'] != null)
                              TextButton.icon(
                                icon: const Icon(Icons.lock_reset, size: 16, color: Colors.amber),
                                label: const Text('Reset Binding', style: TextStyle(color: Colors.amber, fontSize: 12)),
                                onPressed: () => resetUserBinding(token),
                              ),
                            TextButton.icon(
                              icon: const Icon(Icons.delete, size: 16, color: Colors.redAccent),
                              label: const Text('Hapus', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                              onPressed: () => deleteToken(token),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
