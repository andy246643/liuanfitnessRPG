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

  void _proceedToEditor() {
    if (_selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先選擇目標學員')),
      );
      return;
    }
    if (_selectedPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請選擇一份舊課表作為模板')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlanEditorScreen(
          targetUserId: _selectedUserId!,
          templatePlan: _selectedPlan!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('建立新課表'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Stepper(
        currentStep: _selectedUserId == null ? 0 : 1,
        controlsBuilder: (context, details) {
          if (details.currentStep == 1) {
             return Padding(
               padding: const EdgeInsets.only(top: 16.0),
               child: ElevatedButton.icon(
                 onPressed: _proceedToEditor,
                 icon: const Icon(Icons.edit),
                 label: const Text('進入編輯器'),
                 style: ElevatedButton.styleFrom(
                   minimumSize: const Size(double.infinity, 50),
                 ),
               ),
             );
          }
          return const SizedBox.shrink();
        },
        steps: [
          Step(
            title: const Text('第一步：確認目標學員'),
            content: ListTile(
              leading: const Icon(Icons.person, color: Colors.blue),
              title: Text(widget.traineeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              subtitle: Text('ID: ${widget.traineeId}'),
              tileColor: Colors.blue.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            isActive: true,
            state: StepState.complete,
          ),
          Step(
            title: const Text('第二步：挑選舊課表作為模板'),
            content: Column(
              children: [
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
                if (_isLoadingPlans) const CircularProgressIndicator(),
                if (!_isLoadingPlans && _workoutPlans.isEmpty)
                  const Text('目前無符合條件的課表，請重新搜尋', style: TextStyle(color: Colors.grey)),
                if (_workoutPlans.isNotEmpty)
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _workoutPlans.length,
                    itemBuilder: (context, index) {
                      final plan = _workoutPlans[index];
                      final isSelected = _selectedPlan?.id == plan.id;
                      return Card(
                        color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
                        child: ListTile(
                          title: Text(plan.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('ID: ${plan.id?.substring(0, 8)}...'),
                          trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.green) : null,
                          onTap: () {
                            setState(() => _selectedPlan = plan);
                          },
                        ),
                      );
                    }
                  )
              ],
            ),
            isActive: _selectedUserId != null,
            state: _selectedPlan != null ? StepState.complete : StepState.indexed,
          ),
        ],
      ),
    );
  }
}
