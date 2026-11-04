import 'dart:async';

/// Reads [read] for every school in [schoolIds] at once and joins the
/// answers in that order.
///
/// A student holds one membership per teacher whose class they joined, since
/// each teacher's workspace is a school of its own. A school whose read
/// fails is left out rather than failing the rest: one teacher's workspace
/// being unreachable must not blank the others' classes and work. Only when
/// every school fails does the read fail, with the first school's error.
Future<List<T>> readEverySchool<T>(
  List<String> schoolIds,
  Future<List<T>> Function(String schoolId) read,
) async {
  if (schoolIds.length == 1) return read(schoolIds.single);
  final answers = await Future.wait([
    for (final schoolId in schoolIds)
      Future.sync(() => read(schoolId)).then<_Answer<T>>(
        (items) => _Answer(items),
        onError: (Object error, StackTrace stack) =>
            _Answer<T>(null, error, stack),
      ),
  ]);
  final loaded = [for (final a in answers) ?a.items];
  if (loaded.isEmpty && answers.isNotEmpty) {
    final first = answers.first;
    Error.throwWithStackTrace(first.error!, first.stack!);
  }
  return [for (final items in loaded) ...items];
}

class _Answer<T> {
  const _Answer(this.items, [this.error, this.stack]);

  final List<T>? items;
  final Object? error;
  final StackTrace? stack;
}
