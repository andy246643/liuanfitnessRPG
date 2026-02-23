import 'package:flutter/foundation.dart';

class Skin {
  final String id;
  final String name;
  final String imagePath;

  const Skin({
    required this.id,
    required this.name,
    required this.imagePath,
  });
}

// 1. 固定清單 (Hardcoded List)
final Skin liuanSkin = Skin(
  id: 'liuan',
  name: 'liuan',
  imagePath: 'assets/images/skins/liuan/liuan.gif', // Added 'assets/' prefix back
);

final Skin goldenSkin = Skin(
  id: 'golden',
  name: 'golden',
  imagePath: 'assets/images/skins/liuan/golden.gif', // Added 'assets/' prefix back
);

final List<Skin> allSkins = [
  liuanSkin,
  goldenSkin,
];

// Default skin
ValueNotifier<Skin> currentSkin = ValueNotifier<Skin>(liuanSkin);
