import 'package:flutter/material.dart';
import '../models/rpg_character.dart';
import '../theme/zen_theme.dart';
import 'attribute_radar_chart.dart';

class CharacterCard extends StatelessWidget {
  final RpgCharacter character;
  final VoidCallback? onTap;

  const CharacterCard({super.key, required this.character, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isRpgMode.value ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(isRpgMode.value ? 4 : 24),
          border: isRpgMode.value
              ? Border.all(color: pCol, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isRpgMode.value ? 0.3 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 標題列：等級 + 能量
            Row(
              children: [
                // 等級 Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: pCol,
                    borderRadius: BorderRadius.circular(isRpgMode.value ? 2 : 12),
                  ),
                  child: Text(
                    'Lv.${character.level}',
                    style: TextStyle(
                      color: isRpgMode.value ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      fontFamily: fFam,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        character.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: txtCol,
                          fontFamily: fFam,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '總能量: ${character.currentEnergy}',
                        style: TextStyle(fontSize: 12, color: dimCol, fontFamily: fFam),
                      ),
                    ],
                  ),
                ),
                if (character.streakDays > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_fire_department, size: 14, color: Colors.orange),
                        const SizedBox(width: 2),
                        Text(
                          '${character.streakDays}天',
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade700, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // 經驗進度條
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('EXP', style: TextStyle(fontSize: 11, color: dimCol, fontFamily: fFam)),
                    Text(
                      '${character.currentLevelExp} / ${character.expForNextLevel}',
                      style: TextStyle(fontSize: 11, color: dimCol, fontFamily: fFam),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(isRpgMode.value ? 2 : 6),
                  child: LinearProgressIndicator(
                    value: character.levelProgress,
                    minHeight: 8,
                    backgroundColor: isRpgMode.value
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(pCol),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 雷達圖
            Center(
              child: AttributeRadarChart(
                attributes: character.attributes,
                size: 200,
                lineColor: pCol,
                fillColor: pCol.withValues(alpha: 0.2),
                labelColor: txtCol,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
