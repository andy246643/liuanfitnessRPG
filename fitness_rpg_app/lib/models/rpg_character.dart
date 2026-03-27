class RpgCharacter {
  final String id;
  final String userId;
  final String name;
  final int level;
  final int totalExp;
  final int currentEnergy;
  final int attrChest;
  final int attrBack;
  final int attrLegs;
  final int attrArms;
  final int attrCore;
  final int attrCardio;
  final int streakDays;
  final String? lastTrainingDate;

  RpgCharacter({
    required this.id,
    required this.userId,
    this.name = '冒險者',
    this.level = 1,
    this.totalExp = 0,
    this.currentEnergy = 0,
    this.attrChest = 0,
    this.attrBack = 0,
    this.attrLegs = 0,
    this.attrArms = 0,
    this.attrCore = 0,
    this.attrCardio = 0,
    this.streakDays = 0,
    this.lastTrainingDate,
  });

  /// 升到下一級所需的總經驗
  int get expForNextLevel => level * 100;

  /// 目前等級內的經驗進度
  int get currentLevelExp {
    int spent = 0;
    for (int l = 1; l < level; l++) {
      spent += l * 100;
    }
    return totalExp - spent;
  }

  /// 升級進度 0.0 ~ 1.0
  double get levelProgress {
    if (expForNextLevel <= 0) return 0;
    return (currentLevelExp / expForNextLevel).clamp(0.0, 1.0);
  }

  /// 六大屬性 Map（用於雷達圖）
  Map<String, int> get attributes => {
    '胸': attrChest,
    '背': attrBack,
    '腿': attrLegs,
    '手臂': attrArms,
    '核心': attrCore,
    '心肺': attrCardio,
  };

  /// 屬性總和
  int get totalAttributes => attrChest + attrBack + attrLegs + attrArms + attrCore + attrCardio;

  factory RpgCharacter.fromJson(Map<String, dynamic> json) {
    return RpgCharacter(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String? ?? '冒險者',
      level: json['level'] as int? ?? 1,
      totalExp: json['total_exp'] as int? ?? 0,
      currentEnergy: json['current_energy'] as int? ?? 0,
      attrChest: json['attr_chest'] as int? ?? 0,
      attrBack: json['attr_back'] as int? ?? 0,
      attrLegs: json['attr_legs'] as int? ?? 0,
      attrArms: json['attr_arms'] as int? ?? 0,
      attrCore: json['attr_core'] as int? ?? 0,
      attrCardio: json['attr_cardio'] as int? ?? 0,
      streakDays: json['streak_days'] as int? ?? 0,
      lastTrainingDate: json['last_training_date'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'name': name,
    'level': level,
    'total_exp': totalExp,
    'current_energy': currentEnergy,
    'attr_chest': attrChest,
    'attr_back': attrBack,
    'attr_legs': attrLegs,
    'attr_arms': attrArms,
    'attr_core': attrCore,
    'attr_cardio': attrCardio,
    'streak_days': streakDays,
    'last_training_date': lastTrainingDate,
    'updated_at': DateTime.now().toIso8601String(),
  };

  RpgCharacter copyWith({
    int? level,
    int? totalExp,
    int? currentEnergy,
    int? attrChest,
    int? attrBack,
    int? attrLegs,
    int? attrArms,
    int? attrCore,
    int? attrCardio,
    int? streakDays,
    String? lastTrainingDate,
  }) {
    return RpgCharacter(
      id: id,
      userId: userId,
      name: name,
      level: level ?? this.level,
      totalExp: totalExp ?? this.totalExp,
      currentEnergy: currentEnergy ?? this.currentEnergy,
      attrChest: attrChest ?? this.attrChest,
      attrBack: attrBack ?? this.attrBack,
      attrLegs: attrLegs ?? this.attrLegs,
      attrArms: attrArms ?? this.attrArms,
      attrCore: attrCore ?? this.attrCore,
      attrCardio: attrCardio ?? this.attrCardio,
      streakDays: streakDays ?? this.streakDays,
      lastTrainingDate: lastTrainingDate ?? this.lastTrainingDate,
    );
  }
}
