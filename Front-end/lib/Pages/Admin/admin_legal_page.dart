import 'dart:convert'; // For JSON encoding
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart'
    as http; // Make sure to add http to pubspec.yaml
import 'package:ttact/Components/NeuDesign.dart';

class AdminLegalBroadcastPage extends StatefulWidget {
  final String? uid;
  final String? portfolio;
  final String? fullName;
  final String? province;
  const AdminLegalBroadcastPage({super.key, this.uid, this.portfolio, this.fullName, this.province});

  @override
  State<AdminLegalBroadcastPage> createState() =>
      _AdminLegalBroadcastPageState();
}

class _AdminLegalBroadcastPageState extends State<AdminLegalBroadcastPage> {
  // State variables for switches
  bool _includeTerms = false;
  bool _includePolicy = false;
  bool _isSending = false;

  // Stats
  int _totalUsers = 0;

  @override
  void initState() {
    super.initState();
    _fetchUserCount();
  }

  // Get count just for display purposes
  Future<void> _fetchUserCount() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .count()
          .get();
      if (mounted) {
        setState(() {
          _totalUsers = snapshot.count ?? 0;
        });
      }
    } catch (e) {
      debugPrint("Error fetching count: $e");
    }
  }

  // --- THE NEW SENDING LOGIC (VIA DJANGO API) ---
  Future<void> _sendBulkEmails() async {
    // 1. Validation
    if (!_includeTerms && !_includePolicy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select at least one document to send."),
        ),
      );
      return;
    }

    // 2. Alert Dialog
    bool confirm =
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Theme.of(ctx).scaffoldBackgroundColor,
            title: const Text("Confirm Broadcast"),
            content: Text(
              "Are you sure you want to broadcast this legal update to all $_totalUsers users?\n\nThe server will process the emails in the background.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  "SEND NOW",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    setState(() {
      _isSending = true;
    });

    // 3. Call the Django API
    try {
      final url = Uri.parse("https://tact-api.up.railway.app/send-email/");

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "includeTerms": _includeTerms,
          "includePolicy": _includePolicy,
        }),
      );

      if (response.statusCode == 200) {
        // Success
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Broadcast started! Emails are being sent in the background.",
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Server Error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Failed: ${response.statusCode} - ${response.body}",
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Network Error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Connection Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color baseColor = theme.scaffoldBackgroundColor;

    // Neumorphic text style
    TextStyle headerStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: isDark ? Colors.white70 : Colors.black87,
    );

    return Scaffold(
      backgroundColor: baseColor,
      appBar: AppBar(
        title: const Text("Legal Broadcast"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // --- HEADER INFO CARD ---
            NeumorphicContainer(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.mark_email_unread_rounded,
                      size: 50,
                      color: theme.primaryColor,
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      "Total Recipients",
                      style: TextStyle(color: Colors.grey),
                    ),
                    Text(
                      "$_totalUsers Users",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Select the documents updated below to notify all users via email.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // --- SWITCH CONTROLS ---
            Text("Select Content", style: headerStyle),
            const SizedBox(height: 15),

            _buildNeuSwitch(
              title: "Terms & Conditions",
              subtitle: "Include update link for T&Cs",
              value: _includeTerms,
              onChanged: (val) => setState(() => _includeTerms = val),
              isDark: isDark,
            ),

            const SizedBox(height: 15),

            _buildNeuSwitch(
              title: "Privacy Policy",
              subtitle: "Include update link for Policy",
              value: _includePolicy,
              onChanged: (val) => setState(() => _includePolicy = val),
              isDark: isDark,
            ),

            const SizedBox(height: 40),

            // --- ACTION BUTTON ---
            _isSending
                ? const CircularProgressIndicator()
                : NeuButton(
                    onTap: _sendBulkEmails,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      child: const Center(
                        child: Text(
                          "BROADCAST UPDATE",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  // Helper widget for Neumorphic Switch row
  Widget _buildNeuSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required bool isDark,
  }) {
    return NeumorphicContainer(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: Colors.green,
            ),
          ],
        ),
      ),
    );
  }
}
