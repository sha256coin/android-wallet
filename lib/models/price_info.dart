/// S256 market data from the explorer's /api/price, which reads it from
/// LiveCoinWatch (the API key stays on the server). Any field can be null:
/// LiveCoinWatch returns nothing for a coin it has no rate for.
class PriceInfo {
  final double? price;
  final double? volume;
  final double? cap;
  final double? liquidity;

  const PriceInfo({this.price, this.volume, this.cap, this.liquidity});

  static const PriceInfo none = PriceInfo();

  /// A usable price is above 0; anything else is shown as "no price".
  bool get hasPrice => price != null && price! > 0;

  factory PriceInfo.fromJson(Map<String, dynamic> json) {
    double? number(dynamic v) => v is num && v.isFinite && v >= 0 ? v.toDouble() : null;
    return PriceInfo(
      price: number(json['price']),
      volume: number(json['volume']),
      cap: number(json['cap']),
      liquidity: number(json['liquidity']),
    );
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
