import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import 'todo_model.dart';
import 'database_helper.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Todo> todos = [];
  String? username;
  String? lastRefreshText;
  bool isFromCache = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  // ---------------------------------------------------------------------
  // 1. INIT — Load Username → Load Cache → Jika tidak ada → Load DB
  // ---------------------------------------------------------------------
  Future<void> _initializeData() async {
    await _loadUsername();

    // coba load dari cache
    bool loaded = await _loadCache();

    // jika tidak ada cache → ambil dari DB
    if (!loaded) {
      await _refreshData();
    }
  }

  // ---------------------------------------------------------------------
  // LOAD USERNAME
  // ---------------------------------------------------------------------
  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    username = prefs.getString('username') ?? "User";
    setState(() {});
  }

  // ---------------------------------------------------------------------
  // 2. LOAD FROM CACHE
  // ---------------------------------------------------------------------
  Future<bool> _loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedString = prefs.getString('cached_todos');
    final cachedTime = prefs.getString('last_refresh');

    if (cachedString == null) return false;

    try {
      final List<String> rawItems = cachedString.split('|');
      todos = rawItems.map((item) {
        return Todo.fromMap(_stringToMap(item));
      }).toList();
    } catch (e) {
      return false;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("📦 Data Loaded From Cache"),
        duration: Duration(seconds: 2),
      ),
    );

    if (cachedTime != null) {
      lastRefreshText =
          DateFormat('dd MMM yyyy – HH:mm').format(DateTime.parse(cachedTime));
    }

    isFromCache = true;
    setState(() {});

    return true;
  }

  // Convert string → Map
  Map<String, dynamic> _stringToMap(String s) {
    s = s.replaceAll('{', '').replaceAll('}', '');
    Map<String, dynamic> data = {};

    for (var part in s.split(',')) {
      var kv = part.split(':');
      if (kv.length == 2) {
        data[kv[0].trim()] = kv[1].trim();
      }
    }

    return {
      'id': data['id'],
      'title': data['title'],
      'category': data['category'],
      'deadline': data['deadline'] == 'null' ? null : data['deadline'],
      'isUrgent': data['isUrgent'] == '1',
      'isCompleted': data['isCompleted'] == '1',
      'username': data['username'],
    };
  }

  // ---------------------------------------------------------------------
  // 3. SAVE CACHE
  // ---------------------------------------------------------------------
  Future<void> _saveCache(List<Todo> list) async {
    final prefs = await SharedPreferences.getInstance();
    final encodedList = list.map((e) => e.toMap().toString()).join('|');

    prefs.setString('cached_todos', encodedList);
    prefs.setString('last_refresh', DateTime.now().toIso8601String());
  }

  // ---------------------------------------------------------------------
  // 4. REFRESH — Ambil data terbaru dari database
  // ---------------------------------------------------------------------
  Future<void> _refreshData() async {
    if (username == null) return;

    final result = await DatabaseHelper.instance.readTodosByUser(username!);

    setState(() {
      todos = result;
      isFromCache = false;
      lastRefreshText =
          DateFormat('dd MMM yyyy – HH:mm').format(DateTime.now());
    });

    await _saveCache(result);
  }

  // ---------------------------------------------------------------------
  // 5. CLEAR CACHE
  // ---------------------------------------------------------------------
  Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_todos');
    await prefs.remove('last_refresh');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("🗑️ Cache Berhasil Dihapus")),
    );

    setState(() {
      todos = [];
      lastRefreshText = null;
      isFromCache = false;
    });
  }

  // ---------------------------------------------------------------------
  // LOGOUT
  // ---------------------------------------------------------------------
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("To-Do List"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: _clearCache,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isFromCache)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                "📦 Data from Cache",
                style: TextStyle(color: Colors.orange, fontSize: 15),
              ),
            ),
          if (lastRefreshText != null)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Text(
                "⏱️ Terakhir Refresh: $lastRefreshText",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          Expanded(
            child: todos.isEmpty
                ? const Center(child: Text("Belum ada data"))
                : ListView.builder(
                    itemCount: todos.length,
                    itemBuilder: (context, index) {
                      final todo = todos[index];
                      return Card(
                        child: ListTile(
                          title: Text(todo.title),
                          subtitle: Text(todo.category),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
