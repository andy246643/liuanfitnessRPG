import re

FILE_PATH = r"c:\dev\liuan_fitness_rpg_flutter\coach_dashboard_app\lib\screens\plan_editor_screen.dart"

with open(FILE_PATH, 'r', encoding='utf-8') as f:
    content = f.read()

# ADD _addAltSet, _removeAltSet, _reorderAltSets methods
methods_to_add = '''  void _addAltSet() {
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

  @override'''
content = content.replace("  @override\n  Widget build(BuildContext context) {", methods_to_add + "\n  Widget build(BuildContext context) {")


# REPLACE ExpansionTile setup to also pull alt sets
alt_builder = '''            const Divider(height: 24),
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
            ),'''

target_expansion = r"            const Divider\(height: 24\),\n            // ── 替換動作（收合）.*"

pattern = re.compile(target_expansion, re.DOTALL)
new_content = pattern.sub(alt_builder + "\n          ],\n        ),\n      ),\n    );\n  }\n}", content)

with open(FILE_PATH, 'w', encoding='utf-8') as f:
    f.write(new_content)

print("Done")
