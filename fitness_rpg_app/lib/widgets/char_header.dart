import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/zen_theme.dart';
import '../widgets/zen_card.dart';
import '../models/skin.dart';
import '../widgets/skin_selection_modal.dart';

class CharHeader extends StatelessWidget {
  final String currentUserName;
  final double totalVolume;
  final VoidCallback onProfileTap;
  final VoidCallback onThemeToggle;

  const CharHeader({
    super.key,
    required this.currentUserName,
    required this.totalVolume,
    required this.onProfileTap,
    required this.onThemeToggle,
  });

  @override
  Widget build(BuildContext context) {
    // Longevity mode
    if (!isRpgMode.value) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: ZenColors.sageGreen,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: ZenColors.black08, blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              GestureDetector(
                onLongPress: () {
                  isRpgMode.value = !isRpgMode.value;
                  HapticFeedback.heavyImpact();
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: ZenColors.white25,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_outline, color: Colors.white, size: 26),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentUserName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "累計訓練量 ${totalVolume.toStringAsFixed(0)} kg",
                      style: TextStyle(
                        color: ZenColors.white80,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.manage_accounts, color: ZenColors.white85, size: 24),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: onProfileTap,
              ),
            ],
          ),
        ),
      );
    }

    // RPG mode
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: ZenCard(
        color: cardBgCol,
        padding: 20,
        child: Row(
          children: [
            ValueListenableBuilder<Skin>(
              valueListenable: currentSkin,
              builder: (context, skin, child) {
                return GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => SkinSelectionModal(),
                    );
                  },
                  onLongPress: () {
                    isRpgMode.value = !isRpgMode.value;
                    HapticFeedback.heavyImpact();
                  },
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: ZenColors.white20,
                      shape: BoxShape.circle,
                      border: Border.all(color: pCol, width: 2),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        skin.imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Image.asset('assets/images/novice.png', fit: BoxFit.cover);
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "⚔️ 冒險者：$currentUserName",
                        style: TextStyle(
                          fontFamily: fFam,
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.manage_accounts, color: ZenColors.white70),
                        onPressed: onProfileTap,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: ZenColors.white20,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.flash_on, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          "訓練量: ${totalVolume.toStringAsFixed(0)} kg",
                          style: TextStyle(fontFamily: fFam, color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
