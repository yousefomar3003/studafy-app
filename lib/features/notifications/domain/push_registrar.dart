/// Registers this phone for push notifications for the account signed in,
/// and takes it off again when that account signs out of the device.
///
/// Each call acts as the account signed in at the time, and only for it:
/// registering another account on the same phone leaves the earlier ones
/// registered, so every account on the phone gets its pushes (DL-082). The
/// server also covers the child accounts a parent manages, which only ever
/// live on the parent's phones.
///
/// Push carries only fixed, content-free text ("You have a new message");
/// what it is about is read in the app. Nothing here ever throws: a phone
/// that cannot be registered simply gets no push, and the in-app
/// notifications still work.
abstract interface class PushRegistrar {
  /// Asks for permission if not yet asked, then registers the phone.
  Future<void> register();

  /// Removes this phone from the signed-in account (and the child accounts
  /// that leave with it), before it signs out. The phone's other accounts
  /// keep their registrations.
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
