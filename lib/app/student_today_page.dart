import 'package:flutter/material.dart';

import '../core/studafy_design.dart';
import '../core/studafy_domain.dart';
import '../features/academic/domain/academic_repository.dart';
import '../features/classes/application/class_list_interactor.dart';
import '../features/classes/domain/classroom.dart';
import '../features/family/presentation/student_family_page.dart';
import '../features/notifications/presentation/notifications_page.dart';
import 'account_hub_page.dart';

class StudentTodayPage extends StatelessWidget {
  const StudentTodayPage({
    super.key,
    required this.academic,
    required this.onWork,
    required this.onNotebook,
    this.classes,
  });
  final AcademicRepository academic;
  final VoidCallback onWork;
  final VoidCallback onNotebook;

  /// Lists the classes this student is in. Optional so the preview shell,
  /// which has no class service behind it, still builds.
  final ClassListInteractor? classes;
  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    String t(String en, String arabic) => ar ? arabic : en;
    final name =
        ActiveContextController.instance.profile?.displayName
            .split(' ')
            .first ??
        '';
    return Scaffold(
      appBar: AppBar(
        title: const StudafyLogo(size: 28),
        actions: [
          IconButton(
            tooltip: t('Notifications', 'الإشعارات'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const NotificationsPage(),
              ),
            ),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const AccountButton(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          StudafyHero(
            eyebrow: t('A LITTLE PROGRESS, EVERY DAY', 'خطوة صغيرة كل يوم'),
            title: t(
              'Make today yours${name.isEmpty ? '' : ', $name'}.',
              'اجعل اليوم يومك${name.isEmpty ? '' : '، $name'}.',
            ),
            subtitle: t(
              'Your classes, your ideas, your next big thing.',
              'فصولك، أفكارك، وإنجازك القادم.',
            ),
            icon: Icons.bolt_rounded,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: FeatureCard(
                  tint: studafyCyan,
                  onTap: onNotebook,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.auto_stories_rounded,
                        color: studafyCyan,
                        size: 30,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        t('My notebook', 'دفتر دروسي'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t(
                          'Lesson notes · Subscription',
                          'ملاحظات الدروس · اشتراك',
                        ),
                        style: const TextStyle(
                          color: studafyMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FeatureCard(
                  tint: studafyNavy,
                  onTap: onWork,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.edit_note_rounded,
                        color: studafyNavy,
                        size: 30,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        t('My work', 'أعمالي'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t('Take the next step', 'خطوتك القادمة'),
                        style: const TextStyle(
                          color: studafyMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FeatureCard(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const StudentFamilyPage(),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEEE3),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.favorite_outline_rounded,
                    color: Color(0xFFC36139),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('My ID & family', 'معرّفي وعائلتي'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t(
                          'Share your ID. Review parent requests.',
                          'شارك معرّفك وراجع طلبات أولياء الأمور.',
                        ),
                        style: const TextStyle(
                          color: studafyMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(forwardChevron(context)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // A student's first question on opening the app is which classes
          // they are in - it is how they know the link they pasted worked at
          // all. The feeds below answer "what do I have to do", which is a
          // different question and reads as empty until a teacher sets work.
          if (classes != null) ...[
            Text(
              t('Your classes', 'صفوفي'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _StudentClasses(classes: classes!, label: t),
            const SizedBox(height: 24),
          ],
          Text(
            t('Ready when you are', 'جاهز عندما تكون مستعدًا'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<AcademicRecord>>(
            future: academic.load(AcademicFeed.assignments),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError) {
                return Text(
                  t(
                    'Your work could not load. Open My work to retry.',
                    'تعذر تحميل أعمالك. افتح أعمالي لإعادة المحاولة.',
                  ),
                );
              }
              final records = snapshot.data ?? [];
              if (records.isEmpty) {
                return StudafyStatusCard(
                  icon: Icons.wb_sunny_outlined,
                  title: t('A little breathing room', 'وقت لالتقاط الأنفاس'),
                  message: t(
                    'New assignments will appear here when your teacher shares them.',
                    'ستظهر الواجبات الجديدة هنا عندما يشاركها معلمك.',
                  ),
                );
              }
              return Column(
                children: [
                  for (final record in records.take(4))
                    FeatureCard(
                      onTap: onWork,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.assignment_outlined,
                            color: studafyNavy,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              record.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Icon(forwardChevron(context)),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 90),
        ],
      ),
    );
  }
}

/// The classes this student belongs to.
///
/// Failure is shown as a line of text rather than swallowed: an empty list
/// and a failed request look identical to a student otherwise, and the first
/// means "you are in no class yet" while the second means "try again".
class _StudentClasses extends StatelessWidget {
  const _StudentClasses({required this.classes, required this.label});

  final ClassListInteractor classes;
  final String Function(String en, String ar) label;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ClassroomSummary>>(
      future: classes.loadClasses().then(
        (result) => result.fold(
          onSuccess: (items) => items,
          onFailure: (failure) => throw failure,
        ),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LinearProgressIndicator();
        }
        if (snapshot.hasError) {
          return Text(
            label(
              'Your classes could not load. Pull down to retry.',
              'تعذّر تحميل صفوفك. اسحب للأسفل لإعادة المحاولة.',
            ),
          );
        }
        final items = snapshot.data ?? const <ClassroomSummary>[];
        if (items.isEmpty) {
          return StudafyStatusCard(
            icon: Icons.group_add_outlined,
            title: label('No classes yet', 'لا توجد صفوف بعد'),
            message: label(
              'Paste the class link your teacher shared to join your first class.',
              'الصق رابط الصف الذي شاركه معلمك للانضمام إلى صفك الأول.',
            ),
          );
        }
        return Column(
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FeatureCard(
                  child: Row(
                    children: [
                      const Icon(Icons.class_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              label(
                                'Grade ${item.grade} \u00B7 ${item.section}',
                                'الصف ${item.grade} \u00B7 ${item.section}',
                              ),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
