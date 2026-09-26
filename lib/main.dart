import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const dailyLimitMb = 10 * 1024;

void main() {
  runApp(const EsimQuotaApp());
}

class EsimQuotaApp extends StatelessWidget {
  const EsimQuotaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eSIM Daily Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthPage(),
    );
  }
}

class AppStorage {
  static Future<SharedPreferences> get _prefs async =>
      SharedPreferences.getInstance();

  static String todayKey() => DateTime.now().toIso8601String().substring(0, 10);

  static Future<void> ensureUserState() async {
    final prefs = await _prefs;
    final usersString = prefs.getString('users') ?? '{}';
    final users = jsonDecode(usersString) as Map<String, dynamic>;

    for (final entry in users.entries) {
      final user = entry.value as Map<String, dynamic>;
      final quotaDate = user['quotaDate'] as String? ?? todayKey();
      if (quotaDate != todayKey()) {
        user['usedMb'] = 0;
        user['quotaDate'] = todayKey();
      }
    }

    await prefs.setString('users', jsonEncode(users));
  }

  static Future<Map<String, dynamic>> loadUsers() async {
    await ensureUserState();
    final prefs = await _prefs;
    final data = prefs.getString('users') ?? '{}';
    final decoded = jsonDecode(data);
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }

  static Future<void> saveUsers(Map<String, dynamic> users) async {
    final prefs = await _prefs;
    await prefs.setString('users', jsonEncode(users));
  }

  static Future<bool> registerUser(String phone, String password) async {
    final phoneNumber = phone.trim();
    if (phoneNumber.isEmpty || password.trim().isEmpty) {
      return false;
    }

    final users = await loadUsers();
    if (users.containsKey(phoneNumber)) {
      return false;
    }

    users[phoneNumber] = {
      'phone': phoneNumber,
      'password': password,
      'usedMb': 0,
      'quotaDate': todayKey(),
    };

    await saveUsers(users);
    await setLoggedInPhone(phoneNumber);
    return true;
  }

  static Future<bool> loginUser(String phone, String password) async {
    final phoneNumber = phone.trim();
    final users = await loadUsers();
    final user = users[phoneNumber];

    if (user == null) {
      return false;
    }

    final storedPassword = user['password'] as String? ?? '';
    if (storedPassword != password) {
      return false;
    }

    await setLoggedInPhone(phoneNumber);
    return true;
  }

  static Future<void> setLoggedInPhone(String phone) async {
    final prefs = await _prefs;
    await prefs.setString('loggedInPhone', phone);
  }

  static Future<String?> getLoggedInPhone() async {
    final prefs = await _prefs;
    return prefs.getString('loggedInPhone');
  }

  static Future<void> logout() async {
    final prefs = await _prefs;
    await prefs.remove('loggedInPhone');
  }

  static Future<Map<String, dynamic>> getCurrentUser() async {
    final phone = await getLoggedInPhone();
    if (phone == null) {
      return {};
    }

    final users = await loadUsers();
    return users[phone] ?? {};
  }

  static Future<int> getUsedMbForPhone(String phone) async {
    final users = await loadUsers();
    final user = users[phone];
    if (user == null) {
      return 0;
    }

    final date = user['quotaDate'] as String? ?? todayKey();
    if (date != todayKey()) {
      user['usedMb'] = 0;
      user['quotaDate'] = todayKey();
      await saveUsers(users);
    }

    return (user['usedMb'] as num?)?.toInt() ?? 0;
  }

  static Future<bool> useDataForPhone(String phone, int amountMb) async {
    final users = await loadUsers();
    final user = users[phone];
    if (user == null) {
      return false;
    }

    final date = user['quotaDate'] as String? ?? todayKey();
    if (date != todayKey()) {
      user['usedMb'] = 0;
      user['quotaDate'] = todayKey();
    }

    final currentlyUsed = (user['usedMb'] as num?)?.toInt() ?? 0;
    if (amountMb <= 0 || currentlyUsed + amountMb > dailyLimitMb) {
      return false;
    }

    user['usedMb'] = currentlyUsed + amountMb;
    await saveUsers(users);
    return true;
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLogin = false;
  bool loading = false;

  Future<void> submit() async {
    final phone = phoneController.text.trim();
    final password = passwordController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      _showMessage('Phone number and password are required.');
      return;
    }

    setState(() => loading = true);

    bool success;
    if (isLogin) {
      success = await AppStorage.loginUser(phone, password);
    } else {
      success = await AppStorage.registerUser(phone, password);
    }

    setState(() => loading = false);

    if (!success) {
      _showMessage(
        isLogin
            ? 'Invalid phone number or password.'
            : 'This phone number is already registered or the data is invalid.',
      );
      return;
    }

    final currentPhone = await AppStorage.getLoggedInPhone();
    if (!mounted) return;

    if (currentPhone != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardPage(phone: currentPhone),
        ),
      );
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isLogin ? 'Login to Your Account' : 'Register Your Phone'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sim_card, size: 72, color: Colors.blue),
            const SizedBox(height: 20),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                hintText: 'e.g. 08012345678',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: loading ? null : submit,
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(isLogin ? 'Login' : 'Register'),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => isLogin = !isLogin),
              child: Text(
                isLogin ? 'Need an account? Register' : 'Already have an account? Login',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({required this.phone, super.key});

  final String phone;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late int usedMb;
  final usageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    usedMb = 0;
    _loadUsage();
  }

  Future<void> _loadUsage() async {
    final value = await AppStorage.getUsedMbForPhone(widget.phone);
    if (mounted) {
      setState(() => usedMb = value);
    }
  }

  Future<void> _useData() async {
    final value = int.tryParse(usageController.text.trim());
    if (value == null || value <= 0) {
      _showMessage('Enter a valid amount in MB.');
      return;
    }

    final success = await AppStorage.useDataForPhone(widget.phone, value);
    if (!success) {
      _showMessage('You have reached your daily 10GB limit.');
      return;
    }

    usageController.clear();
    await _loadUsage();
    _showMessage('Data usage updated.');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatMb(int mb) {
    if (mb >= 1024) {
      final gb = mb / 1024;
      return '${gb.toStringAsFixed(gb.roundToDouble() == gb ? 0 : 1)} GB';
    }
    return '$mb MB';
  }

  @override
  Widget build(BuildContext context) {
    final remainingMb = dailyLimitMb - usedMb;
    final progress = (usedMb / dailyLimitMb).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Data'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AppStorage.logout();
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const AuthPage()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUsage,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text('Registered phone', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              widget.phone,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 28),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text('Daily allowance', style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 12),
                    Text(
                      '${_formatMb(remainingMb)} remaining',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 18),
                    LinearProgressIndicator(value: progress, minHeight: 12),
                    const SizedBox(height: 12),
                    Text('${_formatMb(usedMb)} used of ${_formatMb(dailyLimitMb)}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: usageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Use data',
                hintText: 'Example: 500 MB',
                border: OutlineInputBorder(),
                suffixText: 'MB',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _useData,
              icon: const Icon(Icons.data_usage),
              label: const Text('Apply Usage'),
            ),
            const SizedBox(height: 24),
            const Text(
              'The 10GB daily limit resets automatically each day.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
