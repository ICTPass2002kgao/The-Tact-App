import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ionicons/ionicons.dart';
import 'package:ttact/Components/CustomOutlinedButton.dart';

class AddMusic extends StatefulWidget {
  const AddMusic({super.key});

  @override
  State<AddMusic> createState() => _AddMusicState();
}

class _AddMusicState extends State<AddMusic> {
  final ImagePicker _picker = ImagePicker();
  late XFile videoFile;

  Future<void> pickImages() async {
    final picked = await _picker.pickMedia();
    if (picked!.path.isNotEmpty) {
      setState(() {
        videoFile = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(18.0),
      child: ListView(
        children: [
          Center(
            child: Card(
              elevation: 10,
              color: Colors.transparent,
              child: GestureDetector(
                onTap: pickImages,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: SweepGradient(
                      transform: GradientRotation(5),
                      center: AlignmentGeometry.directional(1, 0.009),
                      startAngle: 0.1,
                      endAngle: 10,
                      colors: [
                        color.hintColor,
                        color.primaryColor,
                        color.splashColor.withOpacity(0.5),
                        color.primaryColorDark,
                      ],
                    ),
                  ),
                  height: 200,
                  width: 200,
                  child: Icon(
                    Ionicons.add_sharp,
                    size: 70,
                    color: color.scaffoldBackgroundColor,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 10),
          CupertinoTextField(
            placeholder: 'Please enter the song name',
            keyboardType: TextInputType.name,
            padding: EdgeInsetsGeometry.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(width: 1, color: color.primaryColor),
              shape: BoxShape.rectangle,
            ),
          ),
          SizedBox(height: 10),
          CupertinoTextField(
            placeholder: 'Please enter the artist\'s name',
            keyboardType: TextInputType.name,
            padding: EdgeInsetsGeometry.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(width: 1, color: color.primaryColor),
              shape: BoxShape.rectangle,
            ),
          ),
          SizedBox(height: 10),
          CustomOutlinedButton(
            onPressed: () {},
            text: 'Upload Song',
            backgroundColor: color.scaffoldBackgroundColor,
            foregroundColor: color.primaryColor,
            width: double.infinity,
          ),
        ],
      ),
    );
  }
}
