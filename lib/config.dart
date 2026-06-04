class Config {
  static const String addressPrefix = 's2';
  static const int networkPrefix = 0xBF;

  // RPC Configuration
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
