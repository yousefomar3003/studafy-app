/// Registers this phone for push notifications for the account signed in,
/// and takes it off again when that account signs out of the device.
///
/// Push carries only fixed, content-free text ("You have a new message");
/// what it is about is read in the app. Nothing here ever throws: a phone
/// that cannot be registered simply gets no push, and the in-app
/// notifications still work.
abstract interface class PushRegistrar {
  /// Asks for permission if not yet asked, then registers the phone.
  Future<void> register();

  /// Removes this phone from the signed-in account, before it signs out.
  Future<void> unregister();
}

/// Builds with no push configured.
class NoPushRegistrar implements PushRegistrar {
  const NoPushRegistrar();

  @override
  Future<void> register() async {}

  @override
  Future<void> unregister() async {}
}
