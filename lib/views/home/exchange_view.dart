import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:s256_wallet/providers/blockchain_provider.dart';
import 'package:s256_wallet/providers/wallet_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:s256_wallet/widgets/app_background.dart';

class ExchangeView extends StatefulWidget {
  const ExchangeView({super.key});

  @override
  State<ExchangeView> createState() => _ExchangeViewState();
}

class _ExchangeViewState extends State<ExchangeView> with TickerProviderStateMixin {
  double? _moneySupply;
  bool _isLoadingSupply = false;

  // Volume data for exchanges
  String? _klingexVolume;
  String? _rabidRabbitVolume;

  // Animation controllers
  late AnimationController _logoAnimationController;
  late AnimationController _shimmerController;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotateAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _logoAnimationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _shimmerController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _logoScaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: Curves.elasticOut,
    ));

    _logoRotateAnimation = Tween<double>(
      begin: -0.1,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: Curves.easeInOut,
    ));

    _logoAnimationController.forward();

    // Fetch price, money supply and volumes on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final blockchainProvider = Provider.of<BlockchainProvider>(context, listen: false);
      blockchainProvider.fetchPrice();
      _fetchMoneySupply();
      _fetchAllVolumes();
    });
  }

  @override
  void dispose() {
    _logoAnimationController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllVolumes() async {
    _fetchKlingexVolume();
    _fetchRabidRabbitVolume();
  }

  Future<void> _fetchMoneySupply() async {
    if (_isLoadingSupply) return;

    setState(() {
      _isLoadingSupply = true;
    });

    try {
      final response = await http.get(
        Uri.parse('https://explorer.sha256coin.eu/ext/getmoneysupply'),
        headers: {'Accept': 'application/json'},
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        final responseBody = response.body.trim();
        final supply = double.tryParse(responseBody);
        if (supply != null) {
          setState(() {
            _moneySupply = supply;
          });
        } else {
          try {
            final data = jsonDecode(responseBody);
            if (data is num) {
              setState(() {
                _moneySupply = data.toDouble();
              });
            } else if (data is Map && data.containsKey('moneysupply')) {
              setState(() {
                _moneySupply = double.tryParse(data['moneysupply'].toString());
              });
            }
          } catch (e) {
            debugPrint('Error parsing money supply JSON: $e');
          }
        }
      } else {
        debugPrint('Money supply fetch failed with status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching money supply: $e');
      setState(() {
        _moneySupply = 100000000; // 100M fallback
      });
    } finally {
      setState(() {
        _isLoadingSupply = false;
      });
    }
  }

  Future<void> _fetchKlingexVolume() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.klingex.io/api/tickers'),
        headers: {'Accept': 'application/json'},
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> tickers = jsonDecode(response.body);

        // Find the S256_USDT pair in the list
        final s256Ticker = tickers.firstWhere(
              (ticker) => ticker['ticker_id'] == 'S256_USDT',
          orElse: () => null,
        );

        if (s256Ticker != null) {
          // target_volume is USDT volume
          final usdtVolume = double.tryParse(s256Ticker['target_volume'].toString()) ?? 0.0;

          setState(() {
            if (usdtVolume > 0) {
              _klingexVolume = '\$${usdtVolume.toStringAsFixed(2)}';
            } else {
              _klingexVolume = 'Low Volume';
            }
          });
        } else {
          setState(() {
            _klingexVolume = 'Data unavailable';
          });
        }
      } else {
        setState(() {
          _klingexVolume = 'Data unavailable';
        });
      }
    } catch (e) {
      debugPrint('Error fetching KlingEx volume: $e');
      setState(() {
        _klingexVolume = 'Trade Now';
      });
    }
  }

  Future<void> _fetchRabidRabbitVolume() async {
    try {
      final response = await http.get(
        Uri.parse('https://rabid-rabbit.org/api/public/v1/ticker?format=json'),
        headers: {'Accept': 'application/json'},
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> tickers = jsonDecode(response.body);

        // Find the S256_USDT pair
        final s256Ticker = tickers['S256_USDT'];

        if (s256Ticker != null) {
          // quote_volume is USDT volume
          final usdtVolume = double.tryParse(s256Ticker['quote_volume'].toString()) ?? 0.0;

          setState(() {
            if (usdtVolume > 0) {
              _rabidRabbitVolume = '\$${usdtVolume.toStringAsFixed(2)}';
            } else {
              _rabidRabbitVolume = 'Low Volume';
            }
          });
        } else {
          setState(() {
            _rabidRabbitVolume = 'Data unavailable';
          });
        }
      } else {
        setState(() {
          _rabidRabbitVolume = 'Data unavailable';
        });
      }
    } catch (e) {
      debugPrint('Error fetching Rabid Rabbit volume: $e');
      setState(() {
        _rabidRabbitVolume = 'Trade Now';
      });
    }
  }

  String _formatPrice(double price) {
    if (price < 0.01) {
      return '\$${price.toStringAsFixed(6)}';
    } else if (price < 1) {
      return '\$${price.toStringAsFixed(4)}';
    } else {
      return '\$${price.toStringAsFixed(2)}';
    }
  }

  String _formatMarketCap(double price, double? supply) {
    if (supply == null || price == 0) return '---';

    final marketCap = price * supply;
    if (marketCap >= 1000000000) {
      return '\$${(marketCap / 1000000000).toStringAsFixed(2)}B';
    } else if (marketCap >= 1000000) {
      return '\$${(marketCap / 1000000).toStringAsFixed(2)}M';
    } else if (marketCap >= 1000) {
      return '\$${(marketCap / 1000).toStringAsFixed(2)}K';
    } else {
      return '\$${marketCap.toStringAsFixed(2)}';
    }
  }

  String _formatSupply(double? supply) {
    if (supply == null) return '---';

    if (supply >= 1000000000) {
      return '${(supply / 1000000000).toStringAsFixed(2)}B';
    } else if (supply >= 1000000) {
      return '${(supply / 1000000).toStringAsFixed(2)}M';
    } else if (supply >= 1000) {
      return '${(supply / 1000).toStringAsFixed(2)}K';
    } else {
      return supply.toStringAsFixed(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blockchainProvider = Provider.of<BlockchainProvider>(context);
    final walletProvider = Provider.of<WalletProvider>(context);

    final double s256Price = blockchainProvider.price;
    final double? balance = walletProvider.balance;
    final String balanceInUSD = balance != null && s256Price > 0
        ? '\$${(balance * s256Price).toStringAsFixed(2)}'
        : '---';

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),

                  // Enhanced Logo Section
                  Center(
                    child: AnimatedBuilder(
                      animation: _logoAnimationController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _logoScaleAnimation.value,
                          child: Transform.rotate(
                            angle: _logoRotateAnimation.value,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Glowing background effect
                                Container(
                                  width: 160,
                                  height: 160,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        S256Colors.accent.withValues(alpha: 0.3),
                                        S256Colors.accent.withValues(alpha: 0.1),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.3, 0.6, 1.0],
                                    ),
                                  ),
                                ),

                                // Rotating ring
                                AnimatedBuilder(
                                  animation: _shimmerController,
                                  builder: (context, child) {
                                    return Transform.rotate(
                                      angle: _shimmerController.value * 2 * 3.14159,
                                      child: Container(
                                        width: 140,
                                        height: 140,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: SweepGradient(
                                            colors: [
                                              Colors.transparent,
                                              S256Colors.accent.withValues(alpha: 0.2),
                                              S256Colors.accent.withValues(alpha: 0.4),
                                              Colors.transparent,
                                            ],
                                            stops: const [0.0, 0.25, 0.5, 1.0],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),

                                // Main logo container
                                Container(
                                  padding: const EdgeInsets.all(25),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.black.withValues(alpha: 0.8),
                                        Colors.black.withValues(alpha: 0.6),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    border: Border.all(
                                      color: S256Colors.accent.withValues(alpha: 0.5),
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: S256Colors.accent.withValues(alpha: 0.5),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Image.asset(
                                    'assets/logo.png',
                                    height: 80,
                                    width: 80,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(
                                        Icons.currency_bitcoin,
                                        size: 80,
                                        color: S256Colors.accent,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 25),

                  // Title and Subtitle
                  SilverBorder(
                    borderWidth: 3,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [S256Colors.accent, Colors.white],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: const Text(
                          'S256 EXCHANGES',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Trade S256 on Premium Exchanges',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 15,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 30),

                  // Live Price Ticker
                  SilverCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildPriceInfo(
                              'S256 Price',
                              s256Price > 0 ? _formatPrice(s256Price) : '---',
                              isLoading: blockchainProvider.isLoading && s256Price == 0,
                            ),
                            Container(
                              height: 40,
                              width: 1,
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                            _buildPriceInfo(
                              'Your Balance',
                              balance != null
                                  ? '${balance.toStringAsFixed(4)} S256'
                                  : '---',
                            ),
                            Container(
                              height: 40,
                              width: 1,
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                            _buildPriceInfo(
                              'USD Value',
                              balanceInUSD,
                              isPositive: s256Price > 0,
                            ),
                          ],
                        ),
                        if (s256Price > 0 || _moneySupply != null) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Market Cap: ${_formatMarketCap(s256Price, _moneySupply)}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Supply: ${_formatSupply(_moneySupply)} S256',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Markets Header
                  SilverCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.show_chart,
                          color: S256Colors.accent,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Available Markets',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () {
                            blockchainProvider.fetchPrice();
                            _fetchMoneySupply();
                            _fetchAllVolumes();
                          },
                          icon: Icon(
                            Icons.refresh,
                            color: blockchainProvider.isLoading || _isLoadingSupply
                                ? Colors.white38
                                : Colors.white70,
                            size: 20,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Exchange Cards
                  _buildExchangeCard(
                    context,
                    name: 'Rabid Rabbit',
                    url: 'https://rabid-rabbit.org/account/trade/S256-USDT',
                    pair: 'S256/USDT',
                    volume: _rabidRabbitVolume != null
                        ? '24h Volume: $_rabidRabbitVolume'
                        : 'Loading volume...',
                    imageIcon: 'assets/images/RR_Logo.png',
                    isPrimary: true,
                    isNew: true,
                  ),

                  _buildExchangeCard(
                    context,
                    name: 'KlingEx',
                    url: 'https://klingex.io/trade/S256-USDT',
                    pair: 'S256/USDT',
                    volume: _klingexVolume != null
                        ? '24h Volume: $_klingexVolume'
                        : 'Loading volume...',
                    imageIcon: 'assets/images/klingex.png',
                    isNew: true,
                  ),

                  const SizedBox(height: 30),

                  // Info Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.blue,
                          size: 32,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Trading Information',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'S256 is listed on multiple exchanges. Click on any exchange above to start trading. Always ensure you\'re using the official exchange links.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
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
      ),
    );
  }

  Widget _buildExchangeCard(
      BuildContext context, {
        required String name,
        required String url,
        required String pair,
        required String volume,
        String? imageIcon,
        IconData? icon,
        bool isNew = false,
        bool isPrimary = false,
      }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => launchUrl(Uri.parse(url)),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: isPrimary
                  ? LinearGradient(
                colors: [
                  S256Colors.accent.withValues(alpha: 0.1),
                  Colors.transparent,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
                  : null,
              color: !isPrimary ? Colors.white.withValues(alpha: 0.05) : null,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isPrimary
                    ? S256Colors.accent.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.1),
                width: isPrimary ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                // Icon Container
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: imageIcon != null
                      ? Image.asset(
                          imageIcon,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: S256Colors.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            icon ?? Icons.currency_exchange,
                            color: S256Colors.accent,
                            size: 32,
                          ),
                        ),
                ),
                const SizedBox(width: 16),

                // Exchange Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: isPrimary ? FontWeight.w900 : FontWeight.bold,
                            ),
                          ),
                          if (isNew) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'NEW',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        volume,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // Pair and Arrow
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      pair,
                      style: const TextStyle(
                        color: S256Colors.accent,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white.withValues(alpha: 0.4),
                      size: 16,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriceInfo(
      String label,
      String value, {
        bool isPositive = false,
        bool isLoading = false,
      }) {
    Color valueColor = Colors.white;
    if (isPositive && value != '---') valueColor = S256Colors.accent;

    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        if (isLoading)
          const SizedBox(
            width: 50,
            height: 14,
            child: LinearProgressIndicator(
              color: S256Colors.accent,
              backgroundColor: Colors.white24,
            ),
          )
        else
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }
}
