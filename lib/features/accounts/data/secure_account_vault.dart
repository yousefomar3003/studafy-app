import 'dart:convert';

import '../../../core/secure_storage.dart';
import '../domain/device_account.dart';

/// The device's accounts, in the platform keystore beside the session.
///
/// One entry holds the list and the tokens together, so they can never
/// disagree, and so a token for an account no longer listed is dropped the
/// next time the list is written.
class SecureAccountVault implements AccountVault {
  SecureAccountVault(this._store);

  final SecureStore _store;

  static const _key = 'studafy.device_accounts.v1';

  @override
  Future<DeviceAccountList> read() async {
    final raw = await _store.read(_key);
    if (raw == null || raw.isEmpty) return const DeviceAccountList();
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return const DeviceAccountList();
      final accounts = [
        for (final item in json['accounts'] as List<dynamic>? ?? const [])
          ?DeviceAccount.fromJson(item),
      ];
      final tokens = <String, String>{
        for (final entry
            in (json['tokens'] as Map<String, dynamic>? ?? const {}).entries)
          if (entry.value is String) entry.key: entry.value as String,
      };
      return DeviceAccountList(accounts: accounts, tokens: tokens);
    } on FormatException {
      // Unreadable is empty: the person signs in again, nothing worse.
      return const DeviceAccountList();
    }
  }

  @override
  Future<void> write(DeviceAccountList list) async {
    if (list.accounts.isEmpty && list.tokens.isEmpty) {
      await _store.delete(_key);
      return;
    }
    await _store.write(
      _key,
      jsonEncode({
        'accounts': [for (final account in list.accounts) account.toJson()],
        'tokens': list.tokens,
      }),
    );
  }
}
