import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// --- 全域主題狀態 ---
final ValueNotifier<bool> isRpgMode = ValueNotifier(false);

// 品牌色彩常數 (Zen Style)
class ZenColors {
  static const Color sageGreen = Color(0xFF8DAA91);
  static const Color background = Color(0xFFF8F9FA);
  static const Color textDark = Color(0xFF2D3142);
  static const Color textLight = Color(0xFF94A3B8);

  // 預定義半透明色彩常數（避免 withOpacity 每次建立新物件）
  static const Color sageGreen05 = Color(0x0D8DAA91); // 5% opacity
  static const Color sageGreen10 = Color(0x1A8DAA91); // 10% opacity
  static const Color sageGreen15 = Color(0x268DAA91); // 15% opacity
  static const Color textLight50 = Color(0x8094A3B8); // 50% opacity
  static const Color white20 = Color(0x33FFFFFF);  // 20% opacity
  static const Color white25 = Color(0x40FFFFFF);  // 25% opacity
  static const Color white70 = Color(0xB3FFFFFF);  // 70% opacity
  static const Color white80 = Color(0xCCFFFFFF);  // 80% opacity
  static const Color white85 = Color(0xD9FFFFFF);  // 85% opacity
  static const Color black04 = Color(0x0A000000);  // 4% opacity
  static const Color black05 = Color(0x0D000000);  // 5% opacity
  static const Color black08 = Color(0x14000000);  // 8% opacity
  static const Color black30 = Color(0x4D000000);  // 30% opacity
}

// 主題感知的色彩 getter
Color get txtCol => isRpgMode.value ? const Color(0xFF4AF626) : ZenColors.textDark;
Color get dimCol =>
    isRpgMode.value ? const Color.fromRGBO(74, 246, 38, 0.5) : ZenColors.textLight;
Color get bgCol => isRpgMode.value ? Colors.black : ZenColors.background;
Color get cardBgCol => isRpgMode.value ? const Color(0xFF1A1A1A) : Colors.white;
Color get pCol => isRpgMode.value ? const Color(0xFF4AF626) : ZenColors.sageGreen;
String? get fFam => isRpgMode.value ? 'Cubic11' : null;

// 長壽模式主題
ThemeData buildLongevityTheme() {
  return ThemeData.light().copyWith(
    primaryColor: ZenColors.sageGreen,
    scaffoldBackgroundColor: ZenColors.background,
    cardColor: Colors.white,
    textTheme: ThemeData.light().textTheme.apply(
      bodyColor: ZenColors.textDark,
      displayColor: ZenColors.sageGreen,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: ZenColors.background,
      foregroundColor: ZenColors.sageGreen,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    ),
  );
}

// RPG 模式主題
ThemeData buildRpgTheme() {
  return ThemeData.dark().copyWith(
    primaryColor: pCol,
    scaffoldBackgroundColor: bgCol,
    cardColor: const Color(0xFF1A1A1A),
    textTheme: ThemeData.dark().textTheme.apply(
      fontFamily: 'Cubic11',
      bodyColor: txtCol,
      displayColor: pCol,
    ),
  );
}
