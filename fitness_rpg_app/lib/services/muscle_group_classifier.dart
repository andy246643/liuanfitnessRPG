import 'package:flutter/material.dart';

/// 肌群自動分類器
/// 策略：教練標註 > 關鍵字比對 > 歸入「其他」
class MuscleGroupClassifier {
  static const groupOrder = ['胸', '背', '腿', '肩', '手臂', '核心', '其他'];

  static const Map<String, List<String>> _keywordMap = {
    '胸': ['bench', 'press', '臥推', '飛鳥', 'chest', 'pec', '夾胸', '胸推', '握推', 'dip'],
    '背': ['row', 'pull', 'deadlift', '硬舉', '划船', '引體', 'lat', '背', '滑輪下拉', '水平拉', '水平寬拉'],
    '腿': ['squat', '深蹲', 'leg', 'lunge', '腿', '弓步', '腿推', '腿舉', '臀推', 'hip thrust'],
    '肩': ['shoulder', 'ohp', '肩推', 'lateral', '側平舉', '前平舉', 'delt', '肩'],
    '手臂': ['bicep', 'tricep', 'curl', '二頭', '三頭', '彎舉'],
    '核心': ['plank', 'ab', 'crunch', '腹', '核心', '捲腹', '棒式'],
  };

  /// 有 PNG 圖示的肌群 → asset 路徑
  static const Map<String, String> _groupAssets = {
    '胸': 'assets/icon/胸.png',
    '背': 'assets/icon/背.png',
    '腿': 'assets/icon/腿.png',
    '肩': 'assets/icon/肩膀.png',
    '手臂': 'assets/icon/手臂.png',
  };

  /// 沒有 PNG 的肌群用 Material Icon 作為 fallback
  static const Map<String, IconData> _fallbackIcons = {
    '核心': Icons.circle_outlined,
    '其他': Icons.more_horiz,
  };

  /// 取得肌群圖示 asset 路徑，null 代表沒有 PNG（用 fallback icon）
  static String? getAssetPath(String group) => _groupAssets[group];

  /// 取得 fallback Material Icon（僅核心和其他）
  static IconData getIcon(String group) => _fallbackIcons[group] ?? Icons.more_horiz;

  /// 建立肌群圖示 Widget（統一入口）
  /// PNG 圖示保留原始顏色，僅 fallback Material Icon 使用 color 參數
  static Widget buildIcon(String group, {double size = 24, Color? color}) {
    final assetPath = _groupAssets[group];
    if (assetPath != null) {
      return Image.asset(
        assetPath,
        width: size,
        height: size,
      );
    }
    return Icon(_fallbackIcons[group] ?? Icons.more_horiz, size: size, color: color);
  }

  /// 分類單一動作
  static String classify(String exerciseName, {String? coachTag}) {
    // Priority 1: 教練標註
    if (coachTag != null && coachTag.isNotEmpty) return coachTag;

    // Priority 2: 關鍵字比對
    final lower = exerciseName.toLowerCase();

    // 特殊處理 "curl" 的歧義（可能是手臂或腿）
    if (lower.contains('curl')) {
      if (lower.contains('leg') || lower.contains('腿')) return '腿';
      return '手臂';
    }

    for (final entry in _keywordMap.entries) {
      for (final keyword in entry.value) {
        if (lower.contains(keyword.toLowerCase())) {
          return entry.key;
        }
      }
    }

    return '其他';
  }

  /// RPG 屬性用的肌群列表（不含「肩」和「其他」，肩歸入胸，其他平分）
  static const rpgGroups = ['胸', '背', '腿', '手臂', '核心', '心肺'];

  /// 複合動作分類：回傳主肌群和次要肌群
  static ({String primary, String? secondary}) classifyCompound(
    String exerciseName, {
    String? coachPrimary,
    String? coachSecondary,
  }) {
    // Priority 1: 教練指定
    if (coachPrimary != null && coachPrimary.isNotEmpty) {
      return (
        primary: _mapToRpgGroup(coachPrimary),
        secondary: coachSecondary != null && coachSecondary.isNotEmpty
            ? _mapToRpgGroup(coachSecondary)
            : null,
      );
    }

    // Priority 2: 關鍵字交叉判斷
    final lower = exerciseName.toLowerCase();
    final List<String> matched = [];

    for (final entry in _keywordMap.entries) {
      for (final keyword in entry.value) {
        if (lower.contains(keyword.toLowerCase())) {
          final rpgGroup = _mapToRpgGroup(entry.key);
          if (!matched.contains(rpgGroup)) {
            matched.add(rpgGroup);
          }
          break; // 一個肌群只需匹配一次
        }
      }
    }

    if (matched.isEmpty) {
      return (primary: '核心', secondary: null); // 預設給核心
    }
    if (matched.length == 1) {
      return (primary: matched[0], secondary: null);
    }
    return (primary: matched[0], secondary: matched[1]);
  }

  /// 將原始肌群名映射到 RPG 六大屬性
  static String _mapToRpgGroup(String group) {
    switch (group) {
      case '肩': return '胸'; // 肩推歸入胸（上肢推力）
      case '其他': return '核心';
      default: return rpgGroups.contains(group) ? group : '核心';
    }
  }

  /// 批量分組所有動作名稱
  static Map<String, List<String>> groupExercises(
    Iterable<String> exerciseNames, {
    Map<String, String?> coachTags = const {},
  }) {
    final Map<String, List<String>> grouped = {};

    for (final name in exerciseNames) {
      final group = classify(name, coachTag: coachTags[name]);
      grouped.putIfAbsent(group, () => []);
      grouped[group]!.add(name);
    }

    // 按 groupOrder 排序
    final sorted = <String, List<String>>{};
    for (final g in groupOrder) {
      if (grouped.containsKey(g)) {
        sorted[g] = grouped[g]!;
      }
    }
    // 加入 groupOrder 中沒有的自訂分類
    for (final entry in grouped.entries) {
      if (!sorted.containsKey(entry.key)) {
        sorted[entry.key] = entry.value;
      }
    }

    return sorted;
  }
}
