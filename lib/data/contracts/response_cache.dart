/// Where API answers are kept on this device, for the account signed in.
///
/// The transport writes every answer it may keep and reads one back only
/// when the server cannot be reached, so a screen shows what it last showed
/// instead of an error. Kept per account and school, and erased at sign-out
/// (lib/data/local_cache/offline_response_cache.dart).
abstract interface class ResponseCache {
  Future<Map<String, dynamic>?> read(String key);
  Future<void> write(String key, Map<String, dynamic> body);
}
