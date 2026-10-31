import 'dart:async';
import 'package:s256_wallet/widgets/transaction_widget.dart';
import 'package:s256_wallet/widgets/skeleton_loader.dart';
import 'package:s256_wallet/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:s256_wallet/models/price_info.dart';
import 'package:s256_wallet/providers/blockchain_provider.dart';
import 'package:s256_wallet/providers/wallet_provider.dart';
import 'package:s256_wallet/views/home/receive_view.dart';
import 'package:s256_wallet/views/home/send_view.dart';
import 'package:s256_wallet/widgets/button_widget.dart';
import 'package:s256_wallet/modals/transaction_modal.dart';
import 'package:s256_wallet/views/home/transactions_view.dart';
import 'package:s256_wallet/theme/s256_theme.dart';
import 'package:s256_wallet/widgets/app_background.dart';
import 'package:s256_wallet/widgets/balance_chart.dart';
import 'package:s256_wallet/widgets/hud.dart';
import 'package:s256_wallet/widgets/status_strip.dart';

class WalletView extends StatefulWidget {
  const WalletView({super.key});

  @override
  State<WalletView> createState() => _WalletViewState();
}

class _WalletViewState extends State<WalletView> with SingleTickerProviderStateMixin {
  late AnimationController _pendingAnimationController;
  late Animation<double> _pendingAnimation;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _pendingAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pendingAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pendingAnimationController,
      curve: Curves.easeInOut,
    ));
    _pendingAnimationController.repeat(reverse: true);

    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      final wp = Provider.of<WalletProvider>(context, listen: false);
      if (wp.hasPendingTransactions) {
        wp.fetchUtxos(force: true, silent: true);
      }
    });

  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pendingAnimationController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    final wp = Provider.of<WalletProvider>(context, listen: false);
    final bp = Provider.of<BlockchainProvider>(context, listen: false);

    // Show feedback message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(S256Colors.accent),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              wp.hasPendingTransactions
                  ? 'Checking for confirmations...'
                  : 'Syncing wallet data...',
              style: const TextStyle(
                color: S256Colors.text,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        backgroundColor: S256Colors.surface2,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: S256Theme.borderRadius,
          side: BorderSide(
            color: S256Colors.accent.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
    );

    if (wp.hasPendingTransactions) {
      await wp.fetchUtxos(force: true, silent: true); // Use silent mode
    } else {
      await Future.wait([
        wp.fetchUtxos(force: true),
        bp.loadBlockchain(wp.address),
      ]);
    }

    // Show completion message
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: S256Colors.success, size: 18),
              SizedBox(width: 12),
              Text(
                'Wallet synced',
                style: TextStyle(
                  color: S256Colors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          backgroundColor: S256Colors.surface2,
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: S256Theme.borderRadius,
            side: BorderSide(
              color: S256Colors.success.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
        ),
      );
    }
  }

  void _showTransactionDetails(String txid) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: S256Colors.cardBg,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(2),
            topRight: Radius.circular(2),
          ),
        ),
        child: TransactionModal(txid: txid),
      ),
    );
  }

  Widget _buildBalanceCard(
    BlockchainProvider blockchainProvider,
    WalletProvider walletProvider,
    List<dynamic> transactions,
    double? displayBalance,
    double? confirmedBalance,
    bool hasPending,
    double? price,
  ) {
    final info = blockchainProvider.priceInfo;
    final history = BalanceHistory.fromExplorer(
      transactions,
      confirmedBalance: confirmedBalance ?? displayBalance ?? 0,
      totalBalance: displayBalance,
    );

    return HudCard(
      brackets: true,
      borderColor: S256Colors.lineStrong,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const HudLabel('Wallet balance'),
              if (hasPending) ...[
                const SizedBox(width: 10),
                FadeTransition(
                  opacity: _pendingAnimation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: S256Colors.glow,
                      borderRadius: S256Theme.borderRadius,
                      border: Border.all(color: S256Colors.primary.withValues(alpha: 0.5)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time, color: S256Colors.primary, size: 12),
                        SizedBox(width: 6),
                        Text(
                          'PENDING',
                          style: TextStyle(fontFamily: S256Theme.mono, color: S256Colors.primary, fontSize: 10, letterSpacing: 1.2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                PlatinumText(
                  displayBalance?.toStringAsFixed(4) ?? '0.0000',
                  style: const TextStyle(
                    fontFamily: S256Theme.display,
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'S256',
                  style: TextStyle(
                    fontFamily: S256Theme.display,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: S256Colors.primary,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          // Value in USD, only while the explorer has a price
          if (price != null && displayBalance != null) ...[
            const SizedBox(height: 8),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 4,
              children: [
                Text(
                  '≈ ${PriceInfo.formatUsd(displayBalance * price)} USD',
                  style: const TextStyle(fontFamily: S256Theme.mono, color: S256Colors.accent, fontSize: 14),
                ),
                if (info.change24h case final change?)
                  Text(
                    '${PriceInfo.formatChange(change)} 24H',
                    style: TextStyle(
                      fontFamily: S256Theme.mono,
                      fontSize: 11,
                      color: change >= 0 ? S256Colors.success : S256Colors.danger,
                    ),
                  ),
                // Not a live price: say when it last traded
                if (info.isLastTrade)
                  Text(
                    'LAST TRADED ${PriceInfo.formatDate(info.lastTraded!).toUpperCase()}',
                    style: const TextStyle(
                      fontFamily: S256Theme.mono,
                      color: S256Colors.textLight,
                      fontSize: 10.5,
                      letterSpacing: 0.8,
                    ),
                  ),
              ],
            ),
          ],
          if (hasPending && confirmedBalance != displayBalance) ...[
            const SizedBox(height: 8),
            Text(
              'Confirmed: ${confirmedBalance?.toStringAsFixed(4) ?? '0.0000'} S256',
              style: const TextStyle(fontFamily: S256Theme.mono, color: S256Colors.textLight, fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              '${walletProvider.pendingTransactionsCount} transaction'
              '${walletProvider.pendingTransactionsCount > 1 ? 's' : ''} pending. '
              'The balance updates after confirmation.',
              style: const TextStyle(color: S256Colors.textLight, fontSize: 12),
            ),
          ],
          const SizedBox(height: 20),
          if (history.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.show_chart, size: 40, color: S256Colors.lineStrong),
                    SizedBox(height: 8),
                    Text(
                      'No activity yet',
                      style: TextStyle(color: S256Colors.text, fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Your balance chart will appear here',
                      style: TextStyle(color: S256Colors.textLight, fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else
            BalanceChart(history: history, height: 150),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final blockchainProvider = Provider.of<BlockchainProvider>(context);
    final walletProvider = Provider.of<WalletProvider>(context);

    // Get data from providers
    final String timestamp = blockchainProvider.timestamp;
    final List<dynamic> transactions = blockchainProvider.transactions;

    // Use displayBalance for UI (this shows pending balance when available)
    final double? displayBalance = walletProvider.displayBalance;
    final double? confirmedBalance = walletProvider.balance;
    final bool hasPending = walletProvider.hasPendingTransactions;
    final double? price = blockchainProvider.price;

    return Scaffold(
      body: RefreshIndicator(
        backgroundColor: S256Colors.surface2,
        color: S256Colors.accent,
        strokeWidth: 3,
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - kBottomNavigationBarHeight,
            ),
            child: AppBackground(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    children: [
                      const StatusStrip(),
                      const SizedBox(height: 16),
                      if (blockchainProvider.isLoading || walletProvider.isLoading) ...[
                        const WalletBalanceSkeleton(),
                        // Action Buttons Skeleton
                        Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: SkeletonLoader(
                                  width: double.infinity,
                                  height: 48,
                                  borderRadius: S256Theme.borderRadius,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SkeletonLoader(
                                  width: double.infinity,
                                  height: 48,
                                  borderRadius: S256Theme.borderRadius,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Transactions Section Skeleton
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: SilverCard(
                            padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SkeletonLoader(
                                width: 150,
                                height: 20,
                                borderRadius: S256Theme.borderRadius,
                              ),
                              const SizedBox(height: 12),
                              ...List.generate(3, (index) => const TransactionSkeleton()),
                            ],
                          ),
                        ),
                        ),
                      ] else ...[
                        // Balance card: brackets, platinum figures, price and chart
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildBalanceCard(
                            blockchainProvider,
                            walletProvider,
                            transactions,
                            displayBalance,
                            confirmedBalance,
                            hasPending,
                            price,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'LAST SYNC $timestamp'.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: S256Theme.mono,
                            color: S256Colors.textLight,
                            fontSize: 10,
                            letterSpacing: 1,
                          ),
                        ),

                        // Action Buttons
                        Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: ButtonWidget(
                                  text: 'Send',
                                  isPrimary: true,
                                  icon: Icons.arrow_upward,
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const SendView(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ButtonWidget(
                                  text: 'Receive',
                                  isPrimary: false,
                                  icon: Icons.arrow_downward,
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const ReceiveView(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Transactions Section
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: SilverCard(
                            padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const HudLabel('Recent transactions'),
                                  if (hasPending)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: S256Colors.primary.withValues(alpha: 0.2),
                                        borderRadius: S256Theme.borderRadius,
                                      ),
                                      child: Text(
                                        '${walletProvider.pendingTransactionsCount} pending',
                                        style: const TextStyle(
                                          color: S256Colors.primary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Show pending transactions first if any
                              if (hasPending) ...[
                                ...walletProvider.pendingTransactionsList.map((pendingTx) =>
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: S256Colors.primary.withValues(alpha: 0.1),
                                        borderRadius: S256Theme.borderRadius,
                                        border: Border.all(
                                          color: S256Colors.primary.withValues(alpha: 0.2),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: S256Colors.primary.withValues(alpha: 0.2),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.arrow_upward,
                                              color: S256Colors.primary,
                                              size: 16,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Sent to ${pendingTx.toAddress.substring(0, 8)}...${pendingTx.toAddress.substring(pendingTx.toAddress.length - 6)}',
                                                  style: const TextStyle(
                                                    color: S256Colors.text,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Pending confirmation',
                                                  style: TextStyle(
                                                    color: S256Colors.primary.withValues(alpha: 0.8),
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                '-${pendingTx.amount.toStringAsFixed(4)}',
                                                style: const TextStyle(
                                                  color: S256Colors.primary,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                'S256',
                                                style: TextStyle(
                                                  color: S256Colors.primary.withValues(alpha: 0.6),
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                ),
                                if (transactions.isNotEmpty)
                                  const Divider(color: S256Colors.line, height: 20),
                              ],

                              if (transactions.isEmpty && !hasPending)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 24),
                                  child: EmptyState(
                                    icon: Icons.receipt_long_outlined,
                                    title: 'No Transactions Yet',
                                    message: 'Receive S256 to get started with your wallet',
                                    actionText: 'Receive S256',
                                    onAction: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const ReceiveView(),
                                        ),
                                      );
                                    },
                                  ),
                                ),

                              if (transactions.isNotEmpty) ...[
                                ...transactions.take(5).map((tx) => TransactionTile(
                                  tx: tx,
                                  onTap: () => _showTransactionDetails(tx['txid']),
                                )),

                                if (transactions.length > 5)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: ButtonWidget(
                                        text: 'View more Transactions',
                                        isPrimary: false,
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => const TransactionsView(),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}