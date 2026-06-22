import 'package:flutter/material.dart';
import 'package:s256_wallet/widgets/app_background.dart';

class RegulatoryNoticeView extends StatelessWidget {
  const RegulatoryNoticeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Regulatory Notice',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: AppBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.35)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.gavel_rounded, color: Colors.blue),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'MiCA-Oriented Information',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Text(
                      'This section provides transparency information for users in line with current crypto-asset compliance expectations.',
                      style: TextStyle(color: Colors.white70, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _NoticeBlock(
                title: 'Non-Custodial Nature',
                text:
                    'S256 Wallet is a non-custodial software wallet. Private keys remain on your device. The wallet operator does not hold, recover, or control user funds.',
                icon: Icons.key_rounded,
                color: Colors.green,
              ),
              const SizedBox(height: 12),
              _NoticeBlock(
                title: 'No Execution Service',
                text:
                    'The app does not execute trades on your behalf and does not provide order routing or brokerage services. External exchange links are user-initiated.',
                icon: Icons.open_in_new_rounded,
                color: Colors.teal,
              ),
              const SizedBox(height: 12),
              _NoticeBlock(
                title: 'Risk Statement',
                text:
                    'Crypto-assets are highly volatile and can become illiquid. You may lose all value. Network fees, smart contract risk, and third-party platform risk may apply.',
                icon: Icons.warning_amber_rounded,
                color: Colors.orange,
              ),
              const SizedBox(height: 12),
              _NoticeBlock(
                title: 'No Financial Advice',
                text:
                    'Nothing in this wallet constitutes investment, legal, or tax advice. Users remain responsible for their own decisions and local regulatory obligations.',
                icon: Icons.balance_rounded,
                color: Colors.purple,
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: const Text(
                  'Reminder: Always verify destination addresses, URL authenticity of external services, and legal availability in your jurisdiction before transacting.',
                  style: TextStyle(color: Colors.white70, height: 1.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoticeBlock extends StatelessWidget {
  final String title;
  final String text;
  final IconData icon;
  final Color color;

  const _NoticeBlock({
    required this.title,
    required this.text,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: const TextStyle(color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
