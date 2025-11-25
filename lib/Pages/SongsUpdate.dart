import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// Assuming these exist in your project structure based on your snippet
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/Custom_Buttons.dart';

bool get isIOSPlatform {
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

class SongsUpdate extends StatefulWidget {
  const SongsUpdate({super.key});

  @override
  State<SongsUpdate> createState() => _SongsUpdateState();
}

class _SongsUpdateState extends State<SongsUpdate> {
  // We reuse this controller, but we must reset its text every time we open the sheet
  final TextEditingController _songNameController = TextEditingController();

  @override
  void dispose() {
    _songNameController.dispose();
    super.dispose();
  }

  // A helper method to update the song in Firestore
  Future<void> _updateSongName(String docId, String newName) async {
    if (newName.trim().isEmpty) return;

    // Show loading (using your API component)
    Api().showLoading(context);

    try {
      await FirebaseFirestore.instance
          .collection('tact_music')
          .doc(docId)
          .update({'songName': newName.trim()});

      if (!mounted) return;

      // Close the loading dialog
      Navigator.of(context).pop();
      // Close the bottom sheet
      Navigator.of(context).pop();

      Api().showMessage(
        context,
        'Song updated successfully',
        "Success",
        Theme.of(context).primaryColor,
      );
    } catch (e) {
      Navigator.of(context).pop(); // Close loading
      Api().showMessage(
        context,
        'Error updating song: $e',
        "Error",
        Colors.red,
      );
    }
  }

  void _showEditSheet(BuildContext context, DocumentSnapshot doc) {
    final color = Theme.of(context);
    final currentName = doc['songName'] ?? '';

    // Pre-fill the controller with the current name
    _songNameController.text = currentName;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows the sheet to go full height if needed
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        // Add padding to handle the keyboard covering the input
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Edit Song Name",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color.textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _songNameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Song Name',
                prefixIcon: const Icon(Icons.music_note_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.withOpacity(0.1),
              ),
            ),
            const SizedBox(height: 20),
            Custom_Button(
              onPressed: () =>
                  _updateSongName(doc.id, _songNameController.text),
              text: 'Save Changes',
              backgroundColor: color.primaryColor,
              foregroundColor: Colors.white,
              minWidth: double.infinity,
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);

    return Scaffold(
      appBar: isIOSPlatform
          ? CupertinoNavigationBar(
              backgroundColor: color.primaryColor,
              middle: const Text(
                'Manage Songs',
                style: TextStyle(color: Colors.white),
              ),
            )
          : AppBar(
                  centerTitle: true,
                  title: const Text('Manage Songs'),
                  backgroundColor: color.primaryColor,
                  foregroundColor: Colors.white,
                )
                as PreferredSizeWidget,
      body: StreamBuilder<QuerySnapshot>(
        // CHANGED: StreamBuilder listens to changes in real-time
        stream: FirebaseFirestore.instance.collection('tact_music').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("No songs found."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>; // Safety check
              final songName = data['songName'] ?? 'Unknown Title';
              final artistName = data['artist'] ?? 'Unknown Artist';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Container(
                    height: 50,
                    width: 50,
                    decoration: BoxDecoration(
                      color: color.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.music_note,
                      color: color.primaryColor,
                      size: 28,
                    ),
                  ),
                  title: Text(
                    songName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    artistName,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  trailing: const Icon(Icons.edit_rounded, size: 20),
                  onTap: () => _showEditSheet(context, doc),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
