import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ttact/Components/API.dart';

class AdminVerifySeller extends StatefulWidget {
  const AdminVerifySeller({super.key});

  @override
  State<AdminVerifySeller> createState() => _AdminVerifySellerState();
}

class _AdminVerifySellerState extends State<AdminVerifySeller> {
  // --- This is the function that approves the seller ---
  // (This function remains unchanged)
  Future<void> _approveSeller(String userId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'accountVerified': true,
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seller approved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to approve seller: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- This shows a confirmation dialog before approving ---
  // (This function remains unchanged)
  void _showApprovalDialog(BuildContext context, DocumentSnapshot userDoc) {
    final data = userDoc.data() as Map<String, dynamic>;

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Approve Seller'),
          content: Text(
            'Are you sure you want to approve ${data['name'] ?? 'this user'}?',
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(ctx).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Approve'),
              onPressed: () {
                // Call the approve function

                _approveSeller(userDoc.id);
                Api().sendEmail(
                  data['email'] ?? '', // recipient: the seller
                  "✅ Account Approved – You Can Start Selling!",
                  """
  <p>Dear ${data['name']} ${data['surname']},</p>

  <p>🎉 Congratulations! Your seller account on <strong>Dankie Mobile (TACT)</strong> has been approved.</p>
  <p>🛒 You can now log in and start listing your products for sale on our platform.</p>
  <p>❗ If you encounter any issues or have questions, please contact our support team immediately.</p>

  <br>
  <p>Best regards,<br>
  🙏 Dankie Mobile Support Team</p>
  <a href="https://dankie-website.web.app/">🌐 Dankie Mobile</a>
  """,
                  context,
                );

                Navigator.of(ctx).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // ⭐️ ADDED: A helper widget to build info rows in the bottom sheet
  Widget _buildInfoRow(IconData icon, String label, dynamic value) {
    final String displayValue = (value == null || value.toString().isEmpty)
        ? 'Not Provided'
        : value.toString();
    final Color primaryColor = Theme.of(context).primaryColor;

    return ListTile(
      leading: Icon(icon, color: primaryColor),
      title: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600]),
      ),
      subtitle: Text(
        displayValue,
        style: TextStyle(fontSize: 16, color: Colors.black87),
      ),
    );
  }

  // ⭐️ ADDED: The new bottom sheet to show all seller details
  void _showSellerDetailsSheet(BuildContext context, DocumentSnapshot userDoc) {
    final data = userDoc.data() as Map<String, dynamic>;
    final String? profile = data['profileUrl'];
    final String fullName =
        '${data['name'] ?? 'N/A'} ${data['surname'] ?? 'N/A'}';
    final String email = data['email'] ?? 'No Email';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows the sheet to be taller
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header: Profile Picture and Name
              CircleAvatar(
                radius: 40,
                backgroundColor: Theme.of(
                  context,
                ).primaryColor.withOpacity(0.1),
                child: (profile != null && profile.isNotEmpty)
                    ? ClipOval(
                        child: Image.network(
                          profile,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.person,
                              size: 40,
                              color: Theme.of(context).primaryColor,
                            );
                          },
                        ),
                      )
                    : Icon(
                        Icons.person,
                        size: 40,
                        color: Theme.of(context).primaryColor,
                      ),
              ),
              const SizedBox(height: 12),
              Text(
                fullName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              Text(
                email,
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              const Divider(),

              // Details Section
              _buildInfoRow(Icons.phone, 'Phone Number', data['phone']),
              _buildInfoRow(
                Icons.location_on_outlined,
                'Address',
                data['address'],
              ),
              _buildInfoRow(Icons.badge_outlined, 'Role', data['role']),
              _buildInfoRow(
                Icons.account_balance,
                'Paystack Account',
                data['sellerPaystackAccount'],
              ),
              const SizedBox(height: 24),

              // Action Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  // 1. Close this bottom sheet
                  Navigator.of(ctx).pop();
                  // 2. Open the final confirmation dialog
                  _showApprovalDialog(context, userDoc);
                },
                child: const Text(
                  'Approve Seller',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where("accountVerified", isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).primaryColor,
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No unverified sellers available.'));
        }

        final unverifiedSellers = snapshot.data!.docs;

        return ListView.builder(
          itemCount: unverifiedSellers.length,
          itemBuilder: (context, index) {
            final doc = unverifiedSellers[index];
            final data = doc.data() as Map<String, dynamic>;
            String? profile = data['profileUrl'];

            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 4.0,
              ),
              child: Card(
                elevation: 3,
                child: ListTile(
                  // ⭐️ CHANGED: Added onTap to the whole tile
                  onTap: () {
                    _showSellerDetailsSheet(context, doc);
                  },
                  title: Text(
                    '${data['name'] ?? 'N/A'} ${data['surname'] ?? 'N/A'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(data['email'] ?? 'No Email'),
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundColor: Theme.of(
                      context,
                    ).primaryColor.withOpacity(0.1),
                    child: (profile != null && profile.isNotEmpty)
                        ? ClipOval(
                            child: Image.network(
                              profile,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.person,
                                  color: Theme.of(context).primaryColor,
                                );
                              },
                            ),
                          )
                        : Icon(
                            Icons.person,
                            color: Theme.of(context).primaryColor,
                          ),
                  ),
                  // ⭐️ CHANGED: Replaced button with a "Review" button
                  trailing: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30.0),
                    child: TextButton(
                      onPressed: () {
                        _showSellerDetailsSheet(context, doc);
                      },
                      child: Text(
                        'Review',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
