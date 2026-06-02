class Config {
  static const String addressPrefix = 's2';
  static const int networkPrefix = 0xBF;

  // RPC Configuration
  // S256 RPC is publicly accessible at https://sha256coin.eu/rpc (no authentication required)
  // Can be overridden during build with dart-define:
  // flutter build --dart-define=RPC_URL=https://custom-rpc.com/rpc
  static const String rpcUrl = String.fromEnvironment('RPC_URL', defaultValue: 'https://sha256coin.eu/rpc');
  static const String rpcUser = String.fromEnvironment('RPC_USER', defaultValue: '');
  static const String rpcPassword = String.fromEnvironment('RPC_PASSWORD', defaultValue: '');

  // Explorer API Configuration
  static const String explorerUrl = 'https://explorer.sha256coin.eu';
  static const String getAddressTxsEndpoint = '/ext/getaddresstxs';
  static const String getTxEndpoint = '/ext/gettx';

  // S256 explorer price api
  static const String s256ExplorerUrl = 'https://explorer.sha256coin.eu/api/price';
}
