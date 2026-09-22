import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/studafy_design.dart';
import '../domain/family.dart';
import 'family_scope.dart';
import 'family_strings.dart';

class StudentFamilyPage extends StatefulWidget {
  const StudentFamilyPage({super.key});
  @override
  State<StudentFamilyPage> createState() => _StudentFamilyPageState();
}

class _StudentFamilyPageState extends State<StudentFamilyPage> {
  StudentFamily? _family;
  String? _error;
  bool _busy = false;
  String t(String en, String ar) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await FamilyScope.of(context).studentFamily();
    if (!mounted) return;
    setState(
      () => result.fold(
        onSuccess: (value) {
          _family = value;
          _error = null;
        },
        onFailure: (failure) => _error = familyFailureText(context, failure),
      ),
    );
  }

  Future<void> _decide(StudentGuardianRequest request, String decision) async {
    if (_busy) return;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              decision == 'approve'
                  ? t('Is this your parent?', 'هل هذا ولي أمرك؟')
                  : t('Confirm your choice', 'تأكيد اختيارك'),
            ),
            content: Text(
              decision == 'approve'
                  ? t(
                      'Only approve ${request.guardianName} if you know this is your parent or guardian. They will be able to see your grades, attendance and shared school updates.',
                      'وافق على ${request.guardianName} فقط إذا كنت تعرف أنه ولي أمرك. سيتمكن من الاطلاع على درجاتك وحضورك وتحديثاتك الدراسية المشتركة.',
                    )
                  : t(
                      'This person will not have access through this family link.',
                      'لن يتمكن هذا الشخص من الوصول عبر هذا الربط العائلي.',
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(t('Cancel', 'إلغاء')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(t('Confirm', 'تأكيد')),
              ),
            ],
          ),
        ) ??
        false;
    if (!mounted || !confirmed) return;
    setState(() => _busy = true);
    final result = await FamilyScope.of(context)
        .decideGuardian(request.id, decision);
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold(
      onSuccess: (_) => _load(),
      onFailure: (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(familyFailureText(context, failure))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(t('My family', 'عائلتي'))),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          StudafyHero(
            eyebrow: t('YOUR CONNECTIONS', 'روابطك'),
            title: t('Your family.\nYour choice.', 'عائلتك.\nقرارك.'),
            subtitle: t(
              'Share your Studafy ID with your parent. You decide who can follow your progress.',
              'شارك معرّف Studafy مع ولي أمرك. أنت تقرر من يمكنه متابعة تقدمك.',
            ),
            icon: Icons.favorite_outline_rounded,
          ),
          const SizedBox(height: 24),
          if (_error != null)
            StudafyStatusCard(
              icon: Icons.wifi_off_rounded,
              title: t('Could not load requests', 'تعذر تحميل الطلبات'),
              message: _error!,
              actionLabel: t('Try again', 'إعادة المحاولة'),
              onAction: _load,
            )
          else if (_family == null)
            const Center(child: CircularProgressIndicator())
          else ...[
            for (final identity in _family!.identities)
              FeatureCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('MY STUDAFY ID', 'معرّف STUDAFY'),
                      style: const TextStyle(
                        color: studafyMuted,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            identity.studafyId,
                            style: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: t('Copy ID', 'نسخ المعرّف'),
                          icon: const Icon(Icons.copy_rounded),
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: identity.studafyId),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    t('ID copied', 'تم نسخ المعرّف'),
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            if (_family!.identities.isEmpty)
              Text(
                t(
                  'Join a class to activate your student ID.',
                  'انضم إلى فصل لتفعيل معرّف الطالب.',
                ),
              ),
            const SizedBox(height: 24),
            Text(
              t('Parent requests', 'طلبات أولياء الأمور'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (_family!.requests.isEmpty)
              StudafyStatusCard(
                icon: Icons.mark_email_read_outlined,
                title: t('All caught up', 'أنت على اطلاع'),
                message: t(
                  'New parent requests will appear here.',
                  'ستظهر طلبات أولياء الأمور الجديدة هنا.',
                ),
              ),
            for (final request in _family!.requests)
              FeatureCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFFE8E5FF),
                          foregroundColor: studafyNavy,
                          child: Text(
                            request.guardianName.characters.firstOrNull ?? '?',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            request.guardianName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      '${t('Account ID', 'معرّف الحساب')}: ${request.guardianId}',
                      style: const TextStyle(fontSize: 12, color: studafyMuted),
                    ),
                    const SizedBox(height: 12),
                    if (request.status == GuardianLinkStatus.pending)
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          FilledButton(
                            onPressed: _busy
                                ? null
                                : () => _decide(request, 'approve'),
                            child: Text(t('This is my parent', 'هذا ولي أمري')),
                          ),
                          OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => _decide(request, 'decline'),
                            child: Text(t('Decline', 'رفض')),
                          ),
                        ],
                      )
                    else if (request.status == GuardianLinkStatus.verified)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              t('Connected', 'مرتبط'),
                              style: const TextStyle(color: studafyCyan),
                            ),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _decide(request, 'revoke'),
                            child: Text(t('Remove access', 'إزالة الوصول')),
                          ),
                        ],
                      )
                    else
                      Text(
                        request.status == GuardianLinkStatus.declined
                            ? t('Declined', 'مرفوض')
                            : t('Access removed', 'تمت إزالة الوصول'),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    ),
  );
}
