import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class OverseerAuditpage extends StatefulWidget {
  const OverseerAuditpage({super.key});

  @override
  State<OverseerAuditpage> createState() => _OverseerAuditpageState();
}

class _OverseerAuditpageState extends State<OverseerAuditpage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- Color Palette ---
  final Color primaryBlue = const Color(0xFF1976D2);
  final Color successGreen = const Color(0xFF388E3C);
  final Color errorRed = const Color(0xFFD32F2F);
  final Color neutralGrey = const Color(0xFF757575);
  final Color lightBackground = const Color(0xFFF5F7FA);

  Stream<QuerySnapshot> _getAuditStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('audit_logs')
        .doc(user.uid)
        .collection('logs')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Color _getActionColor(String action) {
    action = action.toUpperCase();
    if (action.contains('CREATE') ||
        action.contains('ADD') ||
        action.contains('UPDATE') ||
        action.contains('APPROVE')) {
      return successGreen;
    } else if (action.contains('DELETE') ||
        action.contains('REMOVE') ||
        action.contains('REJECT')) {
      return errorRed;
    } else if (action.contains('VIEW') || action.contains('READ')) {
      return primaryBlue;
    }
    return neutralGrey;
  }

  // --- IMAGE PREVIEW DIALOG ---
  void _showImagePreview(BuildContext context, String imageUrl, String title) {
    if (imageUrl.isEmpty || imageUrl == 'N/A') return;
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

  // --- HELPER TO GET TARGET STRING ---
  String _getTargetDisplay(Map<String, dynamic> d) {
    // 1. Check for Expense
    if (d['expenseName'] != null && d['expenseName'] != 'N/A') {
      String amt = d['expenseAmount'] ?? '';
      return "Exp: ${d['expenseName']} ($amt)";
    }
    // 2. Check for Committee Target
    if (d['targetMemberName'] != null && d['targetMemberName'] != 'N/A') {
      return "${d['targetMemberName']} (Committee)";
    }
    // 3. Check for General Member
    if (d['memberName'] != null && d['memberName'] != 'N/A') {
      return d['memberName'];
    }
    return '-';
  }

  // --- PDF GENERATION ---
  Future<void> _generateAndDownloadPdf() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final pdf = pw.Document();
    final snapshot = await _firestore
        .collection('audit_logs')
        .doc(user.uid)
        .collection('logs') 
        .get();

    final data = snapshot.docs;

    // Load App Logo for Header
    final logoImage = await rootBundle.load('assets/dankie_logo.PNG');
    final logoProvider = pw.MemoryImage(logoImage.buffer.asUint8List());

    // Define PDF Colors
    final pdfPrimaryBlue = PdfColor.fromInt(primaryBlue.value);
    final pdfHeaderBg = PdfColor.fromInt(0xFFE3F2FD);

    // Pre-fetch rows data
    List<List<dynamic>> pdfRows = [];

    for (var doc in data) {
      final d = doc.data();
      Timestamp? ts = d['timestamp'] as Timestamp?;
      String dateStr = ts != null
          ? DateFormat('yyyy-MM-dd HH:mm').format(ts.toDate())
          : '-';

      // -- Face Logic --
      String faceUrl = d['actorFaceUrl'] ?? 'N/A';
      pw.Widget faceWidget = pw.Text("-");
      if (faceUrl != 'N/A' && faceUrl.isNotEmpty) {
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

      // -- Actor Logic --
      String actorName = d['actorName'] ?? 'Unknown';
      String actorRole = d['actorRole'] ?? '';
      String displayActor = actorRole.isNotEmpty
          ? "$actorName\n($actorRole)"
          : actorName;

      // -- Target Logic --
      String targetInfo = _getTargetDisplay(d);

      pdfRows.add([
        dateStr,
        faceWidget, // Face Image
        displayActor,
        d['overseerName'] ?? '-',
        d['action'] ?? '-',
        targetInfo,
        d['overseerEmail'] ?? '-',
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
                        'Overseer Audit Report',
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
                'Actor',
                'Overseer Area',
                'Action',
                'Target / Expense',
                'Email',
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
          'Audit_Log_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
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
              // Hide explicit image URLs to keep details clean
              if (e.key.contains('FaceUrl') || e.key.contains('image')) {
                return const SizedBox.shrink();
              }
              // Hide 'N/A' fields to keep it clean
              if (valueStr == 'N/A') return const SizedBox.shrink();

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
                          'Overseer Audit Logs',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: primaryBlue,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Track expenses, committee actions, and updates.',
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
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(color: primaryBlue),
                      );
                    }
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
                            DataColumn(label: Text('FACE')),
                            DataColumn(label: Text('ACTOR')),
                            DataColumn(label: Text('OVERSEER AREA')),
                            DataColumn(label: Text('ACTION')),
                            DataColumn(label: Text('TARGET / EXPENSE')),
                            DataColumn(label: Text('EMAIL')),
                            DataColumn(label: Text('DETAILS')),
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

                            // --- 1. DATA ALIGNED WITH OverseerAuditLogs CLASS ---

                            // FACE
                            String faceUrl = data['actorFaceUrl'] ?? 'N/A';

                            // ACTOR
                            String actorName = data['actorName'] ?? 'Unknown';
                            String actorRole = data['actorRole'] ?? '';

                            // OVERSEER NAME
                            String overseerName = data['overseerName'] ?? 'N/A';

                            // TARGET / EXPENSE DISPLAY
                            String targetDisplay = _getTargetDisplay(data);

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

                                // 2. Face (Clickable)
                                DataCell(
                                  InkWell(
                                    onTap: () => _showImagePreview(
                                      context,
                                      faceUrl,
                                      "Actor Face",
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
                                        backgroundImage:
                                            (faceUrl != 'N/A' &&
                                                faceUrl.isNotEmpty)
                                            ? NetworkImage(faceUrl)
                                            : null,
                                        child:
                                            (faceUrl == 'N/A' ||
                                                faceUrl.isEmpty)
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

                                // 3. Actor Name & Role
                                DataCell(
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        actorName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (actorRole.isNotEmpty &&
                                          actorRole != 'Unknown Portfolio')
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

                                // 4. Overseer Name (Was University)
                                DataCell(
                                  Text(
                                    overseerName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),

                                // 5. Action
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

                                // 6. Target / Expense
                                DataCell(Text(targetDisplay)),

                                // 7. User (Overseer Email)
                                DataCell(
                                  Text(data['overseerEmail'] ?? 'System'),
                                ),

                                // 8. Details
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
