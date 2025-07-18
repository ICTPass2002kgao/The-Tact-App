import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/CustomOutlinedButton.dart';
import 'package:pdf/pdf.dart'; // Import for PDF generation
import 'package:pdf/widgets.dart' as pw; // Import for PDF widgets
import 'package:printing/printing.dart'; // Import for printing/sharing
import 'package:path_provider/path_provider.dart'; // Import for path provider
import 'dart:io'; // For File operations

class OverseerPage extends StatefulWidget {
  const OverseerPage({super.key});

  @override
  State<OverseerPage> createState() => _OverseerPageState();
}

class _OverseerPageState extends State<OverseerPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Variable to hold logo image bytes for PDF generation
  Uint8List? _logoBytes;

  // Add this variable to hold filtered members for search functionality
  Map<String, dynamic> _filteredMembers = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadLogoBytes();
  }

  // Load logo image bytes from assets
  Future<void> _loadLogoBytes() async {
    try {
      final ByteData bytes = await rootBundle.load(
        'assets/tact_logo.PNG',
      ); // Update path as needed
      setState(() {
        _logoBytes = bytes.buffer.asUint8List();
      });
    } catch (e) {
      // If logo not found or error, just leave _logoBytes as null
      _logoBytes = null;
    }
  }

  final TextEditingController memberNameController = TextEditingController();
  final TextEditingController memberEmailController = TextEditingController();
  final TextEditingController memberAddressController = TextEditingController();
  final TextEditingController memberContactController = TextEditingController();
  final TextEditingController memberSurnameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Overseer Page'), centerTitle: true),
      backgroundColor: color.scaffoldBackgroundColor,
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: color.primaryColor),
              child: Text(
                'Overseer Dashboard',
                style: TextStyle(
                  color: color.scaffoldBackgroundColor,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.home),
              title: Text('Home'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.person),
              title: Text('Help'),
              onTap: () {
                showCupertinoDialog(
                  context: context,
                  builder: (context) {
                    return CupertinoAlertDialog(
                      title: Text('Help'),
                      content: Text('This is the help dialog.'),
                      actions: [
                        CupertinoDialogAction(
                          child: Text('OK'),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Logout'),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: 'Dashboard'),
              Tab(text: 'Add Member'),
              Tab(text: 'All Members'),
              Tab(text: 'Reports'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Dashboard Tab with Graphs
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tithe Offerings (Last 4 Weeks)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 20),
                        Container(
                          height: 300,
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                spreadRadius: 2,
                                blurRadius: 5,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: 5000,
                              barGroups: [
                                BarChartGroupData(
                                  x: 0,
                                  barRods: [
                                    BarChartRodData(
                                      toY: 3000,
                                      color: color.primaryColor,
                                    ),
                                  ],
                                ),
                                BarChartGroupData(
                                  x: 1,
                                  barRods: [
                                    BarChartRodData(
                                      toY: 4500,
                                      color: color.primaryColor,
                                    ),
                                  ],
                                ),
                                BarChartGroupData(
                                  x: 2,
                                  barRods: [
                                    BarChartRodData(
                                      toY: 2500,
                                      color: color.primaryColor,
                                    ),
                                  ],
                                ),
                                BarChartGroupData(
                                  x: 3,
                                  barRods: [
                                    BarChartRodData(
                                      toY: 3800,
                                      color: color.primaryColor,
                                    ),
                                  ],
                                ),
                              ],
                              titlesData: FlTitlesData(
                                show: true,
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      const style = TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      );
                                      Widget text;
                                      switch (value.toInt()) {
                                        case 0:
                                          text = const Text(
                                            'Week 1',
                                            style: style,
                                          );
                                          break;
                                        case 1:
                                          text = const Text(
                                            'Week 2',
                                            style: style,
                                          );
                                          break;
                                        case 2:
                                          text = const Text(
                                            'Week 3',
                                            style: style,
                                          );
                                          break;
                                        case 3:
                                          text = const Text(
                                            'Week 4',
                                            style: style,
                                          );
                                          break;
                                        default:
                                          text = const Text('', style: style);
                                          break;
                                      }
                                      return SideTitleWidget(
                                        space: 4,
                                        meta: meta,
                                        child: text,
                                      );
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      return Text(
                                        '${value.toInt()}',
                                        style: const TextStyle(fontSize: 12),
                                      );
                                    },
                                    interval: 1000,
                                  ),
                                ),
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                drawHorizontalLine: true,
                                getDrawingHorizontalLine: (value) =>
                                    const FlLine(
                                      color: Colors.grey,
                                      strokeWidth: 0.5,
                                    ),
                              ),
                              borderData: FlBorderData(
                                show: true,
                                border: Border.all(
                                  color: Colors.black,
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 30),
                        Text(
                          'Member Growth',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 20),
                        Container(
                          height: 300,
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                spreadRadius: 2,
                                blurRadius: 5,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: LineChart(
                            LineChartData(
                              gridData: FlGridData(show: false),
                              titlesData: FlTitlesData(
                                show: true,
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      const style = TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      );
                                      Widget text;
                                      switch (value.toInt()) {
                                        case 0:
                                          text = const Text(
                                            'Jan',
                                            style: style,
                                          );
                                          break;
                                        case 1:
                                          text = const Text(
                                            'Feb',
                                            style: style,
                                          );
                                          break;
                                        case 2:
                                          text = const Text(
                                            'Mar',
                                            style: style,
                                          );
                                          break;
                                        case 3:
                                          text = const Text(
                                            'Apr',
                                            style: style,
                                          );
                                          break;
                                        case 4:
                                          text = const Text(
                                            'May',
                                            style: style,
                                          );
                                          break;
                                        default:
                                          text = const Text('', style: style);
                                          break;
                                      }
                                      return SideTitleWidget(
                                        space: 4,
                                        meta: meta,
                                        child: text,
                                      );
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      return Text(
                                        '${value.toInt()}',
                                        style: const TextStyle(fontSize: 12),
                                      );
                                    },
                                    interval: 5,
                                  ),
                                ),
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),
                              borderData: FlBorderData(
                                show: true,
                                border: Border.all(
                                  color: Colors.black,
                                  width: 1,
                                ),
                              ),
                              minX: 0,
                              maxX: 4,
                              minY: 0,
                              maxY: 50,
                              lineBarsData: [
                                LineChartBarData(
                                  spots: const [
                                    FlSpot(0, 10),
                                    FlSpot(1, 15),
                                    FlSpot(2, 25),
                                    FlSpot(3, 30),
                                    FlSpot(4, 45),
                                  ],
                                  isCurved: true,
                                  color: color.splashColor,
                                  barWidth: 3,
                                  isStrokeCapRound: true,
                                  dotData: const FlDotData(show: true),
                                  belowBarData: BarAreaData(show: false),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Add Member Tab
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      CupertinoTextField(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18.0),
                          border: Border.all(color: color.primaryColor),
                        ),
                        controller: memberNameController,
                        placeholder: 'Enter Member Name',
                        padding: EdgeInsets.all(16.0),
                        style: TextStyle(fontSize: 18),
                      ),
                      SizedBox(height: 10),
                      CupertinoTextField(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18.0),
                          border: Border.all(color: color.primaryColor),
                        ),
                        controller: memberSurnameController,
                        placeholder: 'Enter Member Surname',
                        padding: EdgeInsets.all(16.0),
                        style: TextStyle(fontSize: 18),
                      ),
                      SizedBox(height: 10),
                      CupertinoTextField(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18.0),
                          border: Border.all(color: color.primaryColor),
                        ),
                        controller: memberEmailController,
                        placeholder: 'Enter Member Email',
                        padding: EdgeInsets.all(16.0),
                      ),
                      SizedBox(height: 10),
                      CupertinoTextField(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18.0),
                          border: Border.all(color: color.primaryColor),
                        ),
                        controller: memberAddressController,
                        placeholder: 'Enter Member Address',
                        padding: EdgeInsets.all(16.0),
                      ),
                      SizedBox(height: 10),
                      CupertinoTextField(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18.0),
                          border: Border.all(color: color.primaryColor),
                        ),
                        controller: memberContactController,
                        placeholder: 'Enter Contact Number',
                        padding: EdgeInsets.all(16.0),
                      ),
                      SizedBox(height: 20),
                      CustomOutlinedButton(
                        onPressed: () async {
                          if (memberNameController.text.isEmpty ||
                              memberSurnameController.text.isEmpty ||
                              memberEmailController.text.isEmpty ||
                              memberAddressController.text.isEmpty ||
                              memberContactController.text.isEmpty) {
                            Api().showMessage(
                              context,
                              'Please fill in all fields',
                              'Error',
                              color.primaryColorDark,
                            );
                            return;
                          }
                          try {
                            FirebaseFirestore firestore =
                                FirebaseFirestore.instance;
                            await firestore.collection('users').add({
                              'name': memberNameController.text,
                              'surname': memberSurnameController.text,
                              'email': memberEmailController.text,
                              'Address': memberAddressController.text,
                              'Contact Number': memberContactController.text,
                              'overseerUid':
                                  FirebaseAuth.instance.currentUser?.uid,
                              'profileUrl': '',
                              'role': 'Member',
                            });
                            Api().showMessage(
                              context,
                              'Member added successfully',
                              'Success',
                              color.splashColor,
                            );
                          } catch (error) {
                            Api().showMessage(
                              context,
                              'Failed to add member: $error',
                              'Error',
                              color.primaryColorDark,
                            );
                          }

                          memberNameController.clear();
                          memberSurnameController.clear();
                          memberEmailController.clear();
                          memberAddressController.clear();
                          memberContactController.clear();
                        },
                        text: 'Add Member',
                        backgroundColor: color.primaryColor,
                        foregroundColor: Colors.white,
                        width: double.infinity,
                      ),
                    ],
                  ),
                ),

                // All Members Tab
                StreamBuilder(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .where(
                        'overseerUid',
                        isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                      )
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(child: Text('No members found.'));
                    }
                    final members = snapshot.data!.docs;
                    return ListView.builder(
                      itemCount: members.length,
                      itemBuilder: (context, index) {
                        final member = members[index];
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              CupertinoTextField(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10.0),
                                  border: Border.all(color: color.primaryColor),
                                ),
                                placeholder: 'Search Members',
                                onChanged: (value) {
                                  //Please implement search functionality
                                  // This is a placeholder for search functionality
                                  // Implement search functionality
                                  final query = value.toLowerCase();
                                  final filteredMembers = members.where((
                                    member,
                                  ) {
                                    return member['name']
                                                .toLowerCase()
                                                .contains(query) ||
                                            member['surname']
                                                ?.toLowerCase()
                                                .contains(query) ??
                                        false;
                                  }).toList();
                                  setState(() {
                                    _filteredMembers = filteredMembers
                                        .asMap()
                                        .map(
                                          (i, member) => MapEntry(
                                            i.toString(),
                                            member.data(),
                                          ),
                                        );
                                  });
                                },
                              ),
                              Card(
                                color: color.scaffoldBackgroundColor
                                    .withOpacity(0.7),
                                elevation: 5,
                                margin: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: ListTile(
                                  leading: Icon(
                                    Icons.person,
                                    color: color.primaryColor,
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${member['name']} ${member['surname'] ?? ''}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: color.primaryColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '${member['email'] ?? 'N/A'}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '${member['Address'] ?? 'N/A'}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '${member['Contact Number'] ?? 'N/A'}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () {
                                      Api().showMessage(
                                        context,
                                        'Edit functionality coming soon!',
                                        'Info',
                                        Colors.blue,
                                      );
                                    },
                                  ),
                                  onTap: () {
                                    Api().showMessage(
                                      context,
                                      'Tapped on ${member['name']}',
                                      'Info',
                                      color.primaryColor,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),

                // Reports Tab
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: StreamBuilder(
                    stream: FirebaseFirestore.instance
                        .collection('overseers')
                        .snapshots(),
                    builder: (context, asyncSnapshot) {
                      var overseerData = asyncSnapshot.data?.docs ?? [];
                      if (asyncSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      }
                      if (overseerData.isEmpty) {
                        return Center(child: Text('No overseers found.'));
                      }
                      var overseer = overseerData.first.data();
                      String overseerName = overseer['name'] ?? 'N/A';
                      String codeNo = overseer['codeNo'] ?? 'N/A';
                      String districtElder = overseer['districtElder'] ?? 'N/A';
                      String communityElder =
                          overseer['communityElder'] ?? 'N/A';
                      String communityName = overseer['communityName'] ?? 'N/A';
                      String region = overseer['region'] ?? 'N/A';
                      String province = overseer['province'] ?? 'N/A';
                      String overseerSurname = overseer['surname'] ?? 'N/A';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Income and Expenditure Statement',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'For the Month: ${DateTime.now().month} Year: ${DateTime.now().year}',
                          ),
                          Text(
                            'Overseer: ${overseerName} ${overseerSurname} Code No: ${codeNo}',
                          ),
                          Text('District Elder: ${districtElder}'),
                          Text('Community Elder: ${communityElder}'),
                          Text('Community Name: ${communityName}'),
                          Text('Province: ${province} Region: ${region}'),
                          SizedBox(height: 20),
                          Divider(),
                          Text(
                            'Income / Receipts',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 10),
                          _buildReportRow('Tithe Offerings - Week 1', 'R', 'c'),
                          _buildReportRow('Tithe Offerings - Week 2', 'R', 'c'),
                          _buildReportRow('Tithe Offerings - Week 3', 'R', 'c'),
                          _buildReportRow('Tithe Offerings - Week 4', 'R', 'c'),
                          _buildReportRow('Others', 'R', 'c'),
                          _buildReportRow('Month End', 'R', 'c'),
                          SizedBox(height: 10),
                          _buildReportRow(
                            'Total Income',
                            'R',
                            'c',
                            isTotal: true,
                          ),
                          SizedBox(height: 20),
                          Divider(),
                          Text(
                            'Expenditure',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 10),
                          _buildReportRow('Rent Period', 'R', 'c'),
                          _buildReportRow('Wine and Priest Wafers', 'R', 'c'),
                          _buildReportRow('Power and Lights', 'R', 'c'),
                          _buildReportRow('Sundries/Repairs', 'R', 'c'),
                          _buildReportRow('Central Council', 'R', 'c'),
                          _buildReportRow('Equipment / General', 'R', 'c'),
                          SizedBox(height: 10),
                          _buildReportRow(
                            'Total Expenditure',
                            'R',
                            'c',
                            isTotal: true,
                          ),
                          SizedBox(height: 20),
                          Divider(),
                          _buildReportRow(
                            'Credit Balance (Amount Banked)',
                            'R',
                            'c',
                            isTotal: true,
                            isCreditBalance: true,
                          ),
                          SizedBox(height: 20),
                          Text('Bank Name: Standard Bank'),
                          Text('Account Name: The TACT'),
                          Text('Account No: 051074958'),
                          Text('Branch Name: Kingsmead'),
                          Text('Branch Code: 040026'),
                          SizedBox(height: 20),
                          Text(
                            'Please write your name and the name of your Community in the Deposit Slip Senders Details Column.',
                          ),
                          SizedBox(height: 30),
                          Text(
                            'Balance Sheet',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text('For the Month of: __________ Year: __________'),
                          Text('Overseer: __________'),
                          Text('District Elder: __________'),
                          Text('Community Elder: __________'),
                          Text('Community Name: __________'),
                          SizedBox(height: 20),
                          Text(
                            'Members Tithe Offerings',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 10),
                          StreamBuilder(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .where(
                                  'overseerUid',
                                  isEqualTo:
                                      FirebaseAuth.instance.currentUser?.uid,
                                )
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return CircularProgressIndicator();
                              }
                              if (snapshot.hasError) {
                                return Text('Error: ${snapshot.error}');
                              }
                              if (!snapshot.hasData ||
                                  snapshot.data!.docs.isEmpty) {
                                return Text('No data available');
                              }
                              var members = snapshot.data!.docs
                                  .map((doc) => doc.data())
                                  .toList();
                              return Column(
                                children: [
                                  _buildBalanceSheetHeader(),
                                  ...members.map((member) {
                                    return _buildBalanceSheetRow(
                                      '${member['name'] ?? 'N/A'} ${member['surname'] ?? ''}',
                                      'R',
                                      'c',
                                      'R',
                                      'c',
                                      'R',
                                      'c',
                                      'R',
                                      'c',
                                      'R',
                                      'c',
                                    );
                                  }).toList(),
                                ],
                              );
                            },
                          ),
                          SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'GRAND TOTAL: R _________ c _________',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(height: 30),
                          Text(
                            'NB: Attach all receipts and Bank Deposit Slips with Neat and Clear Details',
                            style: TextStyle(fontStyle: FontStyle.italic),
                          ),
                          SizedBox(height: 20),
                          Text(
                            'Signatures:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 10),
                          _buildSignatureRow('Overseer'),
                          _buildSignatureRow('Community Elder'),
                          _buildSignatureRow('Secretary'),
                          _buildSignatureRow('District Elder'),
                          _buildSignatureRow('Treasurer'),
                          _buildSignatureRow('Contact Person'),
                          SizedBox(height: 20),
                          Text('Telephone No: __________'),
                          Text('Email Address: __________'),
                          SizedBox(height: 30),
                          CustomOutlinedButton(
                            onPressed: () => _generatePdfAndDownload(),
                            text: 'Download Report as PDF',
                            backgroundColor: color.primaryColor,
                            foregroundColor: Colors.white,
                            width: double.infinity,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper methods (unchanged from previous response) ---
  Widget _buildReportRow(
    String label,
    String rText,
    String cText, {
    bool isTotal = false,
    bool isCreditBalance = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isTotal || isCreditBalance
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$rText _______',
                style: TextStyle(
                  fontWeight: isTotal || isCreditBalance
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$cText _______',
                style: TextStyle(
                  fontWeight: isTotal || isCreditBalance
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceSheetHeader() {
    return Table(
      border: TableBorder.all(color: Colors.grey),
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey[200]),
          children: [
            TableCell(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Members Name and Surname',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            TableCell(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'WEEK 1',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            TableCell(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'WEEK 2',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            TableCell(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'WEEK 3',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            TableCell(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'WEEK 4',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            TableCell(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'MONTHLY',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBalanceSheetRow(
    String name,
    String week1R,
    String week1C,
    String week2R,
    String week2C,
    String week3R,
    String week3C,
    String week4R,
    String week4C,
    String monthlyR,
    String monthlyC,
  ) {
    return Table(
      border: TableBorder.all(color: Colors.grey),
      children: [
        TableRow(
          children: [
            TableCell(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(name),
              ),
            ),
            TableCell(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('$week1R.$week1C'),
              ),
            ),
            TableCell(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('$week2R.$week2C'),
              ),
            ),
            TableCell(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('$week3R.$week3C'),
              ),
            ),
            TableCell(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('$week4R.$week4C'),
              ),
            ),
            TableCell(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('$monthlyR.$monthlyC'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSignatureRow(String role) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('$role:')),
          Expanded(flex: 3, child: Text('_________________________')),
          SizedBox(width: 10),
          Expanded(flex: 1, child: Text('Signature:')),
          Expanded(flex: 3, child: Text('_________________________')),
        ],
      ),
    );
  }

  // --- PDF Generation Logic ---
  Future<void> _generatePdfAndDownload() async {
    final pdf = pw.Document();

    // Await the balance sheet table widget before building the PDF
    final balanceSheetTable = await _buildPdfBalanceSheetTable();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            if (_logoBytes != null)
              pw.Image(pw.MemoryImage(_logoBytes!), width: 100, height: 100),
            pw.Center(
              child: pw.Text(
                'The Twelve Apostles Church in Trinity',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Center(child: pw.Text('P. O. Box 40376, Red Hill, 4071')),
            pw.Center(child: pw.Text('Tel./Fax No\'s: (031) 569 6164')),
            pw.Center(child: pw.Text('Email: thetacc@telkomsa.net')),
            pw.SizedBox(height: 30),
            pw.Text(
              'Income and Expenditure Statement',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            _buildPdfTextRow(
              'For the Month:',
              '${DateTime.now().month}',
              'Year:',
              '${DateTime.now().year}',
            ),
            _buildPdfTextRow('Overseer:', '', 'Code No:', '__________'),
            _buildPdfTextRow('District Elder:', '__________'),
            _buildPdfTextRow('Community Elder:', '__________'),
            _buildPdfTextRow('Community Name:', '__________'),
            _buildPdfTextRow('Province: Gauteng', '', 'Region:', '__________'),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.Text(
              'Income / Receipts',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
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
            pw.Text(
              'Expenditure',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
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
            _buildPdfReportRow(
              'Credit Balance (Amount Banked)',
              'R',
              'c',
              isTotal: true,
              isCreditBalance: true,
            ),
            pw.SizedBox(height: 20),
            pw.Text('Bank Name: Standard Bank'),
            pw.Text('Account Name: The TACT'),
            pw.Text('Account No: 051074958'),
            pw.Text('Branch Name: Kingsmead'),
            pw.Text('Branch Code: 040026'),
            pw.SizedBox(height: 20),
            pw.Text(
              'Please write your name and the name of your Community in the Deposit Slip Senders Details Column.',
            ),
            pw.SizedBox(height: 30),
            pw.Text(
              'Balance Sheet',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            _buildPdfTextRow(
              'For the Month of:',
              '__________',
              'Year:',
              '__________',
            ),
            _buildPdfTextRow('Overseer:', '__________'),
            _buildPdfTextRow('District Elder:', '__________'),
            _buildPdfTextRow('Community Elder:', '__________'),
            _buildPdfTextRow('Community Name:', '__________'),
            pw.SizedBox(height: 20),
            pw.Text(
              'Members Tithe Offerings',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            // Insert the awaited balance sheet table here
            balanceSheetTable,
            pw.SizedBox(height: 10),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'GRAND TOTAL: R _________ c _________',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 30),
            pw.Text(
              'NB: Attach all receipts and Bank Deposit Slips with Neat and Clear Details',
              style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Signatures:',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            _buildPdfSignatureRow('Overseer'),
            _buildPdfSignatureRow('Community Elder'),
            _buildPdfSignatureRow('Secretary'),
            _buildPdfSignatureRow('District Elder'),
            _buildPdfSignatureRow('Treasurer'),
            _buildPdfSignatureRow('Contact Person'),
            pw.SizedBox(height: 20),
            pw.Text('Telephone No: __________'),
            pw.Text('Email Address: __________'),
          ];
        },
      ),
    );

    // Get the application's temporary directory
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/church_report.pdf');
    await file.writeAsBytes(await pdf.save());

    // Use the printing package to share or open the PDF
    await Printing.sharePdf(
      bytes: await file.readAsBytes(),
      filename: 'church_report(${DateTime.now().toIso8601String()}).pdf',
    );

    Api().showMessage(
      context,
      'Report generated and ready to share!',
      'Success',
      Theme.of(context).splashColor,
    );
  }

  // Helper for PDF text rows (e.g., "For the Month: ___ Year: ___")
  pw.Widget _buildPdfTextRow(
    String label1,
    String value1, [
    String? label2,
    String? value2,
  ]) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('$label1 $value1'),
        if (label2 != null && value2 != null) pw.Text('$label2 $value2'),
      ],
    );
  }

  // Helper for PDF report rows (income/expenditure)
  pw.Widget _buildPdfReportRow(
    String label,
    String rText,
    String cText, {
    bool isTotal = false,
    bool isCreditBalance = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.0),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontWeight: isTotal || isCreditBalance
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
              ),
            ),
          ),
          pw.Expanded(
            flex: 1,
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                '$rText _______',
                style: pw.TextStyle(
                  fontWeight: isTotal || isCreditBalance
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                ),
              ),
            ),
          ),
          pw.Expanded(
            flex: 1,
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                '$cText _______',
                style: pw.TextStyle(
                  fontWeight: isTotal || isCreditBalance
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper for PDF Balance Sheet Table
  Future<pw.Widget> _buildPdfBalanceSheetTable() async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    var overseerData = await firestore
        .collection('users')
        .where('overseerUid', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
        .get();
    if (overseerData.docs.isEmpty) {
      Api().showMessage(
        context,
        'No overseer data found for the current user.',
        'Error',
        Theme.of(context).primaryColorDark,
      );
      return pw.Text('No member data found.');
    }
    var member = overseerData.docs.first.data();
    String memberName = member['name'] ?? 'N/A';
    String memberSurname = member['surname'] ?? 'N/A';
    String memberWeek1 = member['week1']?.toString() ?? '0.00';
    String memberWeek2 = member['week2']?.toString() ?? '0.00';
    String memberWeek3 = member['week3']?.toString() ?? '0.00';
    String memberWeek4 = member['week4']?.toString() ?? '0.00';
    return pw.TableHelper.fromTextArray(
      cellAlignment: pw.Alignment.centerLeft,
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      cellPadding: const pw.EdgeInsets.all(8),
      data: <List<String>>[
        <String>[
          'Members Name and Surname',
          'WEEK 1',
          'WEEK 2',
          'WEEK 3',
          'WEEK 4',
          'MONTHLY',
        ],

        <String>[
          '${memberName} ${memberSurname}',
          'R ${memberWeek1.split('.')[0]} c ${memberWeek1.split('.')[1]}',
          'R ${memberWeek2.split('.')[0]} c ${memberWeek2.split('.')[1]}',
          'R ${memberWeek3.split('.')[0]} c ${memberWeek3.split('.')[1]}',
          'R ${memberWeek4.split('.')[0]} c ${memberWeek4.split('.')[1]}',
          'R ${(double.parse(memberWeek1) + double.parse(memberWeek2) + double.parse(memberWeek3) + double.parse(memberWeek4)).toStringAsFixed(2)}',
        ],
      ],
    );
  }

  // Helper for PDF signature rows
  pw.Widget _buildPdfSignatureRow(String role) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4.0),
      child: pw.Row(
        children: [
          pw.Expanded(flex: 2, child: pw.Text('$role:')),
          pw.Expanded(flex: 3, child: pw.Text('_________________________')),
          pw.SizedBox(width: 10),
          pw.Expanded(flex: 1, child: pw.Text('Signature:')),
          pw.Expanded(flex: 3, child: pw.Text('_________________________')),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    memberNameController.dispose();
    memberSurnameController.dispose();
    memberEmailController.dispose();
    memberAddressController.dispose();
    memberContactController.dispose();
    super.dispose();
  }
}
