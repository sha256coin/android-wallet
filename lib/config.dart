class Config {
  static const String addressPrefix = 's2';
  static const int networkPrefix = 0x80;

  // RPC Configuration
  // S256 RPC is publicly accessible at https://sha256coin.eu/rpc (no authentication required)
  // Can be overridden during build with dart-define:
  // flutter build --dart-define=RPC_URL=https://custom-rpc.com/rpc
  static const String rpcUrl = String.fromEnvironment('RPC_URL', defaultValue: 'https://sha256coin.eu/rpc');
  static const String rpcUser = String.fromEnvironment('RPC_USER', defaultValue: '');
  static const String rpcPassword = String.fromEnvironment('RPC_PASSWORD', defaultValue: '');

  // Explorer API Configuration
  // Explorer running at: https://explorer.sha256coin.eu
  // Endpoints implemented in server-mongodb.js:
  //   - /ext/getaddresstxs/:address/:start/:limit
  //   - /ext/gettx/:txid
  static const String explorerUrl = 'https://explorer.sha256coin.eu';
  static const String getAddressTxsEndpoint = '/ext/getaddresstxs';
  static const String getTxEndpoint = '/ext/gettx';

  // LiveCoinWatch API Configuration (disabled - S256 not listed yet)
  // static const String liveCoinWatchUrl = 'https://api.livecoinwatch.com/coins/single';
  // static const String liveCoinWatchApiKey = '4ec13b1b-7248-4d53-94a2-940017952f82';
  // static const String s256Code = '____S256';

  // Legacy price URL (disabled for S256)
  // static const String priceUrl = 'https://sha256coin.eu/api/';
}
