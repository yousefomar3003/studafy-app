/// Synthetic-only identity bridge for legacy preview fixtures. Production
/// academic adapters derive student relationships from authenticated server
/// context and never send this integer.
abstract final class PreviewStudentIdentity {
  static const localId = 1;
}
