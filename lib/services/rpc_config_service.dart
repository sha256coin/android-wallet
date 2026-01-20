import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:s256_wallet/config.dart';

class RpcConfigService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _rpcUrlKey = 'rpc_url';
  static const String _rpcUserKey = 'rpc_user';
  static const String _rpcPasswordKey = 'rpc_password';

  // Initialize RPC credentials - should be called once on first app launch
  Future<void> initializeRpcCredentials() async {
    // Check if credentials are already stored
    final existingUrl = await _storage.read(key: _rpcUrlKey);

    if (existingUrl == null) {
      // First time - check if RPC URL is provided (user/password optional for public RPC)
      if (Config.rpcUrl.isNotEmpty) {
        // Store RPC URL from config
        await _storage.write(key: _rpcUrlKey, value: Config.rpcUrl);

        // Store user/password if provided (optional for public RPC)
        if (Config.rpcUser.isNotEmpty) {
          await _storage.write(key: _rpcUserKey, value: Config.rpcUser);
        }
        if (Config.rpcPassword.isNotEmpty) {
          await _storage.write(key: _rpcPasswordKey, value: Config.rpcPassword);
        }
      }
      // If RPC URL not set, credentials must be configured manually
      // via updateRpcCredentials() or through a setup UI
    }
  }

  // Check if RPC credentials are configured
  // For public RPC (sha256coin.eu/rpc), credentials are optional
  Future<bool> areCredentialsConfigured() async {
    final url = await _storage.read(key: _rpcUrlKey);

    // If URL is stored or available in Config, consider it configured
    if (url != null && url.isNotEmpty) return true;
    if (Config.rpcUrl.isNotEmpty) return true;

    return false;
  }

  // Get RPC URL
  Future<String> getRpcUrl() async {
    final url = await _storage.read(key: _rpcUrlKey);
    if (url != null && url.isNotEmpty) return url;
    if (Config.rpcUrl.isNotEmpty) return Config.rpcUrl;
    throw Exception('RPC URL not configured');
  }

  // Get RPC User
  // Returns empty string for public RPC endpoints that don't require auth
  Future<String> getRpcUser() async {
    final user = await _storage.read(key: _rpcUserKey);
    if (user != null && user.isNotEmpty) return user;
    // Return Config value even if empty (for public RPC)
    return Config.rpcUser;
  }

  // Get RPC Password
  // Returns empty string for public RPC endpoints that don't require auth
  Future<String> getRpcPassword() async {
    final password = await _storage.read(key: _rpcPasswordKey);
    if (password != null && password.isNotEmpty) return password;
    // Return Config value even if empty (for public RPC)
    return Config.rpcPassword;
  }

  // Update RPC credentials (for advanced users who want to use their own node)
  Future<void> updateRpcCredentials({
    required String url,
    required String user,
    required String password,
  }) async {
    await _storage.write(key: _rpcUrlKey, value: url);
    await _storage.write(key: _rpcUserKey, value: user);
    await _storage.write(key: _rpcPasswordKey, value: password);
  }

  // Clear RPC credentials (reset to defaults)
  Future<void> clearRpcCredentials() async {
    await _storage.delete(key: _rpcUrlKey);
    await _storage.delete(key: _rpcUserKey);
    await _storage.delete(key: _rpcPasswordKey);
  }

  // Check if custom RPC credentials are set
  Future<bool> hasCustomCredentials() async {
    final url = await _storage.read(key: _rpcUrlKey);
    return url != null;
  }
}
