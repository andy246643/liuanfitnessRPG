import 'package:flutter/material.dart';
import '../models/skin.dart';
import '../theme/zen_theme.dart';

class SkinSelectionModal extends StatefulWidget {
  SkinSelectionModal({super.key});

  @override
  State<SkinSelectionModal> createState() => _SkinSelectionModalState();
}

class _SkinSelectionModalState extends State<SkinSelectionModal> {
  // Use ValueNotifier from skin.dart to get current skin
  late Skin selectedPreviewSkin;

  @override
  void initState() {
    super.initState();
    selectedPreviewSkin = currentSkin.value;
  }

  void _showConfirmationDialog(Skin skin) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardBgCol,
        title: Text("更換造型確認", style: TextStyle(fontFamily: fFam, color: txtCol)),
        content: Text(
          "確定要更換造型為 ${skin.name} 嗎？",
          style: TextStyle(fontFamily: fFam, color: dimCol),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFD72B2B), // Brave Red
            ),
            child: Text("取消", style: TextStyle(fontFamily: 'Cubic11')),
          ),
          TextButton(
            onPressed: () {
              // Sync state
              currentSkin.value = skin;
              Navigator.pop(context); // Close dialog
              // Modal stays open as requested
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF2975C6), // Knight Blue
            ),
            child: Text("確定", style: TextStyle(fontFamily: 'Cubic11')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      insetPadding: EdgeInsets.zero, // Full screen modal
      child: Container(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            // Close button
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: Icon(Icons.close, color: txtCol),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            // Preview Area
            Expanded(
              flex: 4,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Center(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFF2975C6), // Knight Blue
                            width: 8, // Thick 8-bit style border
                          ),
                        ),
                        child: Image.asset(
                          selectedPreviewSkin.imagePath,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Image.asset(
                              'assets/images/novice.png',
                              fit: BoxFit.contain,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () =>
                        _showConfirmationDialog(selectedPreviewSkin),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2975C6), // Knight Blue
                      foregroundColor: txtCol,
                    ),
                    child: Text("更換為大頭像", style: TextStyle(fontFamily: fFam, fontSize: 16)),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),
            Text("選擇造型", style: TextStyle(fontFamily: fFam, color: txtCol, fontSize: 20)),
            SizedBox(height: 10),

            // Selection Area (Grid)
            Expanded(
              flex: 3,
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.8, // Fixed ratio to prevent stretching
                ),
                itemCount: allSkins.length,
                itemBuilder: (context, index) {
                  final skin = allSkins[index];
                  final isSelected =
                      skin.id == selectedPreviewSkin.id; // Correct comparsion

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedPreviewSkin = skin;
                      });
                      // _showConfirmationDialog(skin); // Removed auto-trigger
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: isSelected
                            ? Border.all(
                                color: const Color(0xFF2975C6),
                                width: 4,
                              )
                            : Border.all(color: Colors.grey, width: 1),
                        color: dimCol,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Image.asset(
                                skin.imagePath,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.image_not_supported,
                                    color: txtCol,
                                  );
                                },
                              ),
                            ),
                          ),
                          Text(
                            skin.name,
                            style: TextStyle(fontFamily: fFam, color: txtCol, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
