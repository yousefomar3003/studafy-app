import 'package:flutter/material.dart';

import '../../../core/studafy_design.dart';
import '../../../core/failures.dart';
import '../domain/school_operations_repository.dart';

class GuardianVerificationPage extends StatefulWidget {
  const GuardianVerificationPage({super.key, required this.repository});
  final SchoolOperationsRepository repository;
  @override
  State<GuardianVerificationPage> createState() =>
      _GuardianVerificationPageState();
}

class _GuardianVerificationPageState extends State<GuardianVerificationPage> {
  final _linkId = TextEditingController();
  int _expiresInDays = 365;
  bool _busy = false;

  String _t(String en, String ar) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

  @override
  void dispose() {
    _linkId.dispose();
    super.dispose();
  }

  Future<void> _act(bool verify) async {
    if (_linkId.text.trim().isEmpty || _busy) return;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              verify
                  ? _t(
                      'Confirm guardian verification',
                      'تأكيد التحقق من ولي الأمر',
                    )
                  : _t('Revoke guardian access?', 'إلغاء وصول ولي الأمر؟'),
            ),
            content: Text(
              verify
                  ? _t(
                      'Verify only after checking the guardian’s identity and relationship with the student.',
                      'أكد الربط بعد التحقق من هوية ولي الأمر وصلته بالطالب فقط.',
                    )
                  : _t(
                      'This removes access granted by this family link.',
                      'سيؤدي هذا إلى إزالة الوصول الممنوح بواسطة هذا الربط العائلي.',
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(_t('Cancel', 'إلغاء')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(_t('Confirm', 'تأكيد')),
              ),
            ],
          ),
        ) ??
        false;
    if (!mounted || !confirmed) return;
    setState(() => _busy = true);
    try {
      final status = verify
          ? await widget.repository.verifyGuardianLink(
              linkId: _linkId.text,
              expiresInDays: _expiresInDays,
            )
          : await widget.repository.revokeGuardianLink(_linkId.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_t('Link status', 'حالة الربط')}: $status'),
          ),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(Failure.fromError(error).message)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: studafyCanvas,
    appBar: AppBar(
      title: Text(_t('Guardian verification', 'التحقق من ولي الأمر')),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        FeatureCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _t(
                  'Enter the link ID supplied with the verification request.',
                  'أدخل معرّف الربط المرفق بطلب التحقق. لا يوفر الخادم قائمة بالطلبات المعلقة حاليًا.',
                ),
                style: const TextStyle(color: studafyMuted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _linkId,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: _t('Guardian link ID', 'معرّف ربط ولي الأمر'),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _expiresInDays,
                decoration: InputDecoration(
                  labelText: _t('Verification period', 'مدة التحقق'),
                ),
                items: [30, 90, 180, 365]
                    .map(
                      (days) => DropdownMenuItem(
                        value: days,
                        child: Text('$days ${_t('days', 'يومًا')}'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _expiresInDays = value!),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _busy ? null : () => _act(true),
                icon: const Icon(Icons.verified_user_outlined),
                label: Text(_t('Verify link', 'تأكيد الربط')),
              ),
              TextButton(
                onPressed: _busy ? null : () => _act(false),
                child: Text(
                  _t('Revoke link', 'إلغاء الربط'),
                  style: const TextStyle(color: Color(0xFFB42318)),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
