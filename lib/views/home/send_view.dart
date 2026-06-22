import 'dart:async';

import 'package:flutter/material.dart';
import 'package:s256_wallet/widgets/app_background.dart';
import 'package:provider/provider.dart';
import 'package:s256_wallet/providers/wallet_provider.dart';
import 'package:s256_wallet/views/home/scanner_view.dart';
import 'package:s256_wallet/widgets/button_widget.dart';

class SendView extends StatefulWidget {
  const SendView({super.key});

  @override
  State<SendView> createState() => _SendViewState();
}

class _SendViewState extends State<SendView> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  bool _isChecked = false;
  bool _advancedSend = false;
  bool? _addressValid;
  bool _isValidatingAddress = false;
  Timer? _addressDebounce;
  String _errorMessage = '';
  bool _isSending = false;
  final double _estimatedFee = 0.00001; // Default fee estimate

  @override
  void initState() {
    super.initState();
    // Fetch fresh balance on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshBalance();
      Provider.of<WalletProvider>(context, listen: false).fetchFeeRate();
    });
  }

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    _addressDebounce?.cancel();
    super.dispose();
  }

  Future<void> _refreshBalance() async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    await walletProvider.fetchUtxos(force: true);
  }

  void _setMaxAmount() {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final balance = _advancedSend && walletProvider.selectedUtxoCount > 0
        ? walletProvider.selectedUtxoTotal
        : (walletProvider.balance ?? 0.0);

    // Leave some for fees (rough estimate)
    final maxAmount = balance > _estimatedFee ? balance - _estimatedFee : 0.0;

    setState(() {
      _amountController.text = maxAmount.toStringAsFixed(8);
      _errorMessage = '';
    });
  }

  /// Parses a BIP21-style URI (e.g., sha256coin:ADDRESS?amount=X&label=Y)
  /// Returns a map with 'address', 'amount', and 'label' fields
  Map<String, String?> _parsePaymentUri(String input) {
    String address = input.trim();
    String? amount;
    String? label;

    // Check if it's a BIP21-style URI
    if (address.toLowerCase().startsWith('sha256coin:')) {
      // Remove the protocol prefix
      address = address.substring('sha256coin:'.length);

      // Split address from query parameters
      final questionMarkIndex = address.indexOf('?');
      if (questionMarkIndex != -1) {
        final queryString = address.substring(questionMarkIndex + 1);
        address = address.substring(0, questionMarkIndex);

        // Parse query parameters
        final params = Uri.splitQueryString(queryString);
        amount = params['amount'];
        label = params['label'] ?? params['message'];
      }
    }

    return {
      'address': address,
      'amount': amount,
      'label': label,
    };
  }

  bool _isValidS256Address(String address) {
    final trimmed = address.trim();

    // Bech32 (native segwit)
    if (trimmed.toLowerCase().startsWith('s21')) {
      if (trimmed.length < 42 || trimmed.length > 62) {
        return false;
      }
      final validBech32 = RegExp(r'^s21[ac-hj-np-z02-9]+$');
      return validBech32.hasMatch(trimmed.toLowerCase());
    }

    // Legacy Base58 (S... P2PKH / 8... P2SH)
    if (trimmed.startsWith('S') || trimmed.startsWith('8')) {
      if (trimmed.length < 26 || trimmed.length > 50) {
        return false;
      }
          final validBase58Chars = RegExp(r'^[123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz]+');
          final hasInvalidChar = RegExp(r'[^123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz]')
            .hasMatch(trimmed);
          return validBase58Chars.hasMatch(trimmed) && !hasInvalidChar;
    }

    return false;
  }

  bool _validateInputs() {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);

    // Check address
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the recipient address.';
      });
      return false;
    }

    final validatedByRpc = _addressValid == true;
    if (!validatedByRpc && !_isValidS256Address(address)) {
      setState(() {
        _errorMessage =
            'Invalid address format. Use s21... or legacy S.../8... addresses.';
      });
      return false;
    }

    // Check amount
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() {
        _errorMessage = 'Please enter a valid amount.';
      });
      return false;
    }

    // Check balance
    final balance = _advancedSend && walletProvider.selectedUtxoCount > 0
        ? walletProvider.selectedUtxoTotal
        : (walletProvider.balance ?? 0.0);
    if (amount > balance) {
      setState(() {
        _errorMessage = 'Insufficient balance. Available: ${balance.toStringAsFixed(8)} S256';
      });
      return false;
    }

    // Check for minimum amount (dust threshold)
    if (amount < 0.00000546) {
      setState(() {
        _errorMessage = 'Amount is below minimum (0.00000546 S256).';
      });
      return false;
    }

    // Allow spending explicitly selected confirmed UTXOs in advanced mode,
    // even if other transactions are pending in mempool.
    final bypassPendingGate =
        _advancedSend && walletProvider.selectedUtxoCount > 0;

    // Check if there are pending transactions
    if (walletProvider.hasPendingTransactions && !bypassPendingGate) {
      setState(() {
        _errorMessage = 'Please wait for pending transactions to confirm.';
      });
      return false;
    }

    // Check UTXOs
    if (walletProvider.utxos == null || walletProvider.utxos!.isEmpty) {
      setState(() {
        _errorMessage = 'No confirmed UTXOs available. Please wait for confirmations.';
      });
      return false;
    }

    if (_advancedSend &&
        walletProvider.selectedUtxoCount > 0 &&
        amount > walletProvider.selectedUtxoTotal) {
      setState(() {
        _errorMessage =
            'Exceeds selected inputs (${walletProvider.selectedUtxoTotal.toStringAsFixed(8)} S256).';
      });
      return false;
    }

    // Check confirmation checkbox
    if (!_isChecked) {
      setState(() {
        _errorMessage = 'Please confirm the transaction details.';
      });
      return false;
    }

    setState(() {
      _errorMessage = '';
    });
    return true;
  }

  Future<void> _send() async {
    if (!_validateInputs()) {
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = '';
    });

    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final address = _addressController.text.trim();
    final amount = double.parse(_amountController.text);
    final selectedUtxos = _advancedSend && walletProvider.selectedUtxoCount > 0
      ? walletProvider.selectedUtxoList
      : null;

    try {
      // First attempt to send
      final result = await walletProvider.sendTransaction(
        address,
        amount,
        preSelectedUtxos: selectedUtxos,
      );

      if (result['success'] == true) {
        // Success!
        if (mounted) {
          _showSuccessDialog(result['txid'] ?? '', result['fee'] ?? 0.0);
        }

        // Clear form
        setState(() {
          _addressController.clear();
          _amountController.clear();
          _isChecked = false;
          _errorMessage = '';
        });

        // Refresh balance after a delay
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            _refreshBalance();
          }
        });

        return;
      }

      // Handle insufficient fee error
      if (result['suggestedFeeRate'] != null) {
        final suggestedFeeRate = result['suggestedFeeRate'] as double;
        final currentFeeRate = result['currentFeeRate'] ?? 0.00001;

        if (mounted) {
          final shouldRetry = await _showFeeDialog(currentFeeRate, suggestedFeeRate);

          if (shouldRetry) {
            // Retry with suggested fee rate
            setState(() {
              _errorMessage = 'Retrying with higher fee...';
            });

            final retryResult = await walletProvider.sendTransaction(
              address,
              amount,
              feeRate: suggestedFeeRate + 0.00000001, // Add small bump to ensure acceptance
            );

            if (retryResult['success'] == true) {
              if (mounted) {
                _showSuccessDialog(retryResult['txid'] ?? '', retryResult['fee'] ?? 0.0);
              }

              // Clear form
              setState(() {
                _addressController.clear();
                _amountController.clear();
                _isChecked = false;
                _advancedSend = false;
                _addressValid = null;
                _errorMessage = '';
              });

              walletProvider.resetCoinControl();

              return;
            } else {
              // Retry failed
              setState(() {
                _errorMessage = retryResult['message'] ?? 'Transaction failed';
              });
            }
          } else {
            // User declined to retry
            setState(() {
              _errorMessage = 'Transaction cancelled. The network requires a higher fee.';
            });
          }
        }
      } else {
        // Other error
        setState(() {
          _errorMessage = result['message'] ?? 'Transaction failed';
        });
      }

    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  Future<bool> _showFeeDialog(double currentFee, double suggestedFee) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color.fromARGB(255, 25, 25, 25),
          title: const Text(
            'Network Fee Required',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The network requires a higher fee for this transaction.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              Text(
                'Current fee rate: ${currentFee.toStringAsFixed(8)} S256/kvB',
                style: const TextStyle(color: Colors.white60),
              ),
              Text(
                'Required fee rate: ${suggestedFee.toStringAsFixed(8)} S256/kvB',
                style: const TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 16),
              const Text(
                'You can either:',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Retry with the higher fee (recommended)', style: TextStyle(color: Colors.white60)),
              const Text('• Wait 20-30 minutes for network conditions to improve', style: TextStyle(color: Colors.white60)),
              const Text('• Cancel and try again later', style: TextStyle(color: Colors.white60)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: S256Colors.accent,
                foregroundColor: Colors.black,
              ),
              child: const Text('Retry with Higher Fee'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  void _showSuccessDialog(String txid, double fee) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color.fromARGB(255, 25, 25, 25),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 8),
              Text('Transaction Sent!', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your transaction has been broadcast to the network.',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (txid.isNotEmpty) ...[
                const Text('Transaction ID:', style: TextStyle(color: Colors.white60, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                SelectableText(
                  txid,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: S256Colors.accent),
                ),
                const SizedBox(height: 16),
              ],
              Text('Network fee: ${fee.toStringAsFixed(8)} S256', style: const TextStyle(color: Colors.white60)),
              const SizedBox(height: 8),
              const Text(
                'Please wait for network confirmations.',
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.white54),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Go back to home
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: S256Colors.accent,
                foregroundColor: Colors.black,
              ),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _setAdvancedMode(bool enabled) {
    final provider = Provider.of<WalletProvider>(context, listen: false);
    setState(() {
      _advancedSend = enabled;
      _errorMessage = '';
    });
    if (enabled) {
      provider.fetchUtxosForCoinControl();
    } else {
      provider.resetCoinControl();
    }
  }

  void _syncAmountToSelection(WalletProvider provider) {
    if (!_advancedSend) return;
    final total = provider.selectedUtxoTotal;
    setState(() {
      _amountController.text = total > 0 ? total.toStringAsFixed(8) : '';
    });
  }

  String? _amountError(WalletProvider provider) {
    final text = _amountController.text.trim();
    if (text.isEmpty) return null;
    final value = double.tryParse(text);
    if (value == null) return 'Invalid number';
    if (value <= 0) return 'Amount must be greater than zero';
    if (value < 0.00000546) {
      return 'Amount below dust threshold (0.00000546 S256)';
    }
    if (_advancedSend &&
        provider.selectedUtxoCount > 0 &&
        value > provider.selectedUtxoTotal) {
      return 'Exceeds selected inputs (${provider.selectedUtxoTotal.toStringAsFixed(8)} S256)';
    }
    if (!_advancedSend && value > (provider.balance ?? 0)) {
      return 'Exceeds available balance';
    }
    return null;
  }

  Future<void> _validateAddressFromRpc(String value) async {
    _addressDebounce?.cancel();
    setState(() {
      _addressValid = null;
      _isValidatingAddress = value.trim().isNotEmpty;
    });

    if (value.trim().isEmpty) {
      setState(() {
        _isValidatingAddress = false;
      });
      return;
    }

    _addressDebounce = Timer(const Duration(milliseconds: 700), () async {
      final provider = Provider.of<WalletProvider>(context, listen: false);
      final rpcValid = await provider.validateAddress(value.trim());
      final localValid = _isValidS256Address(value.trim());
      final valid = rpcValid || localValid;
      if (!mounted) return;
      setState(() {
        _addressValid = valid;
        _isValidatingAddress = false;
      });
    });
  }

  Widget _buildUtxoSelector(WalletProvider provider) {
    if (provider.isLoadingUtxos) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            CircularProgressIndicator(color: S256Colors.accent),
            SizedBox(height: 12),
            Text('Scanning UTXOs...', style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    if (provider.availableUtxos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white10),
        ),
        child: const Text(
          'No confirmed UTXOs found.',
          style: TextStyle(color: Colors.white54),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Select Inputs (${provider.availableUtxos.length})',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    provider.selectAllUtxos();
                    _syncAmountToSelection(provider);
                  },
                  child: const Text('All'),
                ),
                TextButton(
                  onPressed: () {
                    provider.clearUtxoSelection();
                    _syncAmountToSelection(provider);
                  },
                  child: const Text('None'),
                ),
              ],
            )
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 260,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child: ListView.builder(
            itemCount: provider.availableUtxos.length,
            itemBuilder: (context, index) {
              final utxo = provider.availableUtxos[index];
              final key = '${utxo['txid']}:${utxo['vout']}';
              final isSelected = provider.selectedUtxoKeys.contains(key);
              final txid = utxo['txid'] as String;
              final txidShort =
                  '${txid.substring(0, 8)}...${txid.substring(txid.length - 6)}:${utxo['vout']}';

              return InkWell(
                onTap: () {
                  provider.toggleUtxo(key);
                  _syncAmountToSelection(provider);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.amber.withValues(alpha: 0.08)
                        : Colors.transparent,
                    border: Border(
                      bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          txidShort,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white60,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          (utxo['amount'] as num).toStringAsFixed(8),
                          style: const TextStyle(fontSize: 12, color: Colors.white),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text(
                          '${utxo['confirmations']}',
                          style: const TextStyle(fontSize: 12, color: Colors.white54),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(
                        width: 36,
                        child: Checkbox(
                          value: isSelected,
                          onChanged: (_) {
                            provider.toggleUtxo(key);
                            _syncAmountToSelection(provider);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        )
      ],
    );
  }

  Widget _buildFeeEstimate(WalletProvider provider) {
    final fee = _advancedSend && provider.selectedUtxoCount > 0
        ? provider.estimatedFee
        : provider.estimatedSimpleFee;
    final net = provider.estimatedNetSend;
    if (fee <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Estimated fee: ${fee.toStringAsFixed(8)} S256',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          if (_advancedSend && provider.selectedUtxoCount > 0)
            Text(
              net > 0 ? 'Net: ${net.toStringAsFixed(8)}' : 'Net: -',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _buildSendPreview(WalletProvider provider) {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final fee = _advancedSend && provider.selectedUtxoCount > 0
        ? provider.estimatedFee
        : provider.estimatedSimpleFee;

    final hasSelectedInputs = _advancedSend && provider.selectedUtxoCount > 0;
    final selectedInputs = hasSelectedInputs ? provider.selectedUtxoTotal : 0.0;
    final expectedChange = hasSelectedInputs
        ? (selectedInputs - amount - fee) > 0
            ? (selectedInputs - amount - fee)
            : 0.0
        : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Transaction Preview',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Selected Inputs', style: TextStyle(color: Colors.white60, fontSize: 12)),
              Text(
                hasSelectedInputs
                    ? '${selectedInputs.toStringAsFixed(8)} S256'
                    : 'Auto',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Send Amount', style: TextStyle(color: Colors.white60, fontSize: 12)),
              Text(
                '${amount.toStringAsFixed(8)} S256',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Estimated Fee', style: TextStyle(color: Colors.white60, fontSize: 12)),
              Text(
                '${fee.toStringAsFixed(8)} S256',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Expected Change', style: TextStyle(color: Colors.white60, fontSize: 12)),
              Text(
                expectedChange == null
                    ? 'Auto'
                    : '${expectedChange.toStringAsFixed(8)} S256',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Send S256',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _isSending ? null : _refreshBalance,
            tooltip: 'Refresh Balance',
          ),
        ],
      ),
      body: Container(
        color: Colors.black,
        constraints: const BoxConstraints.expand(),
        child: Consumer<WalletProvider>(
          builder: (context, walletProvider, child) {
            final amountErr = _amountError(walletProvider);
            return Stack(
              children: [
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 32.0, left: 16.0, right: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Balance Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Available Balance',
                                style: TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${walletProvider.balance?.toStringAsFixed(8) ?? '0.00000000'} S256',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (walletProvider.hasPendingTransactions) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.access_time, color: Colors.orange, size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${walletProvider.pendingTransactionsCount} pending',
                                        style: const TextStyle(color: Colors.orange, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Recipient Address Field
                        TextField(
                          controller: _addressController,
                          onChanged: _validateAddressFromRpc,
                          enabled: !_isSending,
                          decoration: InputDecoration(
                            labelText: 'Recipient Address (s21...)',
                            labelStyle: const TextStyle(color: Colors.white70),
                            hintText: 's21q...',
                            hintStyle: const TextStyle(color: Colors.white30),
                            errorText: _addressValid == false ? 'Invalid address' : null,
                            filled: true,
                            fillColor: Colors.black,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                              borderSide: const BorderSide(color: Colors.white, width: 1.0),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                              borderSide: const BorderSide(color: S256Colors.accent, width: 1.0),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                              borderSide: const BorderSide(color: Colors.white24, width: 1.0),
                            ),
                            suffixIcon: _isValidatingAddress
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_addressValid != null)
                                        Icon(
                                          _addressValid! ? Icons.check_circle : Icons.cancel,
                                          color: _addressValid! ? Colors.green : Colors.red,
                                        ),
                                      IconButton(
                                        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                                        onPressed: _isSending
                                            ? null
                                            : () async {
                                                final scannedValue = await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => const ScannerView(),
                                                  ),
                                                );
                                                if (scannedValue != null) {
                                                  final parsed = _parsePaymentUri(scannedValue);
                                                  setState(() {
                                                    _addressController.text = parsed['address'] ?? '';
                                                    if (parsed['amount'] != null &&
                                                        parsed['amount']!.isNotEmpty) {
                                                      _amountController.text = parsed['amount']!;
                                                    }
                                                    _errorMessage = '';
                                                  });
                                                  _validateAddressFromRpc(_addressController.text);
                                                }
                                              },
                                      ),
                                    ],
                                  ),
                          ),
                          style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                        ),
                        const SizedBox(height: 12),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Mode',
                              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                            ),
                            ToggleButtons(
                              isSelected: [!_advancedSend, _advancedSend],
                              onPressed: _isSending
                                  ? null
                                  : (index) => _setAdvancedMode(index == 1),
                              borderRadius: BorderRadius.circular(8),
                              selectedColor: Colors.black,
                              fillColor: S256Colors.accent,
                              color: Colors.white70,
                              children: const [
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text('Simple'),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text('Advanced'),
                                ),
                              ],
                            ),
                          ],
                        ),

                        if (_advancedSend) ...[
                          const SizedBox(height: 16),
                          _buildUtxoSelector(walletProvider),
                        ],

                        const SizedBox(height: 16),

                        // Amount Field
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _amountController,
                                enabled: !_isSending,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'Amount (S256)',
                                  labelStyle: const TextStyle(color: Colors.white70),
                                  errorText: amountErr,
                                  filled: true,
                                  fillColor: Colors.black,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                    borderSide: const BorderSide(color: Colors.white, width: 1.0),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                    borderSide: const BorderSide(color: S256Colors.accent, width: 1.0),
                                  ),
                                  disabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                    borderSide: const BorderSide(color: Colors.white24, width: 1.0),
                                  ),
                                ),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ButtonWidget(
                              text: 'Max',
                              isPrimary: false,
                              onPressed: _isSending ? null : _setMaxAmount,
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),
                        _buildFeeEstimate(walletProvider),

                        // Error Message
                        if (_errorMessage.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 10),

                        // Information Text
                        const Text(
                          'To send S256, enter the recipient\'s s21 address and the amount. Ensure you have enough balance to cover the transaction fee.',
                          style: TextStyle(color: Colors.white54),
                        ),

                        const SizedBox(height: 12),

                        _buildSendPreview(walletProvider),

                        const SizedBox(height: 16),

                        // Confirmation Checkbox
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Checkbox(
                              value: _isChecked,
                              onChanged: _isSending ? null : (bool? value) {
                                setState(() {
                                  _isChecked = value ?? false;
                                  if (_isChecked) {
                                    _errorMessage = '';
                                  }
                                });
                              },
                              checkColor: Colors.black,
                              activeColor: Colors.white,
                            ),
                            const Expanded(
                              child: Text(
                                'I confirm that the details are correct',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Send Button
                        ButtonWidget(
                          text: _isSending ? 'Sending...' : 'Send Transaction',
                          isPrimary: true,
                          onPressed: _isSending ||
                                  amountErr != null ||
                                  _isValidatingAddress ||
                                  _addressController.text.trim().isEmpty ||
                                (_addressValid == false &&
                                  !_isValidS256Address(_addressController.text.trim()))
                              ? null
                              : _send,
                        ),

                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.gavel_rounded, color: Colors.blue, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Regulatory notice: This non-custodial wallet does not provide financial advice. You are fully responsible for address verification and transaction decisions.',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.78),
                                    fontSize: 11,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),

                // Loading Overlay
                if (walletProvider.isLoading || _isSending)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: S256Colors.accent),
                          SizedBox(height: 16),
                          Text(
                            'Processing...',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}