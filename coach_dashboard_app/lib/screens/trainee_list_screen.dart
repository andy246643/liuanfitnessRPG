import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'coach_login_screen.dart';
import 'trainee_sessions_screen.dart';

class TraineeListScreen extends StatefulWidget {
  final String coachId;
  final String coachName;

  const TraineeListScreen({
    super.key,
    required this.coachId,
    required this.coachName,
  });

  @override
  State<TraineeListScreen> createState() => _TraineeListScreenState();
}

class _TraineeListScreenState extends State<TraineeListScreen> {
  late Future<List<dynamic>> _traineesFuture;

  @override
  void initState() {
    super.initState();
    _traineesFuture = _fetchTrainees();
  }

  Future<List<dynamic>> _fetchTrainees() async {
    try {
      final supabase = Supabase.instance.client;
      // 取得特定教練指導的身分為 trainee 的使用者
      final response = await supabase
          .from('users')
          .select('id, name, created_at')
          .eq('role', 'trainee')
          .eq('coach_id', widget.coachId)
          .order('created_at', ascending: false);
      return response as List<dynamic>;
    } catch (e) {
      throw Exception('Fetch trainees failed: $e');
    }
  }

  Future<void> _createNewTrainee(BuildContext context) async {
    final TextEditingController nameController = TextEditingController();
    bool isCreating = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('新增學員', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('輸入學員名稱來建立新帳號並指派給自己。'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: '學員名稱',
                      hintText: '例如: 小明',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isCreating ? null : () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: isCreating
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) return;

                          setDialogState(() => isCreating = true);

                          try {
                            final supabase = Supabase.instance.client;
                            final newUuid = const Uuid().v4();

                            await supabase.from('users').insert({
                              'id': newUuid,
                              'name': name,
                              'role': 'trainee',
                              'coach_id': widget.coachId,
                            });

                            if (!mounted) return;
                            Navigator.pop(ctx);
                            setState(() { _traineesFuture = _fetchTrainees(); }); // 重新載入列表

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('成功新增學員: $name')),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                               SnackBar(content: Text('新增失敗: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red),
                            );
                            setDialogState(() => isCreating = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  child: isCreating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('確認新增'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('${widget.coachName} 的指導學員', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        shadowColor: Colors.black12,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: '新增學員',
            onPressed: () => _createNewTrainee(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '登出',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const CoachLoginScreen()),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _traineesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('載入學員列表失敗: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('目前還沒有任何學員。', style: TextStyle(fontSize: 16, color: Colors.grey)));
          }

          final trainees = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: trainees.length,
            itemBuilder: (context, index) {
              final trainee = trainees[index];
              return Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    foregroundColor: Colors.blue.shade800,
                    child: Text(trainee['name'].toString().substring(0, 1).toUpperCase()),
                  ),
                  title: Text(trainee['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  subtitle: Text('ID: ${trainee['id']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TraineeSessionsScreen(
                          traineeId: trainee['id'],
                          traineeName: trainee['name'],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
