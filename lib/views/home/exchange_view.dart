import 'package:flutter/material.dart';
import 'package:s256_wallet/widgets/app_background.dart';
import 'package:url_launcher/url_launcher.dart';

class ExchangeView extends StatelessWidget {
  const ExchangeView({super.key});

  Future<void> _openUrl(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: S256Colors.accent.withValues(alpha: 0.5),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: S256Colors.accent.withValues(alpha: 0.2),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/logo.png',
                          height: 70,
                          width: 70,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.account_balance_wallet,
                            size: 70,
                            color: S256Colors.accent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'S256 Market Information',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _infoCard(
                  icon: Icons.gavel_rounded,
                  title: 'MiCA-Oriented Disclosures',
                  body:
                      'This wallet is non-custodial software. You keep sole control of private keys and transactions. The app does not execute, route, or guarantee exchange trades. Any external platform access is user-initiated and outside wallet control.',
                  color: Colors.blue,
                ),
                const SizedBox(height: 12),
                _infoCard(
                  icon: Icons.warning_amber_rounded,
                  title: 'Risk Notice',
                  body:
                      'Crypto-assets are volatile and may become illiquid. You can lose all value. Verify destination addresses, platform terms, and local legal/tax obligations before trading or transferring assets.',
                  color: Colors.orange,
                ),
                const SizedBox(height: 12),
                _infoCard(
                  icon: Icons.privacy_tip_rounded,
                  title: 'No Financial Advice',
                  body:
                      'Nothing in this section is financial, legal, or tax advice. Information is provided for transparency and user awareness only.',
                  color: Colors.teal,
                ),
                const SizedBox(height: 18),
                const Text(
                  'External Trading Platforms',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                _platformTile(
                  name: 'Rabid Rabbit',
                  link: 'https://rabid-rabbit.org/account/trade/S256-USDT',
                  note: 'Third-party venue. Opens outside the wallet.',
                  imageIcon: 'assets/images/RR_Logo.png',
                ),
                _platformTile(
                  name: 'KlingEx',
                  link: 'https://klingex.io/trade/S256-USDT',
                  note: 'Third-party venue. Opens outside the wallet.',
                  imageIcon: 'assets/images/klingex.png',
                ),
                const SizedBox(height: 16),
                SilverCard(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'Before using any external venue: confirm URL authenticity, account security settings, and whether the service is legally available in your jurisdiction.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String body,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    height: 1.4,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _platformTile({
    required String name,
    required String link,
    required String note,
    required String imageIcon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _openUrl(link),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  imageIcon,
                  width: 42,
                  height: 42,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.link,
                    color: S256Colors.accent,
                    size: 42,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      note,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.open_in_new_rounded,
                color: Colors.white.withValues(alpha: 0.55),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
