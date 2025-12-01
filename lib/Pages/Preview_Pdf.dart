import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfViewPage extends StatelessWidget {
  final String selectedDistrictElder;
  final String selectedCommunityName;
  final String selectedProvince;
  final String overseerInitialsAndSurname;
  final Map<String, dynamic> overseerData;
  final Uint8List? logoBytes;
  final int memberLimit;

  const PdfViewPage({
    super.key,
    required this.selectedDistrictElder,
    required this.selectedCommunityName,
    required this.selectedProvince,
    required this.overseerInitialsAndSurname,
    required this.overseerData,
    this.logoBytes,
    required this.memberLimit,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Report Preview"),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      // PdfPreview handles displaying, zooming, printing, and downloading (sharing)
      body: PdfPreview(
        build: (format) => _generatePdf(format),
        canChangeOrientation: false,
        canDebug: false,
      ),
    );
  }

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final pdf = pw.Document();

    // Load Font
    final cloisterFont = pw.Font.ttf(
      await rootBundle.load('assets/CloisterBlack.ttf'),
    );

    // Fetch Data for Table
    final balanceSheetTable = await _buildPdfBalanceSheetTable(memberLimit);

    // Determine Month Name
    final month = DateTime.now().month;
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June', 
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    String monthName = months[month - 1];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        build: (pw.Context context) {
          return [
            if (logoBytes != null)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Image(pw.MemoryImage(logoBytes!), width: 100, height: 100),
                  pw.Column(
                    children: [
                      pw.Center(
                          child: pw.Text('The Twelve Apostles Church in Trinity',
                              style: pw.TextStyle(
                                  fontSize: 25,
                                  fontWeight: pw.FontWeight.bold,
                                  font: cloisterFont))),
                      pw.SizedBox(height: 10),
                      pw.Center(child: pw.Text('P. O. Box 40376, Red Hill, 4071')),
                      pw.Row(children: [
                        pw.Text('Tel./Fax No\'s:', style: pw.TextStyle(font: cloisterFont)),
                        pw.SizedBox(width: 5),
                        pw.Text('(031) 569 6164')
                      ], mainAxisAlignment: pw.MainAxisAlignment.center),
                      pw.Row(children: [
                        pw.Text('Email:', style: pw.TextStyle(font: cloisterFont)),
                        pw.SizedBox(width: 5),
                        pw.Text('thetacc@telkomsa.net')
                      ], mainAxisAlignment: pw.MainAxisAlignment.center),
                    ],
                  ),
                ],
              ),
            pw.SizedBox(height: 30),
            pw.Text('Income and Expenditure Statement',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),

            _buildPdfTextRow('For the Month:', monthName, 'Year:', '${DateTime.now().year}'),
            _buildPdfTextRow('Overseer:', overseerInitialsAndSurname, 'Code No:', 'CODE'),
            _buildPdfTextRow('District Elder:', selectedDistrictElder),
            _buildPdfTextRow('Community Elder:', '_____________'),
            _buildPdfTextRow('Community Name:', selectedCommunityName),
            _buildPdfTextRow('Province: $selectedProvince', '', 'Region:', 'Region'),

            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.Text('Income / Receipts',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            _buildPdfReportRow('Tithe Offerings - Week 1', 'R', 'c'),
            _buildPdfReportRow('Tithe Offerings - Week 2', 'R', 'c'),
            _buildPdfReportRow('Tithe Offerings - Week 3', 'R', 'c'),
            _buildPdfReportRow('Tithe Offerings - Week 4', 'R', 'c'),
            _buildPdfReportRow('Others', 'R', 'c'),
            _buildPdfReportRow('Month End', 'R', 'c'),
            pw.SizedBox(height: 10),
            _buildPdfReportRow('Total Income', 'R', 'c', isTotal: true),

            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.Text('Expenditure',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            _buildPdfReportRow('Rent Period', 'R', 'c'),
            _buildPdfReportRow('Wine and Priest Wafers', 'R', 'c'),
            _buildPdfReportRow('Power and Lights', 'R', 'c'),
            _buildPdfReportRow('Sundries/Repairs', 'R', 'c'),
            _buildPdfReportRow('Central Council', 'R', 'c'),
            _buildPdfReportRow('Equipment / General', 'R', 'c'),
            pw.SizedBox(height: 10),
            _buildPdfReportRow('Total Expenditure', 'R', 'c', isTotal: true),

            pw.SizedBox(height: 20),
            pw.Divider(),
            _buildPdfReportRow('Credit Balance (Amount Banked)', 'R', 'c',
                isTotal: true, isCreditBalance: true),

            pw.SizedBox(height: 20),
            pw.Text('Bank Name: Standard Bank'),
            pw.Text('Account Name: The TACT'),
            pw.Text('Account No: 051074958'),
            pw.Text('Branch Name: Kingsmead'),
            pw.Text('Branch Code: 040026'),
            pw.SizedBox(height: 20),
            pw.Text(
                'Please write your name and the name of your Community in the Deposit Slip Senders Details Column.'),

            pw.SizedBox(height: 30),
            pw.Text('Balance Sheet',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),

            _buildPdfTextRow('For the Month of:', '${DateTime.now().month}',
                'Year:', '${DateTime.now().year}'),
            _buildPdfTextRow('Overseer:', overseerInitialsAndSurname),
            _buildPdfTextRow('District Elder:', selectedDistrictElder),
            _buildPdfTextRow('Community Elder:', '________________'),
            _buildPdfTextRow('Community Name:', selectedCommunityName),

            pw.SizedBox(height: 20),
            pw.Text('Members Tithe Offerings',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            balanceSheetTable, // The dynamic table

            pw.SizedBox(height: 30),
            pw.Text(
                'NB: Attach all receipts and Bank Deposit Slips with Neat and Clear Details',
                style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
            pw.SizedBox(height: 20),
            pw.Text('Signatures:',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            _buildPdfSignatureRow('Overseer', overseerInitialsAndSurname),
            _buildPdfSignatureRow('Community Elder', '_____________'),
            _buildPdfSignatureRow('Secretary', '_____________'),
            _buildPdfSignatureRow('District Elder', selectedDistrictElder),
            _buildPdfSignatureRow('Treasurer', '_____________'),
            _buildPdfSignatureRow('Contact Person', '_____________'),
            pw.SizedBox(height: 20),
            pw.Text('Telephone No: __________'),
            pw.Text('Email Address: __________'),
          ];
        },
      ),
    );

    return pdf.save();
  }

  Future<pw.Widget> _buildPdfBalanceSheetTable(int limit) async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;

    Query<Map<String, dynamic>> query = firestore
        .collection('users')
        .where('districtElderName', isEqualTo: selectedDistrictElder)
        .where('communityName', isEqualTo: selectedCommunityName)
        .where('overseerUid', isEqualTo: FirebaseAuth.instance.currentUser?.uid);

    // FIX: Only apply limit if it is within valid Firestore bounds (<= 10000).
    // If limit is higher (e.g. 99999), we skip the limit call to fetch all.
    if (limit > 0 && limit <= 10000) {
      query = query.limit(limit);
    }

    var memberLatestData = await query.get();

    List<List<String>> tableData = [
      ['Members Name and Surname', 'WEEK 1', 'WEEK 2', 'WEEK 3', 'WEEK 4', 'MONTHLY'],
    ];

    double grandTotal = 0.00;

    for (var d in memberLatestData.docs) {
      var data = d.data();
      String name = data['name'] ?? 'N/A';
      String surname = data['surname'] ?? 'N/A';
      double w1 = (data['week1'] as num? ?? 0.0).toDouble();
      double w2 = (data['week2'] as num? ?? 0.0).toDouble();
      double w3 = (data['week3'] as num? ?? 0.0).toDouble();
      double w4 = (data['week4'] as num? ?? 0.0).toDouble();
      double total = w1 + w2 + w3 + w4;

      tableData.add([
        '$name $surname',
        'R${w1.toStringAsFixed(2)}',
        'R${w2.toStringAsFixed(2)}',
        'R${w3.toStringAsFixed(2)}',
        'R${w4.toStringAsFixed(2)}',
        'R${total.toStringAsFixed(2)}',
      ]);
      grandTotal += total;
    }

    return pw.Column(
      children: [
        pw.TableHelper.fromTextArray(
          cellAlignment: pw.Alignment.centerLeft,
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
          cellPadding: const pw.EdgeInsets.all(2),
          data: tableData,
        ),
        pw.SizedBox(height: 10),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('GRAND TOTAL: R ${grandTotal.toStringAsFixed(2)}',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        ),
      ],
    );
  }

  // --- PDF HELPERS ---
  pw.Widget _buildPdfTextRow(String l1, String v1, [String? l2, String? v2]) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('$l1 $v1'),
        if (l2 != null && v2 != null) pw.Text('$l2 $v2'),
      ],
    );
  }

  pw.Widget _buildPdfReportRow(String label, String r, String c,
      {bool isTotal = false, bool isCreditBalance = false}) {
    final style = pw.TextStyle(
        fontWeight: (isTotal || isCreditBalance)
            ? pw.FontWeight.bold
            : pw.FontWeight.normal);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.0),
      child: pw.Row(children: [
        pw.Expanded(flex: 3, child: pw.Text(label, style: style)),
        pw.Expanded(
            flex: 1,
            child: pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text('$r _______', style: style))),
        pw.Expanded(
            flex: 1,
            child: pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text('$c _______', style: style))),
      ]),
    );
  }

  pw.Widget _buildPdfSignatureRow(String role, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4.0),
      child: pw.Row(children: [
        pw.Expanded(flex: 2, child: pw.Text('$role:')),
        pw.Expanded(flex: 3, child: pw.Text(value)),
        pw.SizedBox(width: 10),
        pw.Expanded(flex: 1, child: pw.Text('Signature:')),
        pw.Expanded(flex: 3, child: pw.Text('___________________')),
      ]),
    );
  }
}