import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'trainee_list_screen.dart';

class CoachLoginScreen extends StatefulWidget {
  const CoachLoginScreen({super.key});

  @override
  State<CoachLoginScreen> createState() => _CoachLoginScreenState();
}

class _CoachLoginScreenState extends State<CoachLoginScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = "";

  Future<void> _login() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('users')
          .select('*')
          .ilike('name', name)
          .eq('role', 'coach')
          .limit(1);

      if (response.isNotEmpty) {
        final coachId = response[0]['id'];
        final coachName = response[0]['name'];
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TraineeListScreen(
              coachId: coachId,
              coachName: coachName,
            ),
          ),
        );
      } else {
        setState(() {
          _errorMessage = "找不到名為 '$name' 的教練帳號，請確認名稱是否正確。";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "登入發生錯誤: $e";
      });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
  }

  Future<void> _registerCoach() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = "請先輸入想要註冊的教練名稱");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    try {
      final supabase = Supabase.instance.client;
      // 1. 檢查是否已經有同名的教練了
      final checkResponse = await supabase
          .from('users')
          .select('id')
          .ilike('name', name)
          .eq('role', 'coach')
          .limit(1);

      if (checkResponse.isNotEmpty) {
        setState(() {
          _errorMessage = "名稱已被使用！請更換一個名稱重新註冊。";
        });
        return;
      }

      // 2. 建立新的教練帳號
      // Supabase 的 UUID 會透過資料庫的 DEFAULT gen_random_uuid 自動生成
      // (如果沒有設 DEFAULT，也可以在這裡手動用 uuid 套件產生，但我們讓 DB 自己配發)
      final insertResponse = await supabase.from('users').insert({
        'name': name,
        'role': 'coach'
      }).select(); // 取得剛建立好的資料(含產生的 ID)

      if (insertResponse.isNotEmpty) {
        final newCoachId = insertResponse[0]['id'];
        final newCoachName = insertResponse[0]['name'];

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🎉 成功註冊教練：$newCoachName', style: const TextStyle(fontFamily: 'Cubic11'))),
        );

        // 3. 自動登入並跳轉
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TraineeListScreen(
              coachId: newCoachId,
              coachName: newCoachName,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = "註冊發生錯誤: $e\n(可能是因為您的資料庫 users.id 欄位不允許為空且沒有設定自動生成 UUID)";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.fitness_center, size: 80, color: Colors.blue),
              const SizedBox(height: 24),
              const Text(
                '教練管理系統',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '教練名稱',
                  hintText: '例如: Test Coach',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.person),
                ),
                onSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 16),
              if (_errorMessage.isNotEmpty)
                Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('登 入', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _isLoading ? null : _registerCoach,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: const BorderSide(color: Colors.blue),
                  foregroundColor: Colors.blue,
                ),
                child: _isLoading
                    ? const SizedBox.shrink()
                    : const Text('🌟 註冊新教練', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
