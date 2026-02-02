// // ignore_for_file: prefer_const_constructors, use_build_context_synchronously
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:ttact/Components/API.dart';
// import 'package:ttact/Components/Aduit_Logs/Tactso_Audit_Logs.dart'; // Ensure correct path
// import 'package:ttact/Components/NeuDesign.dart';
// import 'dart:io' as io;

// import 'package:ttact/Components/NeumorphicUtils.dart';

// class CommitteeTab extends StatefulWidget {
//   final String currentUid;
//   final String? universityName;
//   final String? universityLogoUrl;
//   final String? loggedMemberName;
//   final String? loggedMemberRole;
//   final String? universityCommitteeFace;
//   final Color baseColor;

//   const CommitteeTab({
//     super.key,
//     required this.currentUid,
//     required this.baseColor,
//     this.universityName,
//     this.universityLogoUrl,
//     this.loggedMemberName,
//     this.loggedMemberRole,
//     this.universityCommitteeFace,
//   });

//   @override
//   State<CommitteeTab> createState() => _CommitteeTabState();
// }

// class _CommitteeTabState extends State<CommitteeTab> {
//   final TextEditingController _nameController = TextEditingController();
//   final TextEditingController _emailController = TextEditingController();
//   final ImagePicker _picker = ImagePicker();
//   String? _selectedRole;
//   XFile? _faceImage;
//   bool _isUploading = false;

//   final List<String> _roles = [
//     'Chairperson',
//     'Deputy Chairperson',
//     'Secretary',
//     'Deputy Secretary',
//     'Treasurer',
//     'Additional Member',
//   ];

//   Future<void> _pickImage() async {
//     final picked = await _picker.pickImage(
//       source: ImageSource.gallery,
//       imageQuality: 85,
//     );
//     if (picked != null) setState(() => _faceImage = picked);
//   }

//   Future<void> _addMember() async {
//     if (_nameController.text.isEmpty ||
//         _emailController.text.isEmpty ||
//         _selectedRole == null ||
//         _faceImage == null) {
//       Api().showMessage(
//         context,
//         "Incomplete",
//         "Fill all fields & upload photo",
//         Colors.orange,
//       );
//       return;
//     }

//     setState(() => _isUploading = true);

//     try {
//       // 1. Upload Image
//       String path =
//           "Tactso Branches/${widget.universityName}/Committee/${_nameController.text}_${DateTime.now().millisecondsSinceEpoch}";
//       String faceUrl = await _uploadFile(_faceImage!, path);

//       // 2. Add to Firestore
//       await FirebaseFirestore.instance
//           .collection('tactso_branches')
//           .doc(widget.currentUid)
//           .collection('committee_members')
//           .add({
//             'name': _nameController.text.trim(),
//             'email': _emailController.text.trim(),
//             'role': _selectedRole,
//             'faceUrl': faceUrl,
//             'addedAt': FieldValue.serverTimestamp(),
//           });

//       // 3. Update Auth Face List
//       await FirebaseFirestore.instance
//           .collection('tactso_branches')
//           .doc(widget.currentUid)
//           .update({
//             'authorizedUserFaceUrls': FieldValue.arrayUnion([faceUrl]),
//           });

//       // 4. Audit Log
//       await TactsoAuditLogs.logAction(
//         action: "ADD_COMMITTEE_MEMBER",
//         details: "Added ${_nameController.text} as $_selectedRole",
//         referenceId: "N/A",
//         universityName: widget.universityName,
//         universityLogo: widget.universityLogoUrl,
//         committeeMemberName: widget.loggedMemberName,
//         committeeMemberRole: widget.loggedMemberRole,
//         universityCommitteeFace: widget.universityCommitteeFace,
//         targetMemberName: _nameController.text,
//         targetMemberRole: _selectedRole,
//       );

//       _nameController.clear();
//       _emailController.clear();
//       setState(() {
//         _faceImage = null;
//         _selectedRole = null;
//         _isUploading = false;
//       });
//       Api().showMessage(context, "Success", "Member Added", Colors.green);
//     } catch (e) {
//       setState(() => _isUploading = false);
//       Api().showMessage(context, "Error", e.toString(), Colors.red);
//     }
//   }

//   Future<String> _uploadFile(XFile file, String path) async {
//     final ref = FirebaseStorage.instance.ref(path);
//     final metadata = SettableMetadata(contentType: 'image/jpeg');
//     if (kIsWeb) {
//       await ref.putData(await file.readAsBytes(), metadata);
//     } else {
//       await ref.putFile(io.File(file.path), metadata);
//     }
//     return await ref.getDownloadURL();
//   }

//   Future<void> _deleteMember(
//     String id,
//     String name,
//     String role,
//     String url,
//   ) async {
//     // Note: Simplify dialog for brevity, use same logic as before
//     await FirebaseFirestore.instance
//         .collection('tactso_branches')
//         .doc(widget.currentUid)
//         .collection('committee_members')
//         .doc(id)
//         .delete();

//     await FirebaseFirestore.instance
//         .collection('tactso_branches')
//         .doc(widget.currentUid)
//         .update({
//           'authorizedUserFaceUrls': FieldValue.arrayRemove([url]),
//         });

//     Api().showMessage(context, "Deleted", "$name removed.", Colors.grey);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         // --- ADD MEMBER FORM ---
//         NeumorphicContainer(
//           color: widget.baseColor,
//           borderRadius: 20,
//           padding: EdgeInsets.all(20),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 "Add Committee Member",
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//               ),
//               SizedBox(height: 20),
//               Row(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Photo Picker
//                   GestureDetector(
//                     onTap: _pickImage,
//                     child: NeumorphicContainer(
//                       color: widget.baseColor,
//                       isPressed: true, // Recessed look for placeholder
//                       padding: EdgeInsets.zero,
//                       child: _faceImage == null
//                           ? Center(
//                               child: Column(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: const [
//                                   Icon(Icons.camera_alt, color: Colors.grey),
//                                   Text(
//                                     "Face",
//                                     style: TextStyle(
//                                       fontSize: 10,
//                                       color: Colors.grey,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             )
//                           : ClipRRect(
//                               borderRadius: BorderRadius.circular(12),
//                               child: kIsWeb
//                                   ? Image.network(
//                                       _faceImage!.path,
//                                       fit: BoxFit.cover,
//                                     )
//                                   : Image.file(
//                                       io.File(_faceImage!.path),
//                                       fit: BoxFit.cover,
//                                     ),
//                             ),
//                     ),
//                   ),
//                   SizedBox(width: 20),
//                   // Inputs
//                   Expanded(
//                     child: Column(
//                       children: [
//                         NeumorphicUtils.buildTextField(
//                           controller: _nameController,
//                           placeholder: "Full Name",
//                           context: context,
//                           prefixIcon: Icons.person,
//                         ),
//                         SizedBox(height: 15),
//                         NeumorphicUtils.buildTextField(
//                           controller: _emailController,
//                           placeholder: "Email Address",
//                           context: context,
//                           prefixIcon: Icons.email,
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//               SizedBox(height: 20),
//               Row(
//                 children: [
//                   Expanded(
//                     child: NeumorphicContainer(
//                       color: widget.baseColor,
//                       isPressed: true,
//                       padding: EdgeInsets.symmetric(horizontal: 12),
//                       child: DropdownButtonHideUnderline(
//                         child: DropdownButton<String>(
//                           hint: Text("Select Role"),
//                           value: _selectedRole,
//                           dropdownColor: widget.baseColor,
//                           items: _roles
//                               .map(
//                                 (r) =>
//                                     DropdownMenuItem(value: r, child: Text(r)),
//                               )
//                               .toList(),
//                           onChanged: (v) => setState(() => _selectedRole = v),
//                         ),
//                       ),
//                     ),
//                   ),
//                   SizedBox(width: 15),
//                   GestureDetector(
//                     onTap: _isUploading ? null : _addMember,
//                     child: NeumorphicContainer(
//                       color: Theme.of(context).primaryColor,
//                       padding: EdgeInsets.symmetric(
//                         horizontal: 30,
//                         vertical: 15,
//                       ),
//                       child: _isUploading
//                           ? SizedBox(
//                               width: 20,
//                               height: 20,
//                               child: CircularProgressIndicator(
//                                 color: Colors.white,
//                                 strokeWidth: 2,
//                               ),
//                             )
//                           : Text(
//                               "Add Member",
//                               style: TextStyle(
//                                 color: Colors.white,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),

//         SizedBox(height: 30),

//         // --- MEMBERS GRID ---
//         StreamBuilder<QuerySnapshot>(
//           stream: FirebaseFirestore.instance
//               .collection('tactso_branches')
//               .doc(widget.currentUid)
//               .collection('committee_members')
//               .orderBy('addedAt')
//               .snapshots(),
//           builder: (context, snapshot) {
//             if (!snapshot.hasData) return CircularProgressIndicator();
//             return GridView.builder(
//               shrinkWrap: true,
//               physics: NeverScrollableScrollPhysics(),
//               gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
//                 maxCrossAxisExtent: 350,
//                 mainAxisExtent: 100,
//                 crossAxisSpacing: 16,
//                 mainAxisSpacing: 16,
//               ),
//               itemCount: snapshot.data!.docs.length,
//               itemBuilder: (context, index) {
//                 var data =
//                     snapshot.data!.docs[index].data() as Map<String, dynamic>;
//                 return NeumorphicContainer(
//                   color: widget.baseColor,
//                   padding: EdgeInsets.all(10),
//                   child: Row(
//                     children: [
//                       ClipRRect(
//                         borderRadius: BorderRadius.circular(8),
//                         child: Image.network(
//                           data['faceUrl'],
//                           width: 60,
//                           height: 60,
//                           fit: BoxFit.cover,
//                           errorBuilder: (c, o, s) =>
//                               Icon(Icons.person, size: 40),
//                         ),
//                       ),
//                       SizedBox(width: 12),
//                       Expanded(
//                         child: Column(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               data['name'],
//                               style: TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: 14,
//                               ),
//                             ),
//                             Text(
//                               data['role'],
//                               style: TextStyle(
//                                 color: Colors.blue,
//                                 fontSize: 12,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                       IconButton(
//                         icon: Icon(Icons.delete_outline, color: Colors.red),
//                         onPressed: () => _deleteMember(
//                           snapshot.data!.docs[index].id,
//                           data['name'],
//                           data['role'],
//                           data['faceUrl'],
//                         ),
//                       ),
//                     ],
//                   ),
//                 );
//               },
//             );
//           },
//         ),
//       ],
//     );
//   }
// }
