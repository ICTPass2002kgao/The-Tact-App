import 'package:flutter/material.dart';

class PaymentGatewayPage extends StatelessWidget {
  const PaymentGatewayPage({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: color.primaryColor,
        foregroundColor: color.scaffoldBackgroundColor,
        title: const Text('Payment Options'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose Your Payment Method',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            PaymentOptionCard(
              icon: Icons.credit_card,
              title: 'Credit/Debit Card',
              subtitle: 'Pay securely using your bank card.',
              onTap: () {
                // Navigate or trigger card payment logic
              },
            ),
            PaymentOptionCard(
              icon: Icons.account_balance_wallet,
              title: 'Mobile Wallet',
              subtitle: 'Google Pay, Apple Pay, Samsung Pay',
              onTap: () {
                // Navigate or trigger mobile wallet payment
              },
            ),
            PaymentOptionCard(
              icon: Icons.paypal,
              title: 'PayPal',
              subtitle: 'Use your PayPal account to complete payment.',
              onTap: () {
                // Navigate or trigger PayPal payment
              },
            ),
            PaymentOptionCard(
              icon: Icons.qr_code,
              title: 'Scan to Pay (QR Code)',
              subtitle: 'Scan with your banking app to pay.',
              onTap: () {
                // Navigate or display QR
              },
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Redirecting to payment gateway...')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: color.primaryColor,
                foregroundColor: color.scaffoldBackgroundColor,
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('Continue to Payment'),
            )
          ],
        ),
      ),
    );
  }
}

class PaymentOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const PaymentOptionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(icon, size: 32, color: Theme.of(context).primaryColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 18),
        onTap: onTap,
      ),
    );
  }
}
