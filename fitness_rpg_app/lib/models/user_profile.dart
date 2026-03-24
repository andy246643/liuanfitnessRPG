/// 使用者個人資料 Model
class UserProfile {
  final String id;
  final String name;
  final String gender;
  final double height;
  final double weight;
  final double bodyFat;

  const UserProfile({
    required this.id,
    required this.name,
    this.gender = '不提供',
    this.height = 0,
    this.weight = 0,
    this.bodyFat = 0,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      gender: json['gender'] as String? ?? '不提供',
      height: (json['height'] as num?)?.toDouble() ?? 0,
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
      bodyFat: (json['body_fat'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'gender': gender,
      'height': height,
      'weight': weight,
      'body_fat': bodyFat,
    };
  }

  UserProfile copyWith({
    String? id,
    String? name,
    String? gender,
    double? height,
    double? weight,
    double? bodyFat,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      bodyFat: bodyFat ?? this.bodyFat,
    );
  }
}
