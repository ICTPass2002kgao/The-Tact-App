import 'package:flutter/material.dart';
import 'package:ttact/Components/paystack_service.dart';

class SubscriptionPlansScreen extends StatelessWidget {
  final String?
  requiredPlanCode; // The plan the user MUST upgrade to. Null means Free Tier.
  final Function(String planCode) onSubscribe; // Callback for button press

  const SubscriptionPlansScreen({
    super.key,
    required this.requiredPlanCode,
    required this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    // Determine if the user is currently on the Free Tier (i.e., no upgrade required)
    final isFreeTierActive = requiredPlanCode == null;
    final color = Theme.of(context);
    return Dialog(
      backgroundColor: color.primaryColor,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: isDesktop
            ? 1200
            : double.infinity, // Increased width to fit 4 cards
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F7FA),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- Header ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Subscription Plans',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // --- Body ---
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Text(
                      'Choose Your Plan',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3E50),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      requiredPlanCode != null
                          ? 'You have exceeded the free tier limit. Please upgrade to continue.'
                          : 'You are currently on the Free Tier.',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),

                    Wrap(
                      spacing: 20,
                      runSpacing: 20,
                      alignment: WrapAlignment.center,
                      children: [
                        // --- FREE TIER CARD ---
                        _buildPlanCard(
                          context: context,
                          planCode: 'free_tier',
                          title: 'Free Tier',
                          memberRange: '0 - 49 Members',
                          price: 'Free',
                          features: [
                            'Standard generation of balance sheet for up to 49 members',
                          ],
                          // It is "Recommended/Active" if requiredPlanCode is null
                          isRecommended: isFreeTierActive,
                          // If they need to upgrade, this card is disabled/greyed out
                          isDisabled: !isFreeTierActive,
                          buttonColor: Colors.grey,
                        ),

                        // --- TIER 1 ---
                        _buildPlanCard(
                          context: context,
                          planCode: PaystackService.planTier1,
                          title: 'Tier 1',
                          memberRange: '50 - 299 Members',
                          price: 'R189',
                          features: [
                            'Generate a balance sheet of 50-299 members',
                          ],
                          isRecommended:
                              requiredPlanCode == PaystackService.planTier1,
                          buttonColor: const Color(0xFF00C853), // Green
                        ),

                        // --- TIER 2 ---
                        _buildPlanCard(
                          context: context,
                          planCode: PaystackService.planTier2,
                          title: 'Tier 2',
                          memberRange: '300 - 499 Members',
                          price: 'R349',
                          features: [
                            'Generate a balance sheet of 300-499 members',
                          ],
                          isRecommended:
                              requiredPlanCode == PaystackService.planTier2,
                          buttonColor: const Color(0xFF2962FF), // Blue
                        ),

                        // --- TIER 3 ---
                        _buildPlanCard(
                          context: context,
                          planCode: PaystackService.planTier3,
                          title: 'Tier 3',
                          memberRange: '500+ Members',
                          price: 'R489',
                          features: [
                            'Generate a balance sheet of 500+ members',
                          ],
                          isRecommended:
                              requiredPlanCode == PaystackService.planTier3,
                          buttonColor: const Color(0xFF6200EA), // Purple
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required BuildContext context,
    required String planCode,
    required String title,
    required String memberRange,
    required String price,
    required List<String> features,
    required bool isRecommended,
    required Color buttonColor,
    bool isDisabled = false,
  }) {
    // Determine Button Text based on state
    String buttonText = 'Choose Plan';
    if (planCode == 'free_tier') {
      buttonText = isRecommended ? 'Current Plan' : 'Limit Exceeded';
    } else if (isRecommended) {
      buttonText = 'Subscribe Now';
    }

    // If it's the active free tier, we don't need an action (it's already active)
    final bool isActionable = !isDisabled && planCode != 'free_tier';

    return Stack(
      children: [
        Container(
          width: 280, // Slightly narrower to fit 4 on large screens
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: isDisabled ? Colors.grey[50] : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isRecommended
                ? Border.all(color: buttonColor, width: 2)
                : Border.all(color: Colors.grey.shade200),
            boxShadow: isDisabled
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Opacity(
            opacity: isDisabled ? 0.6 : 1.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDisabled ? Colors.grey : buttonColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  memberRange,
                  style: TextStyle(
                    fontSize: 14, // Slightly smaller
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      price,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: isDisabled
                            ? Colors.grey
                            : const Color(0xFF2D3E50),
                      ),
                    ),
                    if (price != 'Free')
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0, left: 4.0),
                        child: Text(
                          '/month',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Divider(color: Colors.grey.shade200),
                const SizedBox(height: 24),
                ...features.map(
                  (feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: isDisabled ? Colors.grey : buttonColor,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            feature,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDisabled
                                  ? Colors.grey
                                  : const Color(0xFF455A64),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton(
                    onPressed: isActionable
                        ? () => onSubscribe(planCode)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      disabledBackgroundColor:
                          planCode == 'free_tier' && isRecommended
                          ? Colors
                                .green
                                .shade50 // Active state background
                          : Colors.grey.shade200,
                      foregroundColor: Colors.white,
                      disabledForegroundColor:
                          planCode == 'free_tier' && isRecommended
                          ? Colors
                                .green // Active state text
                          : Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      buttonText,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isRecommended)
          Positioned(
            top: 0,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: buttonColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Text(
                planCode == 'free_tier' ? 'Active' : 'Required',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
