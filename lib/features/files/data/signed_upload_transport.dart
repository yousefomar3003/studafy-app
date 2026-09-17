import 'dart:io';
import 'dart:typed_data';

abstract interface class SignedUploadTransport {
  Future<void> put({
    required Uri signedUrl,
    required Map<String, String> requiredHeaders,
    required Uint8List bytes,
  });
}

/// Sends bytes only to the complete server-issued capability. It never accepts
/// a bucket or object key and refuses redirects so the capability cannot leak.
class IoSignedUploadTransport implements SignedUploadTransport {
  IoSignedUploadTransport({HttpClient? client})
    : _client = client ?? HttpClient();

  final HttpClient _client;

  @override
  Future<void> put({
    required Uri signedUrl,
    required Map<String, String> requiredHeaders,
    required Uint8List bytes,
  }) async {
    if (signedUrl.scheme != 'https' && signedUrl.host != '127.0.0.1') {
      throw StateError('Signed upload URL must use HTTPS.');
    }
    final request = await _client.putUrl(signedUrl);
    request.followRedirects = false;
    requiredHeaders.forEach(request.headers.set);
    request.contentLength = bytes.length;
    request.add(bytes);
    final response = await request.close();
    await response.drain<void>();
    if (response.isRedirect ||
        response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw HttpException('Private upload failed.', uri: signedUrl);
    }
  }
}
