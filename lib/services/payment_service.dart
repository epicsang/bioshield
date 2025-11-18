// lib/services/payment_service.dart
// Payment Service - Handles premium subscription upgrades using Stripe Payment Links

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

/// Subscription plans
enum SubscriptionPlan {
  free,
  monthly,
  yearly,
}

/// Subscription status
enum SubscriptionStatus {
  active,
  expired,
  cancelled,
  pending,
}

/// Payment result
class PaymentResult {
  final bool success;
  final String? transactionId;
  final String? errorMessage;

  PaymentResult.success(this.transactionId)
      : success = true,
        errorMessage = null;

  PaymentResult.error(this.errorMessage)
      : success = false,
        transactionId = null;
}

/// Subscription details
class Subscription {
  final SubscriptionPlan plan;
  final SubscriptionStatus status;
  final DateTime? startDate;
  final DateTime? endDate;
  final double price;

  Subscription({
    required this.plan,
    required this.status,
    this.startDate,
    this.endDate,
    required this.price,
  });

  factory Subscription.fromMap(Map<String, dynamic> map) {
    return Subscription(
      plan: SubscriptionPlan.values.firstWhere(
        (e) => e.toString() == 'SubscriptionPlan.${map['plan']}',
        orElse: () => SubscriptionPlan.free,
      ),
      status: SubscriptionStatus.values.firstWhere(
        (e) => e.toString() == 'SubscriptionStatus.${map['status']}',
        orElse: () => SubscriptionStatus.expired,
      ),
      startDate: map['startDate'] != null
          ? (map['startDate'] as Timestamp).toDate()
          : null,
      endDate: map['endDate'] != null
          ? (map['endDate'] as Timestamp).toDate()
          : null,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'plan': plan.toString().split('.').last,
      'status': status.toString().split('.').last,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'price': price,
    };
  }

  bool get isActive {
    if (status != SubscriptionStatus.active) return false;
    if (endDate == null) return true;
    return DateTime.now().isBefore(endDate!);
  }
}

/// Payment Service using Stripe Payment Links
///
/// This implementation uses Stripe's pre-generated Payment Links for security:
///
/// Benefits:
/// - ✅ No secret keys in client code
/// - ✅ No backend/Cloud Functions required
/// - ✅ Zero infrastructure cost
/// - ✅ PCI-compliant by default
/// - ✅ Automatic tax calculation
/// - ✅ Multiple payment methods supported
///
/// Setup Instructions:
/// 1. Go to https://dashboard.stripe.com/payment-links
/// 2. Click "Create payment link"
/// 3. Configure your product (Monthly or Yearly)
/// 4. Copy the generated URL
/// 5. Replace the placeholder URLs below
class PaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ✨ STRIPE PAYMENT LINKS
  // Generated from: https://dashboard.stripe.com/payment-links
  static const String MONTHLY_PAYMENT_LINK = 'https://buy.stripe.com/test_fZu7sE2ly5s4awuelA53O01';
  static const String YEARLY_PAYMENT_LINK = 'https://buy.stripe.com/test_3cI6oAd0c7Ac7ki1yO53O00';

  // Pricing (in USD)
  static const double MONTHLY_PRICE = 19.99;
  static const double YEARLY_PRICE = 199.99;

  /// Get current subscription
  Future<Subscription> getCurrentSubscription() async {
    final user = _auth.currentUser;
    if (user == null) {
      return Subscription(
        plan: SubscriptionPlan.free,
        status: SubscriptionStatus.expired,
        price: 0.0,
      );
    }

    final doc = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('subscription')
        .doc('current')
        .get();

    if (!doc.exists) {
      return Subscription(
        plan: SubscriptionPlan.free,
        status: SubscriptionStatus.expired,
        price: 0.0,
      );
    }

    return Subscription.fromMap(doc.data()!);
  }

  /// Open Stripe Payment Link for subscription purchase
  ///
  /// This opens the Stripe-hosted payment page in the user's browser.
  /// After successful payment, Stripe can:
  /// 1. Redirect back to your app (configure in Stripe Dashboard)
  /// 2. Send webhook events to your server (for auto-activation)
  Future<PaymentResult> openPaymentLink({
    required SubscriptionPlan plan,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return PaymentResult.error('User not authenticated');
      }

      // Get the appropriate payment link
      final paymentLink = plan == SubscriptionPlan.monthly
          ? MONTHLY_PAYMENT_LINK
          : YEARLY_PAYMENT_LINK;

      // Add user ID as URL parameter for tracking
      final urlWithParams = Uri.parse(paymentLink).replace(
        queryParameters: {
          'client_reference_id': user.uid,
          'prefilled_email': user.email ?? '',
        },
      );

      // Open the Stripe payment page
      if (await canLaunchUrl(urlWithParams)) {
        await launchUrl(
          urlWithParams,
          mode: LaunchMode.externalApplication,
        );

        // Mark as pending in database
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('subscription')
            .doc('current')
            .set({
          'plan': plan.toString().split('.').last,
          'status': SubscriptionStatus.pending.toString().split('.').last,
          'price': plan == SubscriptionPlan.monthly ? MONTHLY_PRICE : YEARLY_PRICE,
          'initiatedAt': FieldValue.serverTimestamp(),
        }, SetDocumentOptions(merge: true));

        print('✅ Payment link opened successfully');
        return PaymentResult.success('pending');
      } else {
        return PaymentResult.error('Could not open payment page');
      }
    } catch (e) {
      print('❌ Payment link error: $e');
      return PaymentResult.error(e.toString());
    }
  }

  /// Legacy method for backward compatibility
  Future<PaymentResult> processPayment({
    required SubscriptionPlan plan,
    required String paymentMethod,
  }) async {
    return openPaymentLink(plan: plan);
  }

  /// Cancel subscription
  Future<bool> cancelSubscription() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Update subscription status
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('subscription')
          .doc('current')
          .update({
        'status': SubscriptionStatus.cancelled.toString().split('.').last,
      });

      // Update user isPremium status
      await _firestore.collection('users').doc(user.uid).update({
        'isPremium': false,
      });

      print('✅ Subscription cancelled');
      return true;
    } catch (e) {
      print('❌ Cancellation error: $e');
      return false;
    }
  }

  /// Check if subscription needs renewal
  Future<bool> needsRenewal() async {
    final subscription = await getCurrentSubscription();

    if (!subscription.isActive) return true;
    if (subscription.endDate == null) return false;

    // Needs renewal if less than 7 days remaining
    final daysRemaining = subscription.endDate!.difference(DateTime.now()).inDays;
    return daysRemaining < 7;
  }

  /// Get transaction history
  Future<List<Map<String, dynamic>>> getTransactionHistory() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('transactions')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  /// Get pricing for plan
  static double getPricing(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.monthly:
        return MONTHLY_PRICE;
      case SubscriptionPlan.yearly:
        return YEARLY_PRICE;
      case SubscriptionPlan.free:
        return 0.0;
    }
  }

  /// Calculate savings for yearly plan
  static double getYearlySavings() {
    return (MONTHLY_PRICE * 12) - YEARLY_PRICE;
  }
}

/*
═══════════════════════════════════════════════════════════════════
STRIPE PAYMENT LINKS SETUP GUIDE
═══════════════════════════════════════════════════════════════════

Step 1: Create Payment Links in Stripe Dashboard
-------------------------------------------------
1. Go to: https://dashboard.stripe.com/payment-links
2. Click "Create payment link"
3. Fill in product details:
   - Name: "BioShield Monthly Premium"
   - Price: $9.99 (or your pricing)
   - Billing: Recurring monthly
4. Click "Create link"
5. Copy the generated URL (e.g., https://buy.stripe.com/test_XXXXX)
6. Repeat for yearly plan

Step 2: Configure Success/Cancel URLs (Optional)
------------------------------------------------
1. In each payment link settings:
   - Success URL: your-app-scheme://payment-success
   - Cancel URL: your-app-scheme://payment-cancel
2. This allows returning to app after payment

Step 3: Set up Webhooks (For Auto-Activation)
---------------------------------------------
1. Go to: https://dashboard.stripe.com/webhooks
2. Add endpoint: https://your-backend.com/stripe-webhook
3. Listen for events:
   - checkout.session.completed
   - customer.subscription.created
   - customer.subscription.deleted
4. Use client_reference_id to identify user

Step 4: Replace URLs in Code
----------------------------
Replace MONTHLY_PAYMENT_LINK and YEARLY_PAYMENT_LINK above
with your actual Stripe Payment Link URLs

═══════════════════════════════════════════════════════════════════
ADVANTAGES OF THIS APPROACH:
═══════════════════════════════════════════════════════════════════

✅ Security:
   - No secret keys in client code
   - PCI-compliant by default
   - Stripe handles all payment data

✅ Zero Backend Required:
   - No Cloud Functions needed
   - No server infrastructure
   - Zero maintenance

✅ Full Stripe Features:
   - Multiple payment methods (card, Apple Pay, Google Pay)
   - Automatic tax calculation
   - Invoice generation
   - Email receipts
   - Subscription management

✅ Cost Effective:
   - Only pay Stripe's standard fees (2.9% + 30¢)
   - No additional backend hosting costs

═══════════════════════════════════════════════════════════════════
*/
