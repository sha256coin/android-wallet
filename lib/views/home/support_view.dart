import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:s256_wallet/widgets/app_background.dart';

class SupportView extends StatelessWidget {
  const SupportView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Support',
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
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        S256Colors.accent.withValues(alpha: 0.3),
                        S256Colors.accent.withValues(alpha: 0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(
                    Icons.support_agent,
                    size: 60,
                    color: S256Colors.accent,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Center(
                child: Text(
                  'Get Help & Connect',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              const Center(
                child: Text(
                  'We\'re here to help you with S256',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 15,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),

              // Contact Section
              _buildSectionTitle('Contact Us'),
              const SizedBox(height: 16),

              _buildContactCard(
                context: context,
                icon: Icons.language,
                title: 'Website',
                subtitle: 'sha256coin.eu',
                url: 'https://sha256coin.eu',
                color: Colors.blue,
              ),

              _buildEmailCard(
                context: context,
                email: 'info@sha256coin.eu',
              ),

              const SizedBox(height: 32),

              // Community Section
              _buildSectionTitle('Join Our Community'),
              const SizedBox(height: 16),

              _buildContactCard(
                context: context,
                icon: Icons.chat,
                title: 'Discord',
                subtitle: 'Join our Discord server',
                url: 'https://discord.gg/dtn58HrC94',
                color: const Color(0xFF5865F2),
              ),

              _buildContactCard(
                context: context,
                icon: Icons.send,
                title: 'Telegram',
                subtitle: 'Follow us on Telegram',
                url: 'https://t.me/s256coin',
                color: const Color(0xFF0088CC),
              ),

              _buildContactCard(
                context: context,
                icon: Icons.tag,
                title: 'X (Twitter)',
                subtitle: 'Follow S256 coin on X',
                url: 'https://x.com/s256coin',
                color: Colors.black,
                iconColor: Colors.white,
              ),

              _buildContactCard(
                context: context,
                icon: Icons.forum,
                title: 'Bitcointalk',
                subtitle: 'Join the discussion',
                url: 'https://bitcointalk.org/index.php?topic=5567429.msg66131557#msg66131557',
                color: const Color(0xFFF7931A),
              ),

              const SizedBox(height: 32),

              // Resources Section
              _buildSectionTitle('Resources'),
              const SizedBox(height: 16),

              _buildContactCard(
                context: context,
                icon: Icons.code,
                title: 'Developers',
                subtitle: 'View our GitHub repository',
                url: 'https://github.com/sha256coin/android-wallet',
                color: const Color(0xFF24292e),
                iconColor: Colors.white,
              ),
/*
              _buildContactCard(
                icon: Icons.savings,
                title: 'MiningPoolStat.app',
                subtitle: 'Check S256 mining pools',
                url: 'https://miningpoolstats.app/coins/S256',
                color: Colors.green,
              ),
*/
              const SizedBox(height: 32),

              // Help Message
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      S256Colors.accent.withValues(alpha: 0.2),
                      S256Colors.accent.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: S256Colors.accent,
                      size: 24,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Need immediate assistance? Join our Discord or Telegram for real-time support from our community.',
                        style: TextStyle(
                          color: S256Colors.accent,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
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
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String url,
    required Color color,
    Color? iconColor,
    BuildContext? context,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Builder(
        builder: (BuildContext builderContext) {
          return InkWell(
            onTap: () => _openUrl(context ?? builderContext, url, title),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: iconColor ?? Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white.withValues(alpha: 0.3),
                    size: 16,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openUrl(BuildContext context, String url, String title) async {
    final uri = Uri.parse(url);

    try {
      var launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (!launched) {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      if (!launched) {
        launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      }

      if (!launched) {
        if (!context.mounted) return;
        _showLinkDialog(context, url, title);
      }
    } catch (_) {
      try {
        final fallbackLaunched = await launchUrl(uri);
        if (!fallbackLaunched && context.mounted) {
          _showLinkDialog(context, url, title);
        }
      } catch (_) {
        if (context.mounted) {
          _showLinkDialog(context, url, title);
        }
      }
    }
  }

  void _showLinkDialog(BuildContext context, String url, String title) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: S256Colors.accent.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          title: Row(
            children: [
              Icon(Icons.link, color: S256Colors.accent, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Open $title',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Unable to open this link automatically. Copy the URL below:',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: S256Colors.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        url,
                        style: TextStyle(
                          color: S256Colors.accent,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.copy, color: S256Colors.accent, size: 20),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: url));
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Link copied to clipboard'),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Close',
                style: TextStyle(
                  color: S256Colors.accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmailCard({
    required BuildContext context,
    required String email,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          final uri = Uri(scheme: 'mailto', path: email);
          try {
            final launched = await launchUrl(
              uri,
              mode: LaunchMode.externalApplication,
            );

            if (!launched) {
              if (!context.mounted) return;
              _showEmailDialog(context, email);
            }
          } catch (_) {
            if (!context.mounted) return;
            _showEmailDialog(context, email);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.email,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Email',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withValues(alpha: 0.3),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEmailDialog(BuildContext context, String email) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: S256Colors.accent.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          title: Row(
            children: [
              Icon(Icons.email, color: S256Colors.accent, size: 28),
              const SizedBox(width: 12),
              const Text(
                'Contact Email',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Copy the email address below:',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: S256Colors.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        email,
                        style: TextStyle(
                          color: S256Colors.accent,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.copy, color: S256Colors.accent, size: 20),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: email));
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Email copied to clipboard'),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Close',
                style: TextStyle(
                  color: S256Colors.accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
