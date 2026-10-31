import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:s256_wallet/models/price_info.dart';
import 'package:s256_wallet/providers/blockchain_provider.dart';
import 'package:s256_wallet/widgets/app_background.dart';
import 'package:url_launcher/url_launcher.dart';

/// Markets tab. Content follows https://sha256coin.eu/markets.html: third-party
/// exchanges, safety checks, independent market data trackers and the legal
/// notes (at the bottom).
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
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(),
                const SizedBox(height: 24),

                _sectionTitle('Live price', null),
                _priceCard(context.watch<BlockchainProvider>().priceInfo),
                const SizedBox(height: 28),

                _sectionTitle('Exchanges', 'Listed in alphabetical order. The order is not a ranking.'),
                _exchangeCard(
                  name: 'FynEx',
                  host: 'fyn-ex.uk',
                  link: 'https://fyn-ex.uk/trading/s256usdt',
                  logo: 'assets/images/fynex-mark.png',
                  pair: 'S256/USDT',
                  type: 'Custodial, centralized exchange',
                  note: 'FynEx also lists SS256 ("SATOSHI-IS-SHA256"), a BNB Smart Chain token that is not S256. '
                      'Check the ticker before you deposit or trade.',
                ),
                const SizedBox(height: 12),
                _exchangeCard(
                  name: 'Rabid Rabbit',
                  host: 'rabid-rabbit.org',
                  link: 'https://rabid-rabbit.org/account/trade/S256-USDT',
                  logo: 'assets/images/RR_Logo.png',
                  pair: 'S256/USDT',
                  type: 'Custodial, centralized exchange',
                ),
                const SizedBox(height: 10),
                _fineprint(
                  'Last checked: 13 October 2026. Listings, pairs, fees and limits change without notice: '
                  'check them on the platform itself.',
                ),

                const SizedBox(height: 28),
                _sectionTitle('Market data', 'Independent trackers that show S256 prices, volume and supply.'),
                _trackerTile(
                  name: 'CoinCarp',
                  host: 'coincarp.com',
                  link: 'https://www.coincarp.com/currencies/sha256coin/',
                  logo: 'assets/images/coincarp_logo.png',
                ),
                const SizedBox(height: 8),
                _trackerTile(
                  name: 'CoinCodex',
                  host: 'coincodex.com',
                  link: 'https://coincodex.com/crypto/sha256coin/',
                  logo: 'assets/images/coincodex.png',
                ),
                const SizedBox(height: 8),
                _trackerTile(
                  name: 'LiveCoinWatch',
                  host: 'livecoinwatch.com',
                  link: 'https://www.livecoinwatch.com/price/SHA256COIN-S256',
                  monogram: 'LCW',
                ),
                const SizedBox(height: 10),
                _fineprint(
                  'Trackers compute prices and market caps from a few low-volume markets. Their figures can be '
                  'stale or wrong and are not a valuation of S256. For supply and block data, use the S256 '
                  'explorer, which reads the blockchain directly.',
                ),
                const SizedBox(height: 8),
                _linkRow('S256 explorer', 'explorer.sha256coin.eu', 'https://explorer.sha256coin.eu'),

                const SizedBox(height: 28),
                _sectionTitle('Before you use an exchange', 'Basic safety checks. They do not replace your own research.'),
                SilverCard(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Column(
                    children: const [
                      _Step(
                        number: 1,
                        title: 'Check the address',
                        body: 'Type the exchange address yourself or use the link on this page, then bookmark it. '
                            'Fake exchange sites and "support" accounts in private messages are common. The S256 '
                            'project will never message you first, ask for your keys or seed phrase, or ask you '
                            'to send coins.',
                      ),
                      _Step(
                        number: 2,
                        title: 'Check that it is S256',
                        body: 'S256 is a native coin on its own blockchain. It has no token or contract on '
                            'Ethereum, BNB Smart Chain or any other network. S256 addresses start with s21, S or 8. '
                            'A token with a similar name or ticker is a different asset.',
                      ),
                      _Step(
                        number: 3,
                        title: 'Start small',
                        body: 'Test a deposit and a withdrawal with a small amount first. Check the exchange\'s '
                            'fees, minimum withdrawal and confirmation count. Low-volume markets can have wide '
                            'spreads and thin order books.',
                      ),
                      _Step(
                        number: 4,
                        title: 'Keep your coins in your own wallet',
                        body: 'Coins left on an exchange are held by the exchange, not by you. Exchanges can '
                            'freeze withdrawals, delist assets, get hacked or fail. Withdraw to a wallet whose '
                            'keys you hold, like this one.',
                        last: true,
                      ),
                    ],
                  ),
                ),

                // Notices last
                const SizedBox(height: 28),
                _sectionTitle('Notices', null),
                _notice(
                  icon: Icons.policy_outlined,
                  title: 'Disclaimer',
                  body: 'This wallet is non-custodial software. You keep sole control of private keys and '
                      'transactions. The app does not execute, route, or guarantee exchange trades. Any external '
                      'platform access is user-initiated and outside wallet control.',
                  color: S256Colors.primary,
                ),
                const SizedBox(height: 10),
                _notice(
                  icon: Icons.warning_amber_rounded,
                  title: 'Risk Notice',
                  body: 'Crypto-assets are volatile and may become illiquid. You can lose all value. Verify '
                      'destination addresses, platform terms, and local legal/tax obligations before trading or '
                      'transferring assets.',
                  color: Colors.orange,
                ),
                const SizedBox(height: 10),
                _notice(
                  icon: Icons.privacy_tip_rounded,
                  title: 'No Financial Advice',
                  body: 'Nothing in this section is financial, legal, or tax advice, or an offer or '
                      'recommendation to buy, sell or hold S256. Information is provided for transparency and '
                      'user awareness only.',
                  color: S256Colors.textLight,
                ),
                const SizedBox(height: 10),
                _notice(
                  icon: Icons.link_off_rounded,
                  title: 'No endorsement',
                  body: 'S256 has no company, foundation or issuer behind it. Listing S256 was each platform\'s '
                      'own decision. The S256 project does not operate, control, audit or vouch for any platform '
                      'named here. A link is not an endorsement. Before using any external venue, confirm the URL, '
                      'your account security settings, and whether the service is legally available where you '
                      'live.',
                  color: S256Colors.textLight,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'THIRD-PARTY VENUES · INFORMATION ONLY',
          style: TextStyle(
            fontFamily: 'ChakraPetch',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
            color: S256Colors.primary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Where S256 is listed',
          style: TextStyle(
            fontFamily: 'ChakraPetch',
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: S256Colors.text,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Independent exchanges list S256 and independent sites track its market data. The S256 project runs '
          'none of them. This page lists them so you can find the real addresses. It does not recommend any of '
          'them.',
          style: TextStyle(color: S256Colors.textLight, height: 1.45, fontSize: 14),
        ),
      ],
    );
  }

  Widget _priceCard(PriceInfo info) {
    return SilverCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                info.hasPrice ? PriceInfo.formatUsd(info.price!) : 'No price yet',
                style: TextStyle(
                  fontFamily: 'ChakraPetch',
                  fontSize: info.hasPrice ? 32 : 22,
                  fontWeight: FontWeight.w600,
                  color: info.hasPrice ? S256Colors.text : S256Colors.textLight,
                ),
              ),
              const SizedBox(width: 8),
              const Text('per S256', style: TextStyle(color: S256Colors.textLight, fontSize: 13)),
            ],
          ),
          if (info.hasPrice) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            if (info.volume != null) ...[_fact('24h vol', PriceInfo.formatCompactUsd(info.volume!)), const Divider(height: 1)],
            if (info.cap != null) ...[_fact('Mkt cap', PriceInfo.formatCompactUsd(info.cap!)), const Divider(height: 1)],
            if (info.liquidity != null) ...[_fact('Liquidity', PriceInfo.formatCompactUsd(info.liquidity!)), const Divider(height: 1)],
          ],
          const SizedBox(height: 10),
          _fineprint(
            info.hasPrice
                ? 'Source: LiveCoinWatch, read through the S256 explorer. It comes from a few low-volume markets '
                    'and is not a valuation of S256.'
                : 'LiveCoinWatch has no price for S256 at the moment. It will appear here and under your balance '
                    'when one is available.',
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String? subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'ChakraPetch',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.6,
              color: S256Colors.text,
            ),
          ),
          const SizedBox(height: 6),
          Container(width: 32, height: 2, color: S256Colors.primary),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(color: S256Colors.textLight, fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Widget _fineprint(String text) {
    return Text(
      text,
      style: const TextStyle(color: S256Colors.textLight, fontSize: 12, height: 1.45),
    );
  }

  Widget _logo(String? asset, String? monogram) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: S256Colors.surface2,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: S256Colors.line),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: asset != null
          ? Padding(
              padding: const EdgeInsets.all(4),
              child: Image.asset(
                asset,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.link, color: S256Colors.primary),
              ),
            )
          : Text(
              monogram ?? '',
              style: const TextStyle(
                fontFamily: 'ChakraPetch',
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: S256Colors.primary,
              ),
            ),
    );
  }

  Widget _exchangeCard({
    required String name,
    required String host,
    required String link,
    required String logo,
    required String pair,
    required String type,
    String? note,
  }) {
    return SilverCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _logo(logo, null),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontFamily: 'ChakraPetch',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: S256Colors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      host,
                      style: const TextStyle(
                        fontFamily: 'IBMPlexMono',
                        fontSize: 12,
                        color: S256Colors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          _fact('Pair', pair),
          const Divider(height: 1),
          _fact('Type', type),
          const Divider(height: 1),
          if (note != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.10),
                border: Border(left: BorderSide(color: Colors.orange.withValues(alpha: 0.8), width: 3)),
              ),
              child: Text(
                note,
                style: const TextStyle(color: S256Colors.text, fontSize: 12.5, height: 1.4),
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openUrl(link),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: Text('VISIT ${host.toUpperCase()}'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                foregroundColor: S256Colors.text,
                side: const BorderSide(color: S256Colors.lineStrong),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                textStyle: const TextStyle(
                  fontFamily: 'ChakraPetch',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fact(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontFamily: 'ChakraPetch',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: S256Colors.textLight,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: S256Colors.text, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _trackerTile({
    required String name,
    required String host,
    required String link,
    String? logo,
    String? monogram,
  }) {
    return InkWell(
      onTap: () => _openUrl(link),
      borderRadius: BorderRadius.circular(2),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: S256Colors.cardBg,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: S256Colors.line),
        ),
        child: Row(
          children: [
            _logo(logo, monogram),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontFamily: 'ChakraPetch',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: S256Colors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    host,
                    style: const TextStyle(
                      fontFamily: 'IBMPlexMono',
                      fontSize: 12,
                      color: S256Colors.textLight,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new_rounded, color: S256Colors.textLight, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _linkRow(String name, String host, String link) {
    return InkWell(
      onTap: () => _openUrl(link),
      borderRadius: BorderRadius.circular(2),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.travel_explore_rounded, color: S256Colors.primary, size: 18),
            const SizedBox(width: 8),
            Text(name, style: const TextStyle(color: S256Colors.primary, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Text(
              host,
              style: const TextStyle(fontFamily: 'IBMPlexMono', fontSize: 12, color: S256Colors.textLight),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notice({
    required IconData icon,
    required String title,
    required String body,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: S256Colors.cardBg,
        border: Border(
          left: BorderSide(color: color, width: 3),
          top: const BorderSide(color: S256Colors.line),
          right: const BorderSide(color: S256Colors.line),
          bottom: const BorderSide(color: S256Colors.line),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'ChakraPetch',
                    color: S256Colors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: const TextStyle(color: S256Colors.textLight, height: 1.4, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String title;
  final String body;
  final bool last;

  const _Step({
    required this.number,
    required this.title,
    required this.body,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 12 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: S256Colors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: S256Colors.primary.withValues(alpha: 0.5)),
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                fontFamily: 'ChakraPetch',
                fontWeight: FontWeight.w700,
                color: S256Colors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'ChakraPetch',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: S256Colors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(color: S256Colors.textLight, height: 1.45, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
