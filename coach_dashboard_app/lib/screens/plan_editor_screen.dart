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
      String? newPlanId;
      try {
        final savedPlanData = await _supabase
            .from('workout_plans')
            .insert({
              'plan_name': _planNameController.text,
              'user_id': widget.targetUserId,
            })
            .select()
            .single();

        newPlanId = savedPlanData['id'] as String;

        if (_details.isNotEmpty) {
          final newDetailsData = _details.asMap().entries.map((entry) {
              final detail = entry.value;
              return detail.cloneForNewPlan(newPlanId!, newOrderIndex: entry.key).toJson();
          }).toList();

          await _supabase.from('plan_details').insert(newDetailsData);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已成功建立新課表！', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
        );
        Navigator.popUntil(context, (route) => route.isFirst);
        
      } catch (e) {
        if (newPlanId != null) {
          await _supabase.from('workout_plans').delete().eq('id', newPlanId);
        }
        rethrow;
      }
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
                              label: Text('總訓練量: $_totalVolume', style: const TextStyle(fontWeight: FontWeight.bold)),
                              backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
                           ),
                        ],
                     )
                  ],
               ),
            ),
            
            Expanded(
               child: ReorderableListView.builder(
                 itemCount: _details.length,
                 onReorder: (oldIndex, newIndex) {
                    setState(() {
                       if (oldIndex < newIndex) newIndex -= 1;
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

// ─── 動作編輯卡片（StatefulWidget for batch add state） ───────────────────────
class _DetailEditCard extends StatefulWidget {
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
  State<_DetailEditCard> createState() => _DetailEditCardState();
}

class _DetailEditCardState extends State<_DetailEditCard> {

  void _addSet() {
    final newSets = List<Map<String, dynamic>>.from(widget.detail.prescribedSets);
    double w = 0;
    int r = 0;
    int rest = widget.detail.restTimeSeconds;
    if (newSets.isNotEmpty) {
      w = (newSets.last['weight'] as num?)?.toDouble() ?? 0;
      r = (newSets.last['reps'] as num?)?.toInt() ?? 0;
      rest = (newSets.last['rest_time'] as num?)?.toInt() ?? 60;
    }
    // 加入 unique id 以便 reorder 或 delete 時維持 Focus 狀態
    newSets.add({'_id': DateTime.now().microsecondsSinceEpoch.toString(), 'weight': w, 'reps': r, 'rest_time': rest});
    widget.onChanged(widget.detail.copyWith(prescribedSets: newSets));
  }

  void _removeSet(int index) {
    final newSets = List<Map<String, dynamic>>.from(widget.detail.prescribedSets)..removeAt(index);
    widget.onChanged(widget.detail.copyWith(prescribedSets: newSets));
  }

  void _reorderSets(int oldIndex, int newIndex) {
    final newSets = List<Map<String, dynamic>>.from(widget.detail.prescribedSets);
    if (oldIndex < newIndex) newIndex -= 1;
    final item = newSets.removeAt(oldIndex);
    newSets.insert(newIndex, item);
    widget.onChanged(widget.detail.copyWith(prescribedSets: newSets));
  }

  void _addAltSet() {
    List<Map<String, dynamic>> newSets;
    if (widget.detail.altPrescribedSets.isEmpty && widget.detail.prescribedSets.isNotEmpty) {
      newSets = List<Map<String, dynamic>>.from(widget.detail.prescribedSets);
      for (var i = 0; i < newSets.length; i++) {
         final map = Map<String, dynamic>.from(newSets[i]);
         map['_id'] = DateTime.now().microsecondsSinceEpoch.toString() + '_alt_$i';
         newSets[i] = map;
      }
    } else {
      newSets = List<Map<String, dynamic>>.from(widget.detail.altPrescribedSets);
      double w = 0;
      int r = 0;
      int rest = widget.detail.restTimeSeconds;
      if (newSets.isNotEmpty) {
        w = (newSets.last['weight'] as num?)?.toDouble() ?? 0;
        r = (newSets.last['reps'] as num?)?.toInt() ?? 0;
        rest = (newSets.last['rest_time'] as num?)?.toInt() ?? 60;
      }
      newSets.add({'_id': DateTime.now().microsecondsSinceEpoch.toString() + '_alt', 'weight': w, 'reps': r, 'rest_time': rest});
    }
    widget.onChanged(widget.detail.copyWith(altPrescribedSets: newSets));
  }

  void _removeAltSet(int index) {
    final newSets = List<Map<String, dynamic>>.from(widget.detail.altPrescribedSets)..removeAt(index);
    widget.onChanged(widget.detail.copyWith(altPrescribedSets: newSets));
  }

  void _reorderAltSets(int oldIndex, int newIndex) {
    final newSets = List<Map<String, dynamic>>.from(widget.detail.altPrescribedSets);
    if (oldIndex < newIndex) newIndex -= 1;
    final item = newSets.removeAt(oldIndex);
    newSets.insert(newIndex, item);
    widget.onChanged(widget.detail.copyWith(altPrescribedSets: newSets));
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final sets   = detail.prescribedSets;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 動作名稱 ──────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.drag_handle, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: detail.exercise,
                    decoration: const InputDecoration(labelText: '動作名稱', isDense: true),
                    onChanged: (val) => widget.onChanged(detail.copyWith(exercise: val)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: widget.onDelete,
                )
              ],
            ),
            const SizedBox(height: 12),
            
            // ── 組別設定清單 ──────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.format_list_numbered, size: 16, color: Colors.indigo),
                const SizedBox(width: 6),
                const Text('組別設定', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text('Vol: ${detail.targetVolume}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // 已設定組別清單
             ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                onReorder: _reorderSets,
                children: sets.asMap().entries.map((e) {
                  final idx = e.key;
                  final ps  = e.value;
                  final w   = ps['weight'] ?? 0;
                  final r   = ps['reps'] ?? 0;
                  final rest = ps['rest_time'] ?? detail.restTimeSeconds;
                  final uniqueId = ps['_id'] ?? 'ps_${idx}';
                  
                  return Padding(
                    key: ValueKey(uniqueId),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.drag_handle, color: Colors.grey, size: 20),
                        const SizedBox(width: 4),
                        Container(
                          width: 24, height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('${idx + 1}',
                              style: TextStyle(color: Colors.indigo.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: TextFormField(
                          initialValue: w == 0 ? '' : w.toString(),
                          decoration: const InputDecoration(labelText: '重量kg', isDense: true),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (val) {
                             final newSets = List<Map<String, dynamic>>.from(widget.detail.prescribedSets);
                             newSets[idx]['weight'] = double.tryParse(val) ?? 0;
                             widget.onChanged(widget.detail.copyWith(prescribedSets: newSets));
                          },
                        )),
                        const SizedBox(width: 6),
                        Expanded(child: TextFormField(
                          initialValue: r == 0 ? '' : r.toString(),
                          decoration: const InputDecoration(labelText: '次數', isDense: true),
                          keyboardType: TextInputType.number,
                          onChanged: (val) {
                             final newSets = List<Map<String, dynamic>>.from(widget.detail.prescribedSets);
                             newSets[idx]['reps'] = int.tryParse(val) ?? 0;
                             widget.onChanged(widget.detail.copyWith(prescribedSets: newSets));
                          },
                        )),
                        const SizedBox(width: 6),
                        Expanded(child: TextFormField(
                          initialValue: rest.toString(),
                          decoration: const InputDecoration(labelText: '休息(秒)', isDense: true),
                          keyboardType: TextInputType.number,
                          onChanged: (val) {
                             final newSets = List<Map<String, dynamic>>.from(widget.detail.prescribedSets);
                             newSets[idx]['rest_time'] = int.tryParse(val) ?? 60;
                             widget.onChanged(widget.detail.copyWith(prescribedSets: newSets));
                          },
                        )),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18, color: Colors.red),
                          onPressed: () => _removeSet(idx),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addSet,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('加入一組'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.indigo,
                  side: BorderSide(color: Colors.indigo.shade200),
                ),
              ),
            ),
            
            const Divider(height: 24),
            // ── 替換動作（收合） ───────────────────────────────────
            ExpansionTile(
              title: const Text('設為替換動作 (Alternative)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              shape: const Border(),
              initiallyExpanded: detail.altExercise != null && detail.altExercise!.isNotEmpty,
              children: [
                Row(
                  children: [
                    const Icon(Icons.swap_horiz, color: Colors.indigo),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: detail.altExercise,
                        decoration: const InputDecoration(labelText: '替換動作名稱（留空代表無）', isDense: true),
                        onChanged: (val) => widget.onChanged(detail.copyWith(altExercise: val)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // 替換動作的組別設定
                Row(
                  children: [
                    const Icon(Icons.format_list_numbered, size: 14, color: Colors.indigo),
                    const SizedBox(width: 6),
                    const Text('替換動作組別', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo)),
                  ],
                ),
                const SizedBox(height: 6),
                
                 ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    onReorder: _reorderAltSets,
                    children: detail.altPrescribedSets.asMap().entries.map((e) {
                      final idx = e.key;
                      final ps  = e.value;
                      final w   = ps['weight'] ?? 0;
                      final r   = ps['reps'] ?? 0;
                      final rest = ps['rest_time'] ?? detail.restTimeSeconds;
                      final uniqueId = ps['_id'] ?? 'altps_${idx}';
                      
                      return Padding(
                        key: ValueKey(uniqueId),
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.drag_handle, color: Colors.grey, size: 20),
                            const SizedBox(width: 4),
                            Container(
                              width: 24, height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(4)),
                              child: Text('${idx + 1}', style: TextStyle(color: Colors.indigo.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: TextFormField(
                              initialValue: w == 0 ? '' : w.toString(),
                              decoration: const InputDecoration(labelText: '重量kg', isDense: true),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (val) {
                                 final newSets = List<Map<String, dynamic>>.from(widget.detail.altPrescribedSets);
                                 newSets[idx]['weight'] = double.tryParse(val) ?? 0;
                                 widget.onChanged(widget.detail.copyWith(altPrescribedSets: newSets));
                              },
                            )),
                            const SizedBox(width: 6),
                            Expanded(child: TextFormField(
                              initialValue: r == 0 ? '' : r.toString(),
                              decoration: const InputDecoration(labelText: '次數', isDense: true),
                              keyboardType: TextInputType.number,
                              onChanged: (val) {
                                 final newSets = List<Map<String, dynamic>>.from(widget.detail.altPrescribedSets);
                                 newSets[idx]['reps'] = int.tryParse(val) ?? 0;
                                 widget.onChanged(widget.detail.copyWith(altPrescribedSets: newSets));
                              },
                            )),
                            const SizedBox(width: 6),
                            Expanded(child: TextFormField(
                              initialValue: rest.toString(),
                              decoration: const InputDecoration(labelText: '休息(秒)', isDense: true),
                              keyboardType: TextInputType.number,
                              onChanged: (val) {
                                 final newSets = List<Map<String, dynamic>>.from(widget.detail.altPrescribedSets);
                                 newSets[idx]['rest_time'] = int.tryParse(val) ?? 60;
                                 widget.onChanged(widget.detail.copyWith(altPrescribedSets: newSets));
                              },
                            )),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18, color: Colors.red),
                              onPressed: () => _removeAltSet(idx),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _addAltSet,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('自動複製主動作組別 / 加入替換組'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.indigo,
                      side: BorderSide(color: Colors.indigo.shade200),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}