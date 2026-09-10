import 'failures.dart';

/// Result of an application use case. Success carries a value; failure
/// carries a stable machine code and a safe, presentable message. Internal
/// exception details never cross this boundary.
sealed class Result<T> {
  const Result();

  const factory Result.success(T value) = Success<T>;
  const factory Result.failure(Failure failure) = FailureResult<T>;

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is FailureResult<T>;

  /// Returns the value or rethrows the failure as a [ResultError].
  T get require => switch (this) {
    Success<T>(:final value) => value,
    FailureResult<T>(:final failure) => throw ResultError(failure),
  };

  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(Failure failure) onFailure,
  }) => switch (this) {
    Success<T>(:final value) => onSuccess(value),
    FailureResult<T>(:final failure) => onFailure(failure),
  };
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class FailureResult<T> extends Result<T> {
  const FailureResult(this.failure);
  final Failure failure;
}

/// Thrown by [Result.require] so boundary violations fail loudly in debug.
class ResultError extends Error {
  ResultError(this.failure);
  final Failure failure;

  @override
  String toString() => 'ResultError(${failure.code}: ${failure.message})';
}

/// Runs [action], converting any thrown error into a typed [Failure].
Future<Result<T>> runCatching<T>(Future<T> Function() action) async {
  try {
    return Result.success(await action());
  } on Failure catch (failure) {
    return Result.failure(failure);
  } catch (error) {
    return Result.failure(Failure.fromError(error));
  }
}
