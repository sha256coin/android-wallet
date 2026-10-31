import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:s256_wallet/providers/wallet_provider.dart';
import 'package:s256_wallet/theme/s256_theme.dart';
import 'package:s256_wallet/widgets/app_background.dart';
import 'package:s256_wallet/widgets/hud.dart';
import 'package:s256_wallet/widgets/status_strip.dart';

class NetworkInfoView extends StatefulWidget {
  const NetworkInfoView({super.key});

  @override
  State<NetworkInfoView> createState() => _NetworkInfoViewState();
}

class _NetworkInfoViewState extends State<NetworkInfoView> {
  Map<String, dynamic>? _info;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchInfo();
  }

  Future<void> _fetchInfo() async {
    if (mounted) setState(() => _loading = true);
    final wp = Provider.of<WalletProvider>(context, listen: false);
    final info = await wp.getNetworkInfo();
    if (mounted) {
      setState(() {
        _info = info;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        shape: const Border(),
        actions: [
          IconButton(
            onPressed: _loading ? null : _fetchInfo,
            icon: const Icon(Icons.refresh_rounded),
            color: S256Colors.textLight,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                children: [
                  HudTitle(
                    'Network',
                    label: 'S256 mainnet',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PulseDot(color: _info != null ? S256Colors.success : S256Colors.primary, size: 7),
                        const SizedBox(width: 4),
                        Text(
                          _loading ? 'READING NODE' : _info != null ? 'ONLINE' : 'UNREACHABLE',
                          style: TextStyle(
                            fontFamily: S256Theme.mono,
                            fontSize: 11,
                            letterSpacing: 1.4,
                            color: _info != null || _loading ? S256Colors.text : S256Colors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (_loading && _info == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_info == null)
                    const HudCard(
                      child: Text(
                        'Failed to load network information',
                        style: TextStyle(color: S256Colors.textLight),
                      ),
                    )
                  else ...[
                    _buildStats(),
                    const SizedBox(height: 28),
                    LayoutBuilder(builder: (context, constraints) {
                      final mempool = _buildSection('Mempool', [
                        _buildInfoRow('Transactions', '${_info!['mempool_size'] ?? 'N/A'}'),
                        _buildInfoRow('Size', _formatBytes(_info!['mempool_bytes'])),
                      ]);
                      final node = _buildSection('Node', [
                        _buildInfoRow('Version', '${_info!['version'] ?? 'N/A'}'),
                        _buildInfoRow('Subversion', '${_info!['subversion'] ?? 'N/A'}'),
                        _buildInfoRow('Median time', _formatTime(_info!['mediantime'])),
                        _buildInfoRow('Best block', _shortHash(_info!['bestblockhash'])),
                      ]);
                      if (constraints.maxWidth < 700) {
                        return Column(children: [mempool, const SizedBox(height: 20), node]);
                      }
                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(flex: 2, child: mempool),
                            const SizedBox(width: 20),
                            Expanded(flex: 3, child: node),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Four large figures: two per row on a phone, four on a wide screen.
  Widget _buildStats() {
    final blocks = _info!['blocks'];
    final peers = _info!['connections'];
    final tiles = [
      ('Block height', blocks is num ? NumberFormat.decimalPattern('en_US').format(blocks) : 'N/A', true),
      ('Hashrate', formatHashrate(_info!['networkhashps']), false),
      ('Difficulty', _formatDifficulty(_info!['difficulty']), false),
      ('Peers', peers is num ? '$peers' : 'N/A', false),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      const gap = 16.0;
      final perRow = constraints.maxWidth >= 720 ? 4 : 2;
      final width = (constraints.maxWidth - gap * (perRow - 1)) / perRow;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final (label, value, brackets) in tiles)
            SizedBox(
              width: width,
              child: HudCard(
                brackets: brackets,
                borderColor: brackets ? S256Colors.lineStrong : null,
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HudLabel(label, slashes: false, color: S256Colors.textLight),
                    const SizedBox(height: 10),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: brackets
                          ? PlatinumText(value, style: _statStyle)
                          : Text(value, style: _statStyle.copyWith(color: S256Colors.text)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }

  static const _statStyle = TextStyle(
    fontFamily: S256Theme.display,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.1,
  );

  Widget _buildSection(String title, List<Widget> rows) {
    return HudCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HudLabel(title),
          const SizedBox(height: 8),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            rows[i],
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: S256Colors.textLight, fontSize: 14)),
          const SizedBox(width: 16),
          Flexible(
            child: SelectableText(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontFamily: S256Theme.mono, fontSize: 13),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _shortHash(dynamic hash) {
    if (hash is! String || hash.length < 20) return hash?.toString() ?? 'N/A';
    return '${hash.substring(0, 10)}…${hash.substring(hash.length - 8)}';
  }

  String _formatDifficulty(dynamic difficulty) {
    if (difficulty == null) return 'N/A';
    final d = (difficulty as num).toDouble();
    if (d >= 1e12) return '${(d / 1e12).toStringAsFixed(2)} T';
    if (d >= 1e9) return '${(d / 1e9).toStringAsFixed(2)} G';
    if (d >= 1e6) return '${(d / 1e6).toStringAsFixed(2)} M';
    if (d >= 1e3) return '${(d / 1e3).toStringAsFixed(2)} K';
    return d.toStringAsFixed(2);
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(date);
  }

  String _formatBytes(dynamic bytes) {
    if (bytes == null) return 'N/A';
    int b = bytes as int;
    if (b > 1024 * 1024) return '${(b / (1024 * 1024)).toStringAsFixed(2)} MB';
    if (b > 1024) return '${(b / 1024).toStringAsFixed(2)} KB';
    return '$b Bytes';
  }
}
