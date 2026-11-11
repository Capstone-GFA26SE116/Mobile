import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../data/profile_repository.dart';
import '../models/profile_models.dart';

class PaymentCheckoutSheet extends StatefulWidget {
  final CheckoutResultModel checkout;
  final SubscriptionPlanItem plan;
  final VoidCallback onPaymentSuccess;

  const PaymentCheckoutSheet({
    super.key,
    required this.checkout,
    required this.plan,
    required this.onPaymentSuccess,
  });

  @override
  State<PaymentCheckoutSheet> createState() => _PaymentCheckoutSheetState();
}

class _PaymentCheckoutSheetState extends State<PaymentCheckoutSheet> {
  final ProfileRepository _repository = ProfileRepository();
  bool _isSyncing = false;
  String? _syncMessage;
  bool _syncError = false;

  String _formatVnd(int amount) {
    if (amount == 0) return 'Free';
    final str = amount.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return '${buffer.toString()} VND';
  }

  Future<void> _openPayOsCheckout() async {
    final url = widget.checkout.checkoutUrl;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PayOS payment checkout link not found.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open link: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _checkPaymentStatus() async {
    setState(() {
      _isSyncing = true;
      _syncMessage = null;
      _syncError = false;
    });

    try {
      final syncResult = await _repository.syncPayment(widget.checkout.paymentId);

      if (!mounted) return;

      if (syncResult.isSucceeded) {
        setState(() {
          _isSyncing = false;
          _syncMessage = 'Payment succeeded! Your subscription plan is now active.';
          _syncError = false;
        });

        // Show celebration alert
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(24),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.primary,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Payment Successful!',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your account has been upgraded to ${widget.plan.name}.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context); // Close checkout sheet
                      widget.onPaymentSuccess();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Start Using Plan',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (syncResult.isPending) {
        setState(() {
          _isSyncing = false;
          _syncMessage =
              'PayOS has not confirmed payment yet. Please complete the transfer or retry in a few moments.';
          _syncError = true;
        });
      } else if (syncResult.isCancelled) {
        setState(() {
          _isSyncing = false;
          _syncMessage = 'This transaction has been cancelled.';
          _syncError = true;
        });
      } else if (syncResult.isExpired) {
        setState(() {
          _isSyncing = false;
          _syncMessage = 'Payment checkout link has expired. Please create a new checkout.';
          _syncError = true;
        });
      } else {
        setState(() {
          _isSyncing = false;
          _syncMessage = 'Transaction status: ${syncResult.status}';
          _syncError = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _syncMessage = e.toString().replaceAll('Exception: ', '');
          _syncError = true;
        });
      }
    }
  }

  void _copyOrderCode() {
    Clipboard.setData(ClipboardData(text: widget.checkout.orderCode.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Order code copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.qr_code_2_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PayOS Payment Gateway',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Scan VietQR or pay online via PayOS',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Bill info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Subscription Plan',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      Text(
                        widget.plan.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: AppColors.surfaceBorder, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Order Code',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      InkWell(
                        onTap: _copyOrderCode,
                        borderRadius: BorderRadius.circular(6),
                        child: Row(
                          children: [
                            Text(
                              '#${widget.checkout.orderCode}',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.copy_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: AppColors.surfaceBorder, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Payment Amount',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      Text(
                        _formatVnd(widget.plan.priceVnd),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // PayOS QR Guide Notice
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1B231F),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(
                    Icons.security_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tap "Open PayOS Gateway" to open your banking app or scan the QR code. Once transfer is completed, tap "Verify Payment" below.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Feedback Message
            if (_syncMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _syncError
                      ? Colors.redAccent.withValues(alpha: 0.15)
                      : AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _syncError
                        ? Colors.redAccent.withValues(alpha: 0.4)
                        : AppColors.primary.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _syncError ? Icons.info_outline : Icons.check_circle_outline,
                      color: _syncError ? Colors.redAccent : AppColors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _syncMessage!,
                        style: TextStyle(
                          color: _syncError ? Colors.redAccent : AppColors.primary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Action Buttons
            ElevatedButton.icon(
              onPressed: _openPayOsCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text(
                'Open PayOS Gateway',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10),

            OutlinedButton.icon(
              onPressed: _isSyncing ? null : _checkPaymentStatus,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.surfaceBorder),
                backgroundColor: AppColors.surface,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : const Icon(Icons.sync_rounded, size: 18, color: AppColors.primary),
              label: Text(
                _isSyncing
                    ? 'Verifying transaction...'
                    : 'I Have Paid (Verify Payment)',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Dismiss',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
