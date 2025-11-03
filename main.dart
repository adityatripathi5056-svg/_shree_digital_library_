import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await AppDatabase.open();
  runApp(ShreeApp(database: db));
}

class ShreeApp extends StatelessWidget {
  final AppDatabase database;
  const ShreeApp({super.key, required this.database});
  @override
  Widget build(BuildContext context) {
    final primary = Colors.black;
    final accent = Color(0xFFFFD54F); // gold
    return MaterialApp(
      title: 'Shree Digital Library',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: primary,
        primaryColor: primary,
        colorScheme: ColorScheme.fromSwatch().copyWith(secondary: accent),
        textTheme: const TextTheme(bodyText2: TextStyle(color: Colors.white)),
        appBarTheme: AppBarTheme(backgroundColor: primary, foregroundColor: Colors.white),
        elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black)),
      ),
      home: HomeScreen(db: database),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final AppDatabase db;
  const HomeScreen({super.key, required this.db});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _name = TextEditingController();
  final _seat = TextEditingController();
  String _batch = '7 AM - 12 PM';
  String? _entry;
  String? _exit;
  User? currentUser;
  bool feesSubmittedLocalView = false;

  @override
  void initState() {
    super.initState();
    _loadLastUser();
  }

  Future<void> _loadLastUser() async {
    final u = await widget.db.getLastUser();
    setState(() { currentUser = u; if (u!=null) feesSubmittedLocalView = u.feesSubmitted==1; });
  }

  Future<void> _registerOrLoad() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter name')));
      return;
    }
    final now = DateTime.now();
    final joined = now.toIso8601String().split('T').first;
    final monthComplete = now.add(const Duration(days:30)).toIso8601String().split('T').first;
    final user = User(id:0, name:_name.text.trim(), seat:_seat.text.trim(), batch:_batch, joinedOn:joined, monthCompleteOn:monthComplete, feesSubmitted:0);
    final id = await widget.db.insertUser(user);
    final u2 = await widget.db.getUserById(id);
    setState(() { currentUser = u2; feesSubmittedLocalView = u2?.feesSubmitted==1; });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registered / Loaded')));
  }

  Future<void> _markEntry() async {
    if (currentUser == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Register first'))); return; }
    final now = DateTime.now();
    await widget.db.addLog(currentUser!.id, now.toIso8601String());
    setState(() { _entry = TimeOfDay.fromDateTime(now).format(context); });
  }

  Future<void> _markExit() async {
    if (currentUser == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Register first'))); return; }
    final now = DateTime.now();
    await widget.db.updateLastLogExit(currentUser!.id, now.toIso8601String());
    setState(() { _exit = TimeOfDay.fromDateTime(now).format(context); });
  }

  void _openAdmin() {
    showDialog(context: context, builder: (_) => AdminLoginDialog(db: widget.db));
  }

  @override
  Widget build(BuildContext context) {
    final accent = Color(0xFFFFD54F);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shree Digital Library'),
        actions: [ IconButton(onPressed: _openAdmin, icon: const Icon(Icons.admin_panel_settings)) ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          children: [
            const SizedBox(height:6),
            TextField(controller: _name, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Full Name', labelStyle: TextStyle(color: Colors.white70))),
            const SizedBox(height:8),
            TextField(controller: _seat, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Seat Number', labelStyle: TextStyle(color: Colors.white70)), keyboardType: TextInputType.number),
            const SizedBox(height:8),
            DropdownButtonFormField<String>(
              dropdownColor: Colors.black87,
              value: _batch,
              items: const [
                DropdownMenuItem(value: '7 AM - 12 PM', child: Text('7 AM - 12 PM')),
                DropdownMenuItem(value: '12 PM - 5 PM', child: Text('12 PM - 5 PM')),
                DropdownMenuItem(value: '5 PM - 10 PM', child: Text('5 PM - 10 PM')),
              ],
              onChanged: (v) => setState(() { _batch = v!; }),
              decoration: const InputDecoration(labelText: 'Select Batch', labelStyle: TextStyle(color: Colors.white70)),
            ),
            const SizedBox(height:12),
            Row(children: [
              Expanded(child: ElevatedButton(onPressed: _registerOrLoad, child: const Text('Register / Load'))),
              const SizedBox(width:8),
              Expanded(child: ElevatedButton(onPressed: _markEntry, child: const Text('Mark Entry'))),
              const SizedBox(width:8),
              Expanded(child: ElevatedButton(onPressed: _markExit, child: const Text('Mark Exit'))),
            ]),
            const SizedBox(height:12),
            if (currentUser != null) Card(color: Colors.grey[900], child: ListTile(
              title: Text(currentUser!.name, style: const TextStyle(color: Colors.white)),
              subtitle: Text('Seat: ${currentUser!.seat} | Batch: ${currentUser!.batch}', style: const TextStyle(color: Colors.white70)),
              trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('Joined: ${currentUser!.joinedOn}', style: const TextStyle(color: Colors.white70)),
                Text('Due: ${currentUser!.monthCompleteOn}', style: const TextStyle(color: Colors.white70)),
                Text('Fees: ${currentUser!.feesSubmitted==1 ? "Submitted" : "Pending"}', style: TextStyle(color: currentUser!.feesSubmitted==1?Colors.green:Colors.red)),
              ],),
            )),
            const Spacer(),
            Align(alignment: Alignment.bottomRight, child: Padding(padding: const EdgeInsets.only(bottom:8.0, right:4.0), child: Text('Made by Aditya & Anshik ❤️', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.amber[200])))),
          ],
        ),
      ),
    );
  }
}

// ------------------ Admin ------------------

class AdminLoginDialog extends StatefulWidget {
  final AppDatabase db;
  const AdminLoginDialog({super.key, required this.db});
  @override State<AdminLoginDialog> createState() => _AdminLoginDialogState();
}
class _AdminLoginDialogState extends State<AdminLoginDialog> {
  final _code = TextEditingController();
  String error = '';
  void _login() {
    if (_code.text.trim() == 'Shree@Nitesh') {
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(builder: (_) => AdminPanel(db: widget.db)));
    } else {
      setState(() => error = 'Wrong code');
    }
  }
  @override Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text('Admin Login', style: TextStyle(color: Colors.white)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _code, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Enter admin code', labelStyle: TextStyle(color: Colors.white70))),
        if (error.isNotEmpty) Text(error, style: const TextStyle(color: Colors.red)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), ElevatedButton(onPressed: _login, child: const Text('Login'))],
    );
  }
}

class AdminPanel extends StatefulWidget {
  final AppDatabase db;
  const AdminPanel({super.key, required this.db});
  @override State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  List<User> users = [];
  @override void initState(){ super.initState(); _load(); }
  Future<void> _load() async { users = await widget.db.getAllUsers(); setState((){}); }
  Future<void> _toggleFee(User u) async { u.feesSubmitted = u.feesSubmitted==1?0:1; await widget.db.updateUserFees(u.id, u.feesSubmitted); await _load(); }
  Future<void> _resetMonth() async { await widget.db.resetAllForNewMonth(); await _load(); }
  Future<void> _export() async { final file = await widget.db.exportCsv(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported to $file'))); }

  @override Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Admin Panel')), body: Column(children: [
      Padding(padding: const EdgeInsets.all(8.0), child: Row(children: [ ElevatedButton(onPressed: _resetMonth, child: const Text('Start New Month')), const SizedBox(width:8), ElevatedButton(onPressed: _export, child: const Text('Backup CSV')) ])),
      Expanded(child: ListView.builder(itemCount: users.length, itemBuilder: (_,i){ final u = users[i]; return Card(color: Colors.grey[900], child: ListTile(title: Text(u.name, style: const TextStyle(color: Colors.white)), subtitle: Text('Seat ${u.seat} | Batch ${u.batch}\nJoined: ${u.joinedOn} | Due: ${u.monthCompleteOn}', style: const TextStyle(color: Colors.white70)), trailing: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: u.feesSubmitted==1? Colors.green: Colors.red), onPressed: () => _toggleFee(u), child: Text(u.feesSubmitted==1? 'Submitted':'Pending'), ),)); }))
    ]));
  }
}

// ---------------- Database ----------------

class User { int id; String name; String seat; String batch; String joinedOn; String monthCompleteOn; int feesSubmitted; User({required this.id, required this.name, required this.seat, required this.batch, required this.joinedOn, required this.monthCompleteOn, required this.feesSubmitted}); }

class AppDatabase { final Database db; AppDatabase._(this.db); static Future<AppDatabase> open() async { final documentsDirectory = await getApplicationDocumentsDirectory(); final path = join(documentsDirectory.path, 'shree.db'); final db = await openDatabase(path, version: 1, onCreate: (db, version) async { await db.execute("CREATE TABLE users ( id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, seat TEXT, batch TEXT, joinedOn TEXT, monthCompleteOn TEXT, feesSubmitted INTEGER );"); await db.execute("CREATE TABLE logs ( id INTEGER PRIMARY KEY AUTOINCREMENT, userId INTEGER, entry TEXT, exit TEXT );"); }); return AppDatabase._(db); }

  Future<int> insertUser(User u) async { final id = await db.insert('users', { 'name': u.name, 'seat': u.seat, 'batch': u.batch, 'joinedOn': u.joinedOn, 'monthCompleteOn': u.monthCompleteOn, 'feesSubmitted': u.feesSubmitted }); return id; }
  Future<User?> getUserById(int id) async { final res = await db.query('users', where: 'id = ?', whereArgs: [id]); if (res.isEmpty) return null; final r = res.first; return User(id: r['id'] as int, name: r['name'] as String, seat: r['seat'] as String, batch: r['batch'] as String, joinedOn: r['joinedOn'] as String, monthCompleteOn: r['monthCompleteOn'] as String, feesSubmitted: r['feesSubmitted'] as int); }
  Future<User?> getLastUser() async { final res = await db.query('users', orderBy: 'id DESC', limit: 1); if (res.isEmpty) return null; final r = res.first; return User(id: r['id'] as int, name: r['name'] as String, seat: r['seat'] as String, batch: r['batch'] as String, joinedOn: r['joinedOn'] as String, monthCompleteOn: r['monthCompleteOn'] as String, feesSubmitted: r['feesSubmitted'] as int); }
  Future<List<User>> getAllUsers() async { final res = await db.query('users', orderBy: 'id DESC'); return res.map((r) => User(id: r['id'] as int, name: r['name'] as String, seat: r['seat'] as String, batch: r['batch'] as String, joinedOn: r['joinedOn'] as String, monthCompleteOn: r['monthCompleteOn'] as String, feesSubmitted: r['feesSubmitted'] as int)).toList(); }
  Future<void> updateUserFees(int id, int val) async { await db.update('users', {'feesSubmitted': val}, where: 'id = ?', whereArgs: [id]); }
  Future<void> addLog(int userId, String entry) async { await db.insert('logs', {'userId': userId, 'entry': entry, 'exit': null}); }
  Future<void> updateLastLogExit(int userId, String exit) async { final res = await db.query('logs', where: 'userId = ? AND exit IS NULL', orderBy: 'id DESC', limit: 1, whereArgs: [userId]); if (res.isNotEmpty) { final id = res.first['id'] as int; await db.update('logs', {'exit': exit}, where: 'id = ?', whereArgs: [id]); } }
  Future<void> resetAllForNewMonth() async { await db.delete('logs'); final all = await getAllUsers(); for (final u in all) { await updateUserFees(u.id, 0); } }
  Future<String> exportCsv() async { final rows = await db.query('users'); final dir = await getApplicationDocumentsDirectory(); final file = File(join(dir.path, 'shree_backup_${DateTime.now().millisecondsSinceEpoch}.csv')); final sink = file.openWrite(); await sink.writeln('id,name,seat,batch,joinedOn,monthCompleteOn,feesSubmitted'); for (final r in rows) { await sink.writeln('${r['id']},${r['name']},${r['seat']},${r['batch']},${r['joinedOn']},${r['monthCompleteOn']},${r['feesSubmitted']}'); } await sink.close(); return file.path; } }

