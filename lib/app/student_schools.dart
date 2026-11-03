import '../core/studafy_domain.dart';
import '../features/academic/domain/academic_repository.dart';
import '../features/classes/application/class_list_interactor.dart';

/// The schools a student's tabs are read from, as one value: it changes when
/// they join a class in another teacher's school (each teacher's workspace
/// is a school of its own), and the shell then reads its tabs again so the
/// new class shows beside the ones they had.
String studentSchoolsKey() =>
    ActiveContextController.instance.schoolIds.join(',');

/// Supplies the Work tab's class filter: every class the student is in, from
/// every teacher's school. Kept in the app layer because only it may reach
/// across features.
Future<List<ClassChoice>> classChoicesOf(ClassListInteractor? classes) async {
  if (classes == null) return const [];
  final result = await classes.loadClasses();
  return result.fold(
    onSuccess: (items) => [
      for (final item in items) ClassChoice(id: item.id.value, name: item.name),
    ],
    onFailure: (_) => const [],
  );
}
