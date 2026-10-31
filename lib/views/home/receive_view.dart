import 'package:flutter/material.dart';
import 'package:s256_wallet/theme/s256_theme.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:s256_wallet/providers/wallet_provider.dart';
import 'package:s256_wallet/services/payment_request.dart';
import 'package:s256_wallet/widgets/app_background.dart';

class ReceiveView extends StatefulWidget {
  const ReceiveView({super.key});

  @override
  State<ReceiveView> createState() => _ReceiveViewState();
}

class _ReceiveViewState extends State<ReceiveView>
    with TickerProviderStateMixin {
  late AnimationController _qrAnimationController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  bool _isAddressCopied = false;
  String? _requestedAmount;
  String? _requestMessage;

  @override
  void initState() {
    super.initState();

    // QR Code animation - SLOWER ENTRANCE
    _qrAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200), // Doubled from 600ms to 1200ms
      vsync: this,
    );

    // Fade animation for content
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    // Pulse animation for logo
    _pulseAnimation = Tween<double>(
      begin: 0.6,
      end: 1.4,
    ).animate(CurvedAnimation(
      parent: _qrAnimationController,
      curve: Curves.easeInOut,
    ));

    _qrAnimationController.forward();
    _fadeController.forward();

    // Add repeating pulse effect
    _qrAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _qrAnimationController.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _qrAnimationController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.mediumImpact();

    setState(() {
      _isAddressCopied = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: S256Colors.text, size: 20),
            SizedBox(width: 8),
            Text('Address copied to clipboard!'),
          ],
        ),
        backgroundColor: S256Colors.surface2,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: S256Theme.borderRadius,
        ),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 2),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isAddressCopied = false;
        });
      }
    });
  }

  // The active payment request, or null when only the address is shown.
  // Same format as the web wallet (see PaymentRequest).
  PaymentRequest? _currentRequest(String? address) {
    if (address == null || address.isEmpty) return null;
    final amountSats = PaymentRequest.parseAmount(_requestedAmount ?? '');
    if (amountSats == null) return null;
    final message = _requestMessage?.trim() ?? '';
    return PaymentRequest(
      address: address,
      amountSats: amountSats,
      message: message.isEmpty ? null : message,
    );
  }

  void _shareAddress(String address) {
    HapticFeedback.lightImpact();

    // A request is shared with a web wallet link and the sha256coin: URI,
    // so it can be paid from the web wallet or pasted into this app.
    final shareText = _currentRequest(address)?.toShareText() ??
        'My S256 wallet address:\n\n$address';

    SharePlus.instance.share(
      ShareParams(
        text: shareText,
        subject: 'S256 Wallet Address',
      ),
    );
  }

  Future<void> _showRequestAmountDialog(BuildContext context, String address) async {
    HapticFeedback.lightImpact();

    final TextEditingController amountController = TextEditingController(text: _requestedAmount);
    final TextEditingController messageController = TextEditingController(text: _requestMessage);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: S256Colors.surface2,
          shape: RoundedRectangleBorder(
            borderRadius: S256Theme.borderRadius,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: S256Colors.darkBg,
              borderRadius: S256Theme.borderRadius,
              border: Border.all(
                color: S256Colors.text.withValues(alpha: 0.1),
              ),
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: S256Colors.primary.withValues(alpha: 0.2),
                          borderRadius: S256Theme.borderRadius,
                        ),
                        child: const Icon(
                          Icons.request_quote,
                          color: S256Colors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Request Amount',
                        style: TextStyle(
                          color: S256Colors.text,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Amount input
                  TextFormField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: S256Colors.text),
                    decoration: InputDecoration(
                      labelText: 'Amount (S256)',
                      labelStyle: TextStyle(color: S256Colors.textLight),
                      prefixIcon: Icon(Icons.monetization_on, color: S256Colors.primary),
                      filled: true,
                      fillColor: S256Colors.darkBg.withValues(alpha: 0.3),
                      border: OutlineInputBorder(
                        borderRadius: S256Theme.borderRadius,
                        borderSide: BorderSide(color: S256Colors.text.withValues(alpha: 0.1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: S256Theme.borderRadius,
                        borderSide: BorderSide(color: S256Colors.text.withValues(alpha: 0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: S256Theme.borderRadius,
                        borderSide: BorderSide(color: S256Colors.primary),
                      ),
                    ),
                    validator: (value) {
                      // Up to 8 decimals, above 0, no exponents: the same
                      // rule the scanner and the web wallet use.
                      if (PaymentRequest.parseAmount(value ?? '') == null) {
                        return 'Please enter a valid amount';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Message input (optional)
                  TextFormField(
                    controller: messageController,
                    maxLines: 3,
                    maxLength: PaymentRequest.maxMessageLength,
                    style: const TextStyle(color: S256Colors.text),
                    decoration: InputDecoration(
                      labelText: 'Message (optional)',
                      labelStyle: TextStyle(color: S256Colors.textLight),
                      prefixIcon: Icon(Icons.message, color: S256Colors.primary),
                      filled: true,
                      fillColor: S256Colors.darkBg.withValues(alpha: 0.3),
                      border: OutlineInputBorder(
                        borderRadius: S256Theme.borderRadius,
                        borderSide: BorderSide(color: S256Colors.text.withValues(alpha: 0.1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: S256Theme.borderRadius,
                        borderSide: BorderSide(color: S256Colors.text.withValues(alpha: 0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: S256Theme.borderRadius,
                        borderSide: BorderSide(color: S256Colors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Text(
                    'This will create a payment request with your address',
                    style: TextStyle(
                      color: S256Colors.textLight,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.of(context).pop();
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: S256Theme.borderRadius,
                              side: BorderSide(color: S256Colors.text.withValues(alpha: 0.2)),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: S256Colors.textLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              HapticFeedback.lightImpact();
                              Navigator.of(context).pop({
                                // Normalised, e.g. "01.50" -> "1.5"
                                'amount': PaymentRequest.formatAmount(
                                    PaymentRequest.parseAmount(amountController.text)!),
                                'message': messageController.text.trim(),
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: S256Colors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: S256Theme.borderRadius,
                            ),
                          ),
                          child: const Text(
                            'Create Request',
                            style: TextStyle(
                              color: S256Colors.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (result != null) {
      setState(() {
        _requestedAmount = result['amount'];
        _requestMessage = result['message'];
      });

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: S256Colors.onPrimary, size: 20),
              const SizedBox(width: 8),
              Text('Payment request created: ${result['amount']} S256',
                  style: const TextStyle(color: S256Colors.onPrimary)),
            ],
          ),
          backgroundColor: S256Colors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: S256Theme.borderRadius,
          ),
          margin: const EdgeInsets.all(20),
        ),
      );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletProvider = Provider.of<WalletProvider>(context);
    final address = walletProvider.address;
    final screenWidth = MediaQuery.of(context).size.width;
    final qrSize = (screenWidth - 120).clamp(180.0, 340.0).toDouble();

    // QR: the plain address, or sha256coin:<address>?amount=..&message=..
    // when an amount is requested (readable by this app and the web wallet).
    final String qrData = _currentRequest(address)?.toUri() ?? address ?? '';

    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: S256Colors.darkBg,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: S256Colors.text.withValues(alpha: 0.1),
              borderRadius: S256Theme.borderRadius,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: S256Colors.text,
                  size: 20
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
            ),
          ),
          title: const Text(
            'Receive S256',
            style: TextStyle(
              color: S256Colors.text,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          centerTitle: true,
        ),
        body: Container(
          decoration: BoxDecoration(
            color: S256Colors.darkBg,
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Logo and title section
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _pulseAnimation.value,
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: S256Colors.cardBg,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: S256Colors.text.withValues(alpha: 0.2),
                                      width: 2,
                                    ),
                                  ),
                                  child: Image.asset(
                                    'assets/logo_big.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'S256 Wallet',
                            style: TextStyle(
                              color: S256Colors.text,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: S256Colors.success.withValues(alpha: 0.2),
                              borderRadius: S256Theme.borderRadius,
                              border: Border.all(
                                color: S256Colors.success.withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: S256Colors.success,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Ready to receive',
                                  style: TextStyle(
                                    color: S256Colors.success,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Request amount indicator if active
                    if (_requestedAmount != null && _requestedAmount!.isNotEmpty)
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: S256Colors.primary.withValues(alpha: 0.1),
                            borderRadius: S256Theme.borderRadius,
                            border: Border.all(
                              color: S256Colors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.request_quote,
                                color: S256Colors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Requesting $_requestedAmount S256',
                                      style: const TextStyle(
                                        color: S256Colors.text,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (_requestMessage != null && _requestMessage!.isNotEmpty)
                                      Text(
                                        _requestMessage!,
                                        style: TextStyle(
                                          color: S256Colors.textLight,
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.clear, color: S256Colors.textLight, size: 20),
                                onPressed: () {
                                  setState(() {
                                    _requestedAmount = null;
                                    _requestMessage = null;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                    // QR Code Container
                    if (address != null && address.isNotEmpty) ...[
                      Container(
                        width: qrSize + 40,
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          // Pure white behind the QR code so every scanner reads it.
                          color: Color(0xFFFFFFFF),
                          borderRadius: S256Theme.borderRadius,
                        ),
                        child: Column(
                          children: [
                            // Static QR (no animation) with responsive sizing
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                QrImageView(
                                  data: qrData,
                                  version: QrVersions.auto,
                                  size: qrSize,
                                  backgroundColor: Colors.transparent,
                                  errorCorrectionLevel: QrErrorCorrectLevel.H,
                                ),
                                // Logo in center of QR
                                Container(
                                  width: 50,
                                  height: 50,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: S256Colors.text,
                                    borderRadius: S256Theme.borderRadius,
                                    border: Border.all(
                                      color: S256Colors.darkBg.withValues(alpha: 0.1),
                                      width: 2,
                                    ),
                                  ),
                                  child: Image.asset(
                                    'assets/logo_big.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Scan to send S256',
                              style: TextStyle(
                                color: S256Colors.textLight,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Address section
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: S256Colors.cardBg,
                            borderRadius: S256Theme.borderRadius,
                            border: Border.all(
                              color: S256Colors.text.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.account_balance_wallet,
                                    color: S256Colors.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Wallet Address',
                                    style: TextStyle(
                                      color: S256Colors.textLight,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: S256Colors.darkBg.withValues(alpha: 0.3),
                                  borderRadius: S256Theme.borderRadius,
                                  border: Border.all(
                                    color: _isAddressCopied
                                        ? S256Colors.success.withValues(alpha: 0.5)
                                        : S256Colors.text.withValues(alpha: 0.1),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        address,
                                        style: const TextStyle(
                                          color: S256Colors.text,
                                          fontFamily: S256Theme.mono,
                                          fontSize: 13,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: () => _copyToClipboard(address),
                                      borderRadius: S256Theme.borderRadius,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: _isAddressCopied ? S256Colors.success : S256Colors.primary,
                                          borderRadius: S256Theme.borderRadius,
                                        ),
                                        child: Icon(
                                          _isAddressCopied ? Icons.check : Icons.copy,
                                          color: S256Colors.onPrimary,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Action buttons
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildActionButton(
                                icon: Icons.share,
                                label: 'Share',
                                onTap: () => _shareAddress(address),
                                gradient: [
                                  S256Colors.primary,
                                  S256Colors.primary,
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildActionButton(
                                icon: Icons.qr_code_scanner,
                                label: 'Request Amount',
                                onTap: () => _showRequestAmountDialog(context, address),
                                gradient: [
                                  S256Colors.primary,
                                  S256Colors.primary,
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Info section
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: S256Colors.primary.withValues(alpha: 0.05),
                            borderRadius: S256Theme.borderRadius,
                            border: Border.all(
                              color: S256Colors.primary.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: S256Colors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'How to receive S256',
                                      style: TextStyle(
                                        color: S256Colors.text,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Share your wallet address or QR code with the sender. Always verify the address before confirming any transaction to ensure funds are sent to the correct location.',
                                      style: TextStyle(
                                        color: S256Colors.textLight,
                                        fontSize: 13,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      // Empty state
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.5,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 80,
                                color: S256Colors.textLight,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No wallet address available',
                                style: TextStyle(
                                  color: S256Colors.textLight,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Please create or import a wallet first',
                                style: TextStyle(
                                  color: S256Colors.textLight,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required List<Color> gradient,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: S256Theme.borderRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: gradient.first,
          borderRadius: S256Theme.borderRadius,
          
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: S256Colors.onPrimary, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: S256Colors.onPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}