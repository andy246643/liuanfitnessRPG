import 'dart:math';
import 'package:flutter/material.dart';

class AttributeRadarChart extends StatelessWidget {
  final Map<String, int> attributes;
  final double size;
  final Color lineColor;
  final Color fillColor;
  final Color labelColor;

  const AttributeRadarChart({
    super.key,
    required this.attributes,
    this.size = 200,
    this.lineColor = const Color(0xFF8DAA91),
    this.fillColor = const Color(0x338DAA91),
    this.labelColor = const Color(0xFF2D3142),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RadarPainter(
          attributes: attributes,
          lineColor: lineColor,
          fillColor: fillColor,
          labelColor: labelColor,
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final Map<String, int> attributes;
  final Color lineColor;
  final Color fillColor;
  final Color labelColor;

  _RadarPainter({
    required this.attributes,
    required this.lineColor,
    required this.fillColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 30;
    final labels = attributes.keys.toList();
    final values = attributes.values.toList();
    final n = labels.length;
    if (n == 0) return;

    // 找最大值用來標準化（至少 10 避免除以零）
    final maxVal = values.reduce(max).clamp(10, double.infinity).toDouble();

    final gridPaint = Paint()
      ..color = labelColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final axisPaint = Paint()
      ..color = labelColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // 畫 3 層同心網格
    for (int ring = 1; ring <= 3; ring++) {
      final r = radius * ring / 3;
      final path = Path();
      for (int i = 0; i < n; i++) {
        final angle = -pi / 2 + (2 * pi * i / n);
        final x = center.dx + r * cos(angle);
        final y = center.dy + r * sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // 畫軸線
    for (int i = 0; i < n; i++) {
      final angle = -pi / 2 + (2 * pi * i / n);
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      canvas.drawLine(center, Offset(x, y), axisPaint);
    }

    // 畫數值區域
    final dataPath = Path();
    final dataPoints = <Offset>[];
    for (int i = 0; i < n; i++) {
      final angle = -pi / 2 + (2 * pi * i / n);
      final normalizedValue = (values[i] / maxVal).clamp(0.0, 1.0);
      final r = radius * normalizedValue;
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);
      dataPoints.add(Offset(x, y));
      if (i == 0) {
        dataPath.moveTo(x, y);
      } else {
        dataPath.lineTo(x, y);
      }
    }
    dataPath.close();

    // 填充
    canvas.drawPath(dataPath, Paint()..color = fillColor);
    // 邊框
    canvas.drawPath(dataPath, Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);

    // 畫數據點
    for (final pt in dataPoints) {
      canvas.drawCircle(pt, 3, Paint()..color = lineColor);
    }

    // 畫標籤
    for (int i = 0; i < n; i++) {
      final angle = -pi / 2 + (2 * pi * i / n);
      final labelR = radius + 18;
      final x = center.dx + labelR * cos(angle);
      final y = center.dy + labelR * sin(angle);

      final textSpan = TextSpan(
        text: '${labels[i]}\n${values[i]}',
        style: TextStyle(color: labelColor, fontSize: 10, fontWeight: FontWeight.bold, height: 1.2),
      );
      final tp = TextPainter(text: textSpan, textAlign: TextAlign.center, textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return oldDelegate.attributes != attributes;
  }
}
