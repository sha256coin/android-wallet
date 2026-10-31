/// S256 market data from the explorer's /api/price, which reads it from
/// LiveCoinWatch (the API key stays on the server). Any field can be null:
/// LiveCoinWatch returns nothing for a coin it has no rate for.
///
/// While no market trades S256 the explorer sends the last traded price and
/// [lastTraded], the time of that price. Then it is not a live price.
class PriceInfo {
  final double? price;
  final double? volume;
  final double? cap;
  final double? liquidity;

  /// When [price] was last traded, or null when it is a live price.
  final DateTime? lastTraded;

  const PriceInfo(
      {this.price, this.volume, this.cap, this.liquidity, this.lastTraded});

  static const PriceInfo none = PriceInfo();

  /// A usable price is above 0; anything else is shown as "no price".
  bool get hasPrice => price != null && price! > 0;

  /// The price is the last trade, not a live rate.
  bool get isLastTrade => hasPrice && lastTraded != null;

  factory PriceInfo.fromJson(Map<String, dynamic> json) {
    double? number(dynamic v) =>
        v is num && v.isFinite && v >= 0 ? v.toDouble() : null;
    return PriceInfo(
      price: number(json['price']),
      volume: number(json['volume']),
      cap: number(json['cap']),
      liquidity: number(json['liquidity']),
      lastTraded: switch (number(json['lastTraded'])) {
        final ms? =>
          DateTime.fromMillisecondsSinceEpoch(ms.toInt(), isUtc: true),
        _ => null,
      },
    );
  }

  /// "18 Oct 2026" (UTC).
  static String formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final d = date.toUtc();
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  /// Small prices keep more decimals: $0.000123, $0.0123, $1.23.
  static String formatUsd(double value) {
    if (value < 0.01) return '\$${value.toStringAsFixed(6)}';
    if (value < 1) return '\$${value.toStringAsFixed(4)}';
    return '\$${value.toStringAsFixed(2)}';
  }

  /// Large amounts as $1.2K, $3.4M, $5.6B.
  static String formatCompactUsd(double value) {
    if (value >= 1e9) return '\$${(value / 1e9).toStringAsFixed(2)}B';
    if (value >= 1e6) return '\$${(value / 1e6).toStringAsFixed(2)}M';
    if (value >= 1e3) return '\$${(value / 1e3).toStringAsFixed(2)}K';
    return '\$${value.toStringAsFixed(2)}';
  }
}
