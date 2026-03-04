import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/workout_plan.dart';
import 'plan_editor_screen.dart';

class CreatePlanScreen extends StatefulWidget {
  final String traineeId;
  final String traineeName;

  const CreatePlanScreen({
    super.key,
    required this.traineeId,
    required this.traineeName,
  });

  @override
  State<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends State<CreatePlanScreen> {
  final _supabase = Supabase.instance.client;
  String? _selectedUserId;
  WorkoutPlan? _selectedPlan;
  
  List<WorkoutPlan> _workoutPlans = [];
  bool _isLoadingPlans = false;

  @override
  void initState() {
    super.initState();
    _selectedUserId = widget.traineeId;
  }

  Future<void> _fetchWorkoutPlans(String query) async {
    setState(() => _isLoadingPlans = true);
    try {
      final response = await _supabase
          .from('workout_plans')
          .select('*')
          .ilike('plan_name', '%$query%')
          .order('created_at', ascending: false)
          .limit(10);
          
      final plans = List<Map<String, dynamic>>.from(response)
          .map((json) => WorkoutPlan.fromJson(json))
          .toList();
          
      setState(() {
        _workoutPlans = plans;
        _isLoadingPlans = false;
      });
    } catch (e) {
      debugPrint('Error fetching plans: $e');
      setState(() => _isLoadingPlans = false);
    }
  }

  void _proceedToEditor(WorkoutPlan selectedPlan) {
    if (_selectedUserId == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlanEditorScreen(
          targetUserId: _selectedUserId!,
          templatePlan: selectedPlan,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('挑選舊課表作為模板'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.person, color: Colors.blue),
              title: Text(widget.traineeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              subtitle: Text('ID: ${widget.traineeId}'),
              tileColor: Colors.blue.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            const SizedBox(height: 24),
            TextField(
              decoration: const InputDecoration(
                labelText: '搜尋課表名稱...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) {
                if (val.length > 1) {
                   _fetchWorkoutPlans(val);
                }
              },
            ),
            const SizedBox(height: 16),
            if (_isLoadingPlans) const Center(child: CircularProgressIndicator()),
            if (!_isLoadingPlans && _workoutPlans.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text('目前無符合條件的課表，請重新搜尋', style: TextStyle(color: Colors.grey)),
                ),
              ),
            if (_workoutPlans.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _workoutPlans.length,
                  itemBuilder: (context, index) {
                    final plan = _workoutPlans[index];
                    return Card(
                      child: ListTile(
                        title: Text(plan.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: const Icon(Icons.edit, color: Colors.grey),
                        onTap: () {
                          // 直接進入編輯畫面，不需要再按鈕
                          _proceedToEditor(plan);
                        },
                      ),
                    );
                  }
                ),
              )
          ],
        ),
      ),
    );
  }
}
