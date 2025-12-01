import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuditService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<void> logAction({
    required String action,
    required String details,
    String? referenceId,
    String? universityName, // <--- NEW
    String? studentName,    // <--- NEW
     String? deviceTime,    // <--- NEW
   required String? committeeName,
   required String? universityCommitteeFace,
   required String? universityLogo,
    
  }) async {
    final user = _auth.currentUser;

    try {
      await _firestore.collection('audit_logs').add({
        'timestamp': FieldValue.serverTimestamp(),
        'uid': user?.uid ?? 'System/Guest',
        'userEmail': user?.email ?? 'Unknown',
        'action': action,
        'details': details,
        'referenceId': referenceId,
        'universityName': universityName ?? 'N/A', // Save University
        'studentName': studentName ?? 'N/A',       // Save Student
        'deviceTime': DateTime.now().toIso8601String(),
        'committeeName': committeeName ?? 'N/A',
        'universityCommitteeFace': universityCommitteeFace ?? 'N/A',
        'universityLogo': universityLogo ?? 'N/A',
      });
    } catch (e) {
      print("Failed to write audit log: $e");
    }
  }
}