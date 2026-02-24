import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/workout_plan.dart';
import '../models/plan_detail.dart';

class PlanEditorScreen extends StatefulWidget {
  final String targetUserId;
  final WorkoutPlan templatePlan;

  const PlanEditorScreen({
    super.key,
    required this.targetUserId,
    required this.templatePlan,
  });

  @override
  State<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends State<PlanEditorScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isSaving = false;
  late TextEditingController _planNameController;
  List<PlanDetail> _details = [];

  @override
  void initState() {
    super.initState();
    _planNameController = TextEditingController(text: '${widget.templatePlan.name} (Copy)');
    _fetchTemplateDetails();
  }

  @override
  void dispose() {
    _planNameController.dispose();
    super.dispose();
  }

  Future<void> _fetchTemplateDetails() async {
    try {
      final response = await _supabase
          .from('plan_details')
          .select('*')
          .eq('plan_id', widget.templatePlan.id!)
          .order('order_index', ascending: true);
          
      setState(() {
        _details = List<Map<String, dynamic>>.from(response)
            .map((json) => PlanDetail.fromJson(json))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching plan details: $e');
      setState(() => _isLoading = false);
    }
  }

  void _updateDetail(int index, PlanDetail newDetail) {
    setState(() {
      _details[index] = newDetail;
    });
  }

  num get _totalVolume {
    return _details.fold(0, (sum, detail) => sum + detail.targetVolume);
  }

  Future<void> _saveNewPlan() async {
    if (_planNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請輸入課表名稱')));
      return;
    }
    
    setState(() => _isSaving = true);
    try {
      // 1. 新增一筆記錄到 workout_plans，並取回新的 UUID (藉由 select())
      final savedPlanData = await _supabase
          .from('workout_plans')
          .insert({
            'plan_name': _planNameController.text,
            'user_id': widget.targetUserId,
          })
          .select()
          .single();

      final newPlanId = savedPlanData['id'] as String;

      // 2. 將修改後的動作細項存入 plan_details (自動重設 ID 並指向新的 planId)
      if (_details.isNotEmpty) {
        final newDetailsData = _details.asMap().entries.map((entry) {
            final detail = entry.value;
            // cloneForNewPlan 負責清除舊的 id，並指派新的 planId
            return detail.cloneForNewPlan(newPlanId, newOrderIndex: entry.key).toJson();
        }).toList();

        await _supabase.from('plan_details').insert(newDetailsData);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已成功建立新課表！', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
      );
      Navigator.popUntil(context, (route) => route.isFirst); // 返回首頁
      
    } catch (e) {
      debugPrint('Error saving new plan: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('儲存失敗：$e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('編輯課表')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('編輯課表'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
             icon: _isSaving ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check),
             tooltip: '儲存新課表',
             onPressed: _isSaving ? null : _saveNewPlan,
          ),
        ],
      ),
      body: Column(
         children: [
            // 頂部資訊區 (包含新課表名稱、總訓練量、目標學員ID提示)
            Container(
               padding: const EdgeInsets.all(16),
               color: Theme.of(context).colorScheme.surfaceContainerHighest,
               child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                     TextField(
                        controller: _planNameController,
                        decoration: const InputDecoration(
                          labelText: '新課表名稱',
                          border: OutlineInputBorder(),
                        ),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                     ),
                     const SizedBox(height: 12),
                     Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                           Text('目標學員 ID: ${widget.targetUserId.substring(0, 8)}...', style: const TextStyle(color: Colors.grey)),
                           Chip(
                              avatar: const Icon(Icons.monitor_weight, size: 16),
                              label: Text('總目標訓練量: $_totalVolume', style: const TextStyle(fontWeight: FontWeight.bold)),
                              backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
                           ),
                        ],
                     )
                  ],
               ),
            ),
            
            // 下方動作清單
            Expanded(
               child: ReorderableListView.builder(
                 itemCount: _details.length,
                 onReorder: (oldIndex, newIndex) {
                    setState(() {
                       if (oldIndex < newIndex) {
                         newIndex -= 1;
                       }
                       final item = _details.removeAt(oldIndex);
                       _details.insert(newIndex, item);
                    });
                 },
                 itemBuilder: (context, index) {
                    final detail = _details[index];
                    return _DetailEditCard(
                       key: ValueKey(detail.id ?? 'new_$index'),
                       detail: detail,
                       onChanged: (newDetail) => _updateDetail(index, newDetail),
                       onDelete: () {
                          setState(() {
                             _details.removeAt(index);
                          });
                       },
                    );
                 },
               ),
            )
         ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
           setState(() {
              _details.add(PlanDetail(
                exercise: '新動作',
                orderIndex: _details.length,
              ));
           });
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _DetailEditCard extends StatelessWidget {
  final PlanDetail detail;
  final ValueChanged<PlanDetail> onChanged;
  final VoidCallback onDelete;

  const _DetailEditCard({
    super.key,
    required this.detail,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
       margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
       elevation: 2,
       child: Padding(
         padding: const EdgeInsets.all(12),
         child: Column(
           children: [
              Row(
                 children: [
                    const Icon(Icons.drag_handle, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                       child: TextFormField(
                         initialValue: detail.exercise,
                         decoration: const InputDecoration(labelText: '動作名稱', isDense: true),
                         onChanged: (val) => onChanged(detail.copyWith(exercise: val)),
                       ),
                    ),
                    IconButton(
                       icon: const Icon(Icons.delete_outline, color: Colors.red),
                       onPressed: onDelete,
                    )
                 ],
              ),
              const SizedBox(height: 12),
              Row(
                 children: [
                    Expanded(
                       child: TextFormField(
                         initialValue: detail.targetSets.toString(),
                         decoration: const InputDecoration(labelText: '組數 (Sets)', isDense: true),
                         keyboardType: TextInputType.number,
                         onChanged: (val) => onChanged(detail.copyWith(targetSets: int.tryParse(val) ?? 0)),
                       ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                       child: TextFormField(
                         initialValue: detail.targetReps.toString(),
                         decoration: const InputDecoration(labelText: '次數 (Reps)', isDense: true),
                         keyboardType: TextInputType.number,
                         onChanged: (val) => onChanged(detail.copyWith(targetReps: int.tryParse(val) ?? 0)),
                       ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                       child: TextFormField(
                         initialValue: detail.targetWeight.toString(),
                         decoration: const InputDecoration(labelText: '重量 (Weight)', isDense: true),
                         keyboardType: const TextInputType.numberWithOptions(decimal: true),
                         onChanged: (val) => onChanged(detail.copyWith(targetWeight: double.tryParse(val) ?? 0)),
                       ),
                    ),
                 ],
              ),
              const SizedBox(height: 12),
              Wrap(
                 spacing: 8.0,
                 runSpacing: 8.0,
                 alignment: WrapAlignment.spaceBetween,
                 crossAxisAlignment: WrapCrossAlignment.center,
                 children: [
                    Row(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                          const Icon(Icons.battery_charging_full, size: 16, color: Colors.orange),
                          const SizedBox(width: 4),
                          const Text('自覺強度 RPE: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                          SizedBox(
                             width: 40,
                             child: TextFormField(
                               initialValue: detail.targetRpe.toString(),
                               decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.only(bottom: 4)),
                               keyboardType: TextInputType.number,
                               style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                               onChanged: (val) => onChanged(detail.copyWith(targetRpe: int.tryParse(val) ?? 0)),
                             ),
                          )
                       ],
                    ),
                    Row(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                           const Icon(Icons.timer, size: 16, color: Colors.green),
                           const SizedBox(width: 4),
                           const Text('休息(秒): ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                           SizedBox(
                              width: 40,
                              child: TextFormField(
                                initialValue: detail.restTimeSeconds.toString(),
                                decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.only(bottom: 4)),
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                onChanged: (val) => onChanged(detail.copyWith(restTimeSeconds: int.tryParse(val) ?? 60)),
                              ),
                           )
                        ],
                     ),
                    Container(
                       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                       decoration: BoxDecoration(
                         color: Colors.blue.withOpacity(0.1),
                         borderRadius: BorderRadius.circular(8),
                       ),
                       child: Text(
                          'Volume: ${detail.targetVolume}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                       ),
                    )
                 ],
              )
           ],
         ),
       ),
    );
  }
}
