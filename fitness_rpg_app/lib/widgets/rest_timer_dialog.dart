import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/zen_theme.dart';

class RestTimerDialog extends StatefulWidget {
  final int restTimeSeconds;

  RestTimerDialog({super.key, required this.restTimeSeconds});

  @override
  State<RestTimerDialog> createState() => _RestTimerDialogState();
}

class _RestTimerDialogState extends State<RestTimerDialog> {
  late DateTime endTime;
  late Timer timer;
  int remainingSeconds = 0;
  bool isFinished = false;

  @override
  void initState() {
    super.initState();
    remainingSeconds = widget.restTimeSeconds;
    endTime = DateTime.now().add(Duration(seconds: remainingSeconds));

    timer = Timer.periodic(Duration(seconds: 1), (Timer t) {
      if (!mounted) {
        t.cancel();
        return;
      }

      final now = DateTime.now();
      if (now.isAfter(endTime)) {
        setState(() {
          remainingSeconds = 0;
          isFinished = true;
        });
        t.cancel();
      } else {
        setState(() {
          remainingSeconds = endTime.difference(now).inSeconds;
        });
      }
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: cardBgCol,
      title: Text(
        "休息時間",
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: fFam, color: txtCol, fontSize: 24),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isFinished ? "時間到！" : "💖 體力回復中...",
            style: TextStyle(fontFamily: fFam, color: isFinished ? pCol : dimCol, fontSize: 18),
          ),
          SizedBox(height: 20),
          Text(
            "$remainingSeconds s",
            style: TextStyle(
              fontFamily: fFam,
              color: isFinished ? pCol : Colors.orange,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (isFinished) ...[
            SizedBox(height: 10),
          ],
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        ElevatedButton(
          onPressed: () {
            if (mounted) Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: pCol,
            foregroundColor: bgCol,
            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          ),
          child: Text(
            "停止休息，進行下一個",
            style: TextStyle(fontFamily: fFam, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
