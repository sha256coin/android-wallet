import 'package:flutter/material.dart';
import 'package:s256_wallet/theme/s256_theme.dart';
import 'package:intl/intl.dart';
import 'package:s256_wallet/widgets/app_background.dart';

class TransactionTile extends StatelessWidget {
  final dynamic tx;
  final VoidCallback onTap;

  const TransactionTile({super.key, required this.tx, required this.onTap});

  String _formatAmount(double amount) {
    // Smart formatting: remove trailing zeros but keep at least 4 decimals
    String formatted = amount.abs().toStringAsFixed(8);
    // Remove trailing zeros, but keep at least 4 decimal places
    while (formatted.contains('.') &&
           (formatted.endsWith('0') && formatted.split('.')[1].length > 4)) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
    return formatted;
  }

  @override
  Widget build(BuildContext context) {
    final amountValue = tx['amount'] as num;
    final amount = _formatAmount(amountValue.toDouble());
    final isReceived = amountValue > 0;
    final icon = isReceived ? Icons.arrow_downward : Icons.arrow_upward;
    final color = isReceived ? S256Colors.success : S256Colors.danger;
    int timestampInSeconds = tx['timestamp'];
    DateTime dateTime =
        DateTime.fromMillisecondsSinceEpoch(timestampInSeconds * 1000);

    final formattedDate = DateFormat('dd MMM yyyy HH:mm').format(dateTime);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: S256Colors.text.withValues(alpha: 0.05),
        borderRadius: S256Theme.borderRadius,
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          title: Row(
            children: [
              Text(
                isReceived ? '+' : '-',
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                amount,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'S256',
                style: TextStyle(
                  color: color.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          subtitle: Text(
            formattedDate,
            style: const TextStyle(color: S256Colors.textLight, fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right, color: S256Colors.textLight),
          onTap: onTap,
        ),
      ),
    );
  }
}
