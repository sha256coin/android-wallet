import 'package:flutter/material.dart';
import 'package:s256_wallet/theme/s256_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:s256_wallet/widgets/app_background.dart';
import 'package:s256_wallet/views/home/regulatory_notice_view.dart';

class AboutView extends StatelessWidget {
  const AboutView({super.key});



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'About',
          style: TextStyle(color: S256Colors.text, fontSize: 20),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: S256Colors.text),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: AppBackground(
        child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with logo/icon
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: S256Colors.cardBg,
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    size: 80,
                    color: S256Colors.accent,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // App Title
              const Center(
                child: Text(
                  'S256 Wallet',
                  style: TextStyle(
                    color: S256Colors.text,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Version
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: S256Colors.accent.withValues(alpha: 0.2),
                    borderRadius: S256Theme.borderRadius,
                  ),
                  child: const Text(
                    'Version 1.7.0',
                    style: TextStyle(color: S256Colors.accent, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 16),



              // Main description
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: S256Colors.cardBg,
                  borderRadius: S256Theme.borderRadius,
                  border: Border.all(
                    color: S256Colors.accent.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: const Text(
                  'Take control of your crypto with S256 Wallet—designed for privacy-first users who value simplicity and security.',
                  style: TextStyle(
                    color: S256Colors.text,
                    fontSize: 16,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),

              // Why S256 Wallet section
              _buildSectionTitle('🔐 Why S256 Wallet?'),
              const SizedBox(height: 16),
              _buildFeatureItem(
                Icons.flash_on,
                'No registration required—start using instantly',
              ),
              _buildFeatureItem(
                Icons.privacy_tip,
                'No personal data collected or stored',
              ),
              _buildFeatureItem(
                Icons.lock,
                'Private keys stay on your device, never shared',
              ),
              _buildFeatureItem(
                Icons.public,
                'Supports public blockchain transactions with full transparency',
              ),
              const SizedBox(height: 32),

              // Privacy You Can Trust section
              _buildSectionTitle('🛡️ Privacy You Can Trust'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: S256Colors.text.withValues(alpha: 0.05),
                  borderRadius: S256Theme.borderRadius,
                  border: Border.all(
                    color: S256Colors.text.withValues(alpha: 0.1),
                  ),
                ),
                child: const Text(
                  'We don\'t ask for your name, email, or address. Your wallet activity is yours alone. Automatically collected data (like device type or app version) is used only to ensure smooth performance—never stored or shared.',
                  style: TextStyle(
                    color: S256Colors.textLight,
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Transparent Policy section
              _buildSectionTitle('💬 Transparent Policy'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: S256Colors.text.withValues(alpha: 0.05),
                  borderRadius: S256Theme.borderRadius,
                  border: Border.all(
                    color: S256Colors.text.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Issued by:', 'S256 Team'),
                    const SizedBox(height: 12),
                    _buildInfoRow('Effective Date:', 'November 30, 2025'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text(
                          'Contact: ',
                          style: TextStyle(
                            color: S256Colors.textLight,
                            fontSize: 15,
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            final uri = Uri.parse('mailto:info@sha256coin.eu');
                            try {
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              }
                            } catch (e) {
                              // Silently handle - no email app available
                            }
                          },
                          child: const Text(
                            'info@sha256coin.eu',
                            style: TextStyle(
                              color: S256Colors.accent,
                              fontSize: 15,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text(
                          'Website: ',
                          style: TextStyle(
                            color: S256Colors.textLight,
                            fontSize: 15,
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            final uri = Uri.parse('https://sha256coin.eu');
                            try {
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            } catch (e) {
                              // Silently handle - no browser available
                            }
                          },
                          child: const Text(
                            'sha256coin.eu',
                            style: TextStyle(
                              color: S256Colors.accent,
                              fontSize: 15,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Regulatory notice entry
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: S256Colors.primary.withValues(alpha: 0.12),
                  borderRadius: S256Theme.borderRadius,
                  border: Border.all(
                    color: S256Colors.primary.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.policy_outlined, color: S256Colors.primary),
                        SizedBox(width: 10),
                        Text(
                          'Disclaimer & Transparency',
                          style: TextStyle(
                            color: S256Colors.text,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Read risk and non-custodial disclosures aligned with MiCA-oriented transparency expectations.',
                      style: TextStyle(color: S256Colors.textLight, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegulatoryNoticeView(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('Open Regulatory Notice'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: S256Colors.primary,
                          side: BorderSide(color: S256Colors.primary.withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Footer message
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: S256Colors.cardBg,
                  borderRadius: S256Theme.borderRadius,
                ),
                child: const Text(
                  'Experience crypto the way it was meant to be: decentralized, secure, and private.',
                  style: TextStyle(
                    color: S256Colors.accent,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: S256Colors.text,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: S256Colors.accent.withValues(alpha: 0.2),
              borderRadius: S256Theme.borderRadius,
            ),
            child: Icon(
              icon,
              color: S256Colors.accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                text,
                style: const TextStyle(
                  color: S256Colors.textLight,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: S256Colors.textLight,
            fontSize: 15,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: S256Colors.text,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
