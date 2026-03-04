import re

FILE_PATH = r"c:\dev\liuan_fitness_rpg_flutter\coach_dashboard_app\lib\screens\plan_editor_screen.dart"

with open(FILE_PATH, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace _DetailEditCardState completely
new_state = '''class _DetailEditCardState extends State<_DetailEditCard> {

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
            
            // ── 達成率基準與額外設定 (折疊) ───────────────────────────
            ExpansionTile(
              title: const Text('進階設定（達成率計算基準、RPE等）', style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              shape: const Border(),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: detail.targetSets.toString(),
                        decoration: const InputDecoration(labelText: '目標組數', isDense: true),
                        keyboardType: TextInputType.number,
                        onChanged: (val) => widget.onChanged(detail.copyWith(targetSets: int.tryParse(val) ?? 0)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: detail.targetReps.toString(),
                        decoration: const InputDecoration(labelText: '目標次數', isDense: true),
                        keyboardType: TextInputType.number,
                        onChanged: (val) => widget.onChanged(detail.copyWith(targetReps: int.tryParse(val) ?? 0)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: detail.targetWeight.toString(),
                        decoration: const InputDecoration(labelText: '目標重量 kg', isDense: true),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (val) => widget.onChanged(detail.copyWith(targetWeight: double.tryParse(val) ?? 0)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: detail.targetRpe.toString(),
                        decoration: const InputDecoration(
                          labelText: 'RPE', isDense: true,
                          prefixIcon: Icon(Icons.battery_charging_full, size: 16, color: Colors.orange),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (val) => widget.onChanged(detail.copyWith(targetRpe: int.tryParse(val) ?? 0)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: detail.restTimeSeconds.toString(),
                        decoration: const InputDecoration(
                          labelText: '預設休息(秒)', isDense: true,
                          prefixIcon: Icon(Icons.timer, size: 16, color: Colors.green),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (val) => widget.onChanged(detail.copyWith(restTimeSeconds: int.tryParse(val) ?? 60)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const Divider(height: 16),
            
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
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: detail.altTargetSets.toString(),
                        decoration: const InputDecoration(labelText: '替換組數', isDense: true),
                        keyboardType: TextInputType.number,
                        onChanged: (val) => widget.onChanged(detail.copyWith(altTargetSets: int.tryParse(val) ?? 0)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: detail.altTargetReps.toString(),
                        decoration: const InputDecoration(labelText: '替換次數', isDense: true),
                        keyboardType: TextInputType.number,
                        onChanged: (val) => widget.onChanged(detail.copyWith(altTargetReps: int.tryParse(val) ?? 0)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: detail.altTargetWeight.toString(),
                        decoration: const InputDecoration(labelText: '替換重量', isDense: true),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (val) => widget.onChanged(detail.copyWith(altTargetWeight: double.tryParse(val) ?? 0)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}'''

# Replace from `class _DetailEditCardState extends State<_DetailEditCard> {` to the end
pattern = re.compile(r"class _DetailEditCardState extends State<_DetailEditCard> \{.*", re.DOTALL)
new_content = pattern.sub(new_state, content)

with open(FILE_PATH, 'w', encoding='utf-8') as f:
    f.write(new_content)

print("Done")
