import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class AuditPage extends StatefulWidget {
  const AuditPage({super.key});

  @override
  State<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends State<AuditPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- Color Palette ---
  final Color primaryBlue = const Color(0xFF1976D2);
  final Color successGreen = const Color(0xFF388E3C);
  final Color errorRed = const Color(0xFFD32F2F);
  final Color neutralGrey = const Color(0xFF757575);
  final Color lightBackground = const Color(0xFFF5F7FA);

  Stream<QuerySnapshot> _getAuditStream() {
    return _firestore
        .collection('audit_logs')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Color _getActionColor(String action) {
    action = action.toUpperCase();
    if (action.contains('CREATE') ||
        action.contains('ADD') ||
        action.contains('UPDATE')) {
      return successGreen;
    } else if (action.contains('DELETE') || action.contains('REMOVE')) {
      return errorRed;
    } else if (action.contains('VIEW') || action.contains('READ')) {
      return primaryBlue;
    }
    return neutralGrey;
  }

  // --- IMAGE PREVIEW DIALOG ---
  void _showImagePreview(BuildContext context, String imageUrl, String title) {
    if (imageUrl.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  loadingBuilder: (ctx, child, progress) {
                    if (progress == null) return child;
                    return const CircularProgressIndicator(color: Colors.white);
                  },
                  errorBuilder: (ctx, error, stack) => const Icon(
                    Icons.broken_image,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- PDF GENERATION ---
  Future<void> _generateAndDownloadPdf() async {
    final pdf = pw.Document();
    final snapshot = await _firestore
        .collection('audit_logs')
        .orderBy('timestamp', descending: true)
        .get();

    final data = snapshot.docs;

    // Load App Logo for Header
    final logoImage = await rootBundle.load('assets/dankie_logo.PNG');
    final logoProvider = pw.MemoryImage(logoImage.buffer.asUint8List());

    // Define PDF Colors
    final pdfPrimaryBlue = PdfColor.fromInt(primaryBlue.value);
    final pdfHeaderBg = PdfColor.fromInt(0xFFE3F2FD);

    // Pre-fetch rows data (images need to be fetched async)
    List<List<dynamic>> pdfRows = [];

    for (var doc in data) {
      final d = doc.data() as Map<String, dynamic>;
      Timestamp? ts = d['timestamp'] as Timestamp?;
      String dateStr = ts != null
          ? DateFormat('yyyy-MM-dd HH:mm').format(ts.toDate())
          : '-';

      // -- NEW: Retrieve Face with Fallbacks --
      String faceUrl = d['actorFaceUrl'] ?? 
                       d['universityCommitteeFace'] ?? 
                       d['educationOfficerFaceUrl'] ?? 
                       '';

      pw.Widget faceWidget = pw.Text("-");
      if (faceUrl.isNotEmpty) {
        try {
          final netImage = await networkImage(faceUrl);
          faceWidget = pw.ClipOval(
            child: pw.Image(
              netImage,
              width: 20,
              height: 20,
              fit: pw.BoxFit.cover,
            ),
          );
        } catch (e) {
          /* Ignore image load error */
        }
      }

      // -- NEW: Retrieve Actor Name/Role --
      String actorName = d['actorName'] ?? d['committeeName'] ?? d['educationOfficerName'] ?? '-';
      String actorRole = d['actorRole'] ?? '';
      String displayActor = actorRole.isNotEmpty ? "$actorName\n($actorRole)" : actorName;

      // -- NEW: Retrieve Target (Student or Member) --
      String studentName = d['studentName'] ?? 'N/A';
      String targetMember = d['targetMemberName'] ?? 'N/A';
      String targetInfo = (studentName != 'N/A') 
          ? studentName 
          : (targetMember != 'N/A' ? "$targetMember (Member)" : '-');

      pdfRows.add([
        dateStr,
        faceWidget, // Face Image
        displayActor,
        d['universityName'] ?? '-',
        d['action'] ?? '-',
        targetInfo,
        d['branchEmail'] ?? d['userEmail'] ?? '-',
      ]);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: pdfPrimaryBlue, width: 2),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      pw.Image(logoProvider, width: 40, height: 40),
                      pw.SizedBox(width: 10),
                      pw.Text(
                        'Dankie Audit Report',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: pdfPrimaryBlue,
                        ),
                      ),
                    ],
                  ),
                  pw.Text(
                    DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            // Table
            pw.TableHelper.fromTextArray(
              context: context,
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerDecoration: pw.BoxDecoration(color: pdfHeaderBg),
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: pdfPrimaryBlue,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.centerLeft,
              headers: [
                'Time',
                'Face',
                'Committee / Actor',
                'University',
                'Action',
                'Target (Student/Mem)',
                'User Email',
              ],
              data: pdfRows,
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name:
          'Dankie_Audit_Log_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
    );
  }

  void _showFullDetails(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: primaryBlue),
            const SizedBox(width: 10),
            const Text("Full Audit Details"),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: data.entries.map((e) {
              String valueStr = e.value.toString();
              if (e.value is Timestamp) {
                valueStr = DateFormat(
                  'yyyy-MM-dd HH:mm:ss',
                ).format((e.value as Timestamp).toDate());
              }
              if (e.key.contains('Url') || e.key.contains('image'))
                return const SizedBox.shrink(); // Hide raw URLs in details

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.key.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        color: neutralGrey,
                      ),
                    ),
                    SelectableText(
                      valueStr,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    Divider(color: Colors.grey.shade200),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBackground,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER ---
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white,
                      backgroundImage: const AssetImage(
                        'assets/dankie_logo.PNG',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'System Audit Logs',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: primaryBlue,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Track operations, status updates, and document access.',
                          style: TextStyle(fontSize: 14, color: neutralGrey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _generateAndDownloadPdf,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 20),
                    label: const Text("Export PDF"),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- TABLE ---
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: StreamBuilder<QuerySnapshot>(
                  stream: _getAuditStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return Center(
                        child: CircularProgressIndicator(color: primaryBlue),
                      );
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history_toggle_off,
                              size: 40,
                              color: neutralGrey,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "No logs found.",
                              style: TextStyle(color: neutralGrey),
                            ),
                          ],
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: MaterialStateProperty.all(
                            const Color(0xFFF8F9FC),
                          ),
                          headingRowHeight: 50,
                          dataRowMinHeight: 60,
                          dataRowMaxHeight: 70,
                          columnSpacing: 30,
                          horizontalMargin: 24,
                          columns: const [
                            DataColumn(label: Text('TIME')),
                            DataColumn(label: Text('COMMITTEE FACE')),
                            DataColumn(label: Text('COMMITTEE NAME')),
                            DataColumn(label: Text('UNIVERSITY')),
                            DataColumn(label: Text('LOGO')),
                            DataColumn(label: Text('ACTION')),
                            DataColumn(label: Text('TARGET (Student/Mem)')), // Renamed Column
                            DataColumn(label: Text('USER')),
                            DataColumn(label: Text('VIEW')),
                          ],
                          rows: snapshot.data!.docs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            Timestamp? ts = data['timestamp'] as Timestamp?;
                            String dateStr = ts != null
                                ? DateFormat(
                                    'MMM dd, HH:mm',
                                  ).format(ts.toDate())
                                : '-';
                            String actionStr = data['action'] ?? '';
                            Color actionColor = _getActionColor(actionStr);

                            // --- 1. NEW DATA RETRIEVAL LOGIC (With Fallbacks) ---
                            
                            // FACE: Try new 'actorFaceUrl', fallback to old fields
                            String faceUrl = data['actorFaceUrl'] ?? 
                                             data['universityCommitteeFace'] ??
                                             data['educationOfficerFaceUrl'] ?? 
                                             '';
                                             
                            // LOGO: Try new 'universityLogo', fallback to old 'imageUrl'
                            String logoUrl = data['universityLogo'] ?? '';
                            if (logoUrl.isEmpty) {
                              if (data['imageUrl'] is List && (data['imageUrl'] as List).isNotEmpty) {
                                logoUrl = (data['imageUrl'] as List)[0];
                              } else if (data['imageUrl'] is String) {
                                logoUrl = data['imageUrl'];
                              }
                            }

                            // NAME: Try new 'actorName', fallback to old names
                            String actorName = data['actorName'] ?? 
                                               data['committeeName'] ?? 
                                               data['educationOfficerName'] ?? 
                                               '-';
                            
                            // ROLE: New field
                            String actorRole = data['actorRole'] ?? '';

                            // TARGET: Try 'studentName' or 'targetMemberName'
                            String studentName = data['studentName'] ?? 'N/A';
                            String targetMemberName = data['targetMemberName'] ?? 'N/A';
                            String targetDisplay = (studentName != 'N/A' && studentName != 'Unknown') 
                                ? studentName 
                                : (targetMemberName != 'N/A' ? "$targetMemberName (Member)" : '-');


                            return DataRow(
                              cells: [
                                // 1. Time
                                DataCell(
                                  Text(
                                    dateStr,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),

                                // 2. Committee Face (Clickable)
                                DataCell(
                                  InkWell(
                                    onTap: () => _showImagePreview(
                                      context,
                                      faceUrl,
                                      "Committee Face",
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: primaryBlue.withOpacity(0.3),
                                        ),
                                      ),
                                      child: CircleAvatar(
                                        radius: 18,
                                        backgroundColor: Colors.grey.shade100,
                                        backgroundImage: faceUrl.isNotEmpty
                                            ? NetworkImage(faceUrl)
                                            : null,
                                        child: faceUrl.isEmpty
                                            ? Icon(
                                                Icons.person,
                                                size: 16,
                                                color: Colors.grey,
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),

                                // 3. Committee Name & Role
                                DataCell(
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        actorName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (actorRole.isNotEmpty)
                                        Text(
                                          actorRole,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: neutralGrey,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                // 4. University Name
                                DataCell(
                                  Text(
                                    data['universityName'] ?? '-',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),

                                // 5. University Logo (Clickable)
                                DataCell(
                                  InkWell(
                                    onTap: () => _showImagePreview(
                                      context,
                                      logoUrl,
                                      "University Logo",
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      child: CircleAvatar(
                                        radius: 18,
                                        backgroundColor: Colors.white,
                                        backgroundImage: logoUrl.isNotEmpty
                                            ? NetworkImage(logoUrl)
                                            : null,
                                        child: logoUrl.isEmpty
                                            ? Icon(
                                                Icons.school,
                                                size: 16,
                                                color: Colors.grey,
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),

                                // 6. Action
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: actionColor.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: actionColor.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Text(
                                      actionStr,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                        color: actionColor,
                                      ),
                                    ),
                                  ),
                                ),

                                // 7. Target (Student or Member)
                                DataCell(Text(targetDisplay)),

                                // 8. User (Branch Email)
                                DataCell(Text(data['branchEmail'] ?? data['userEmail'] ?? 'System')),

                                // 9. Details
                                DataCell(
                                  IconButton(
                                    icon: Icon(
                                      Icons.visibility_outlined,
                                      color: primaryBlue,
                                    ),
                                    onPressed: () =>
                                        _showFullDetails(context, data),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}