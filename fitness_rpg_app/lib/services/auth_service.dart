import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';

/// 驗證服務：處理學員登入相關的 Supabase 查詢
class AuthService {
  final SupabaseClient _supabase;

  AuthService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// 學員登入：驗證教練名稱 → 驗證學員名稱 → 回傳 UserProfile
  ///
  /// 若驗證失敗，拋出 [AuthException] 並附帶使用者友善的錯誤訊息。
  Future<UserProfile> loginTrainee(String traineeName, String coachName) async {
    if (traineeName.isEmpty || coachName.isEmpty) {
      throw AuthException('請輸入冒險者與教練名稱！');
    }

    try {
      // 1. 查找教練
      final coachResponse = await _supabase
          .from('users')
          .select('id')
          .ilike('name', coachName)
          .eq('role', 'coach')
          .limit(1);

      if (coachResponse.isEmpty) {
        throw AuthException("找不到名為 '$coachName' 的教練！");
      }

      final coachId = coachResponse[0]['id'];

      // 2. 查找該教練旗下的學員
      final traineeResponse = await _supabase
          .from('users')
          .select('id, name, gender, height, weight, body_fat')
          .ilike('name', traineeName)
          .eq('role', 'trainee')
          .eq('coach_id', coachId)
          .limit(1);

      if (traineeResponse.isEmpty) {
        throw AuthException("教練 '$coachName' 旗下找不到冒險者 '$traineeName'！請請教練為您建立帳號。");
      }

      return UserProfile.fromJson(traineeResponse[0]);
    } on AuthException {
      rethrow;
    } catch (e) {
      debugPrint('登入發生錯誤: $e');
      throw AuthException('連線錯誤，請稍後再試。');
    }
  }

  /// 更新使用者個人資料（性別、身高、體重、體脂）
  Future<void> updateProfile({
    required String userId,
    required String gender,
    required double height,
    required double weight,
    required double bodyFat,
  }) async {
    await _supabase
        .from('users')
        .update({
          'gender': gender,
          'height': height,
          'weight': weight,
          'body_fat': bodyFat,
        })
        .eq('id', userId);
  }

  /// 記錄體重/體脂歷史
  Future<void> recordMetrics({
    required String userId,
    required double weight,
    required double bodyFat,
  }) async {
    await _supabase.from('user_metrics_history').insert({
      'user_id': userId,
      'weight': weight,
      'body_fat': bodyFat,
    });
  }
}

/// 自定義驗證例外，包含使用者友善的錯誤訊息
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}
