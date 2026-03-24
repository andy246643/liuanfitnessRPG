import 'package:flutter/material.dart';
import '../theme/zen_theme.dart';

/// 具備品牌質感的卡片組件，自動適配 RPG / 長壽模式
class ZenCard extends StatelessWidget {
  final Widget child;
  final double padding;
  final Color? color;
  final VoidCallback? onTap;

  const ZenCard({
    super.key,
    required this.child,
    this.padding = 20,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: color ?? (isRpgMode.value ? const Color(0xFF1A1A1A) : Colors.white),
        borderRadius: BorderRadius.circular(isRpgMode.value ? 4 : 32),
        border: isRpgMode.value ? Border.all(color: pCol, width: 2) : null,
        boxShadow: isRpgMode.value
            ? [BoxShadow(color: const Color.fromRGBO(0, 0, 0, 0.3), blurRadius: 4, offset: const Offset(0, 4))]
            : [BoxShadow(color: const Color.fromRGBO(0, 0, 0, 0.04), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: MouseRegion(cursor: SystemMouseCursors.click, child: card),
      );
    }
    return card;
  }
}
