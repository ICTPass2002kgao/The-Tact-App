import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UploadProductPage extends StatefulWidget {
  @override
  _UploadProductPageState createState() => _UploadProductPageState();
}

class _UploadProductPageState extends State<UploadProductPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  List<XFile> imageFiles = [];

  final ImagePicker _picker = ImagePicker();

  Future<void> pickImages() async {
    final picked = await _picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        imageFiles = picked;
      });
    }
  }

  Future<void> uploadProduct() async {
    if (nameController.text.isEmpty || imageFiles.isEmpty) return;

    List<String> imageUrls = [];

    for (var file in imageFiles) {
      final ref = FirebaseStorage.instance.ref("products/${DateTime.now().millisecondsSinceEpoch}_${file.name}");
      await ref.putFile(File(file.path));
      final url = await ref.getDownloadURL();
      imageUrls.add(url);
    }

    await FirebaseFirestore.instance.collection('products').add({
      'name': nameController.text,
      'description': descController.text,
      'imageUrls': imageUrls,
      'createdAt': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Product uploaded with ${imageUrls.length} images")));

    nameController.clear();
    descController.clear();
    setState(() {
      imageFiles = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text("Upload Product")),
      backgroundColor: color.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: "Product Name"),
            ),
            TextField(
              controller: descController,
              decoration: InputDecoration(labelText: "Description"),
            ),
            SizedBox(height: 10),
            ElevatedButton(onPressed: pickImages, child: Text("Pick Images")),
            if (imageFiles.isNotEmpty)
              Wrap(
                spacing: 10,
                children: imageFiles.map((file) {
                  return Image.file(File(file.path), width: 100, height: 100, fit: BoxFit.cover);
                }).toList(),
              ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: uploadProduct,
              child: Text("Upload Product"),
            ),
          ],
        ),
      ),
    );
  }
}
