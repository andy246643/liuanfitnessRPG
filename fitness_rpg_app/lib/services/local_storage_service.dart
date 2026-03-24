import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const _pendingLogsKey = 'pending_workout_logs';
  static const _sessionStateKey = 'active_session_state';

  /// 儲存暫存的訓練紀錄（每完成一個動作就存一次）
  static Future<void> savePendingLogs(List<Map<String, dynamic>> logs) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(logs);
    await prefs.setString(_pendingLogsKey, jsonStr);
  }

  /// 讀取暫存的訓練紀錄
  static Future<List<Map<String, dynamic>>> loadPendingLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_pendingLogsKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final decoded = jsonDecode(jsonStr) as List;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// 清除暫存的訓練紀錄
  static Future<void> clearPendingLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingLogsKey);
  }

  /// 儲存進行中的訓練狀態
  static Future<void> saveSessionState(Map<String, dynamic> state) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(state);
    await prefs.setString(_sessionStateKey, jsonStr);
  }

  /// 讀取進行中的訓練狀態
  static Future<Map<String, dynamic>?> loadSessionState() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_sessionStateKey);
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(jsonStr) as Map);
    } catch (_) {
      return null;
    }
  }

  /// 清除訓練狀態
  static Future<void> clearSessionState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionStateKey);
  }
}
