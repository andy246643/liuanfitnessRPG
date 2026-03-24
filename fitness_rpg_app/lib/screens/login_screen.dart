import 'package:flutter/material.dart';
import '../theme/zen_theme.dart';
import '../widgets/zen_card.dart';

class LoginScreen extends StatefulWidget {
  final Function(String traineeName, String coachName) onLogin;

  const LoginScreen({super.key, required this.onLogin});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController coachNameController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    coachNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      children: [
        ZenCard(
          child: Column(
            children: [
              Text(
                (isRpgMode.value ? "🔑 冒險者連線" : "伺服器連結"),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: fFam,
                  color: txtCol,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: coachNameController,
                style: TextStyle(fontFamily: fFam, color: txtCol, decoration: TextDecoration.none),
                decoration: InputDecoration(
                  hintText: "教練名稱",
                  hintStyle: TextStyle(fontFamily: fFam, color: dimCol),
                  filled: true,
                  fillColor: bgCol,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  prefixIcon: Icon(Icons.shield, color: pCol),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                style: TextStyle(fontFamily: fFam, color: txtCol, decoration: TextDecoration.none),
                decoration: InputDecoration(
                  hintText: (isRpgMode.value ? "冒險者名稱" : "您的名字"),
                  hintStyle: TextStyle(fontFamily: fFam, color: dimCol),
                  filled: true,
                  fillColor: bgCol,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  prefixIcon: Icon(Icons.person, color: pCol),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onLogin(
                      nameController.text.trim(),
                      coachNameController.text.trim(),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pCol,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text("進入系統", style: TextStyle(fontFamily: fFam, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
