import 'package:flutter/material.dart';

import '../../../core/studafy_design.dart';
import '../../../core/studafy_domain.dart';
import '../../../core/failures.dart';
import '../domain/school_operations_repository.dart';

class ClassroomManagementPage extends StatefulWidget {
  const ClassroomManagementPage({
    super.key,
    required this.repository,
    required this.classroom,
    required this.classrooms,
  });
  final SchoolOperationsRepository repository;
  final ManagedClassroom classroom;
  final List<ManagedClassroom> classrooms;

  @override
  State<ClassroomManagementPage> createState() =>
      _ClassroomManagementPageState();
}

class _ClassroomManagementPageState extends State<ClassroomManagementPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<RosterStudent> _students = const [];
  List<ClassroomStaffMember> _staff = const [];
  bool _loading = true;
  bool _busy = false;
  RosterStudent? _pendingEnrollment;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait<Object>([
        widget.repository.listStudents(widget.classroom.id),
        widget.repository.listStaff(widget.classroom.id),
      ]);
      if (!mounted) return;
      setState(() {
        _students = values[0] as List<RosterStudent>;
        _staff = values[1] as List<ClassroomStaffMember>;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = Failure.fromError(error).message;
      });
    }
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    if (!mounted || _busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(success)));
      await _load();
    } on Object catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(Failure.fromError(error).message)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    String t(String en, String arText) => ar ? arText : en;
    return Scaffold(
      backgroundColor: studafyCanvas,
      appBar: AppBar(
        title: Text(widget.classroom.name),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: t('Students', 'الطلاب')),
            Tab(text: t('Staff', 'المعلمون')),
            Tab(text: t('Meetings', 'الاجتماعات')),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _load,
                      child: Text(t('Try again', 'إعادة المحاولة')),
                    ),
                  ],
                ),
              ),
            )
          : TabBarView(
              controller: _tabs,
              children: [_studentsTab(t), _staffTab(t), _meetingsTab(t)],
            ),
    );
  }

  Widget _studentsTab(String Function(String, String) t) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (ActiveContextController.instance.role == StudafyRole.schoolAdmin)
          FilledButton.icon(
            onPressed: _busy ? null : () => _addStudent(t),
            icon: const Icon(Icons.person_add_alt_1),
            label: Text(t('Create and enrol student', 'إنشاء طالب وتسجيله')),
          ),
        const SizedBox(height: 8),
        if (_pendingEnrollment != null) ...[
          SelectableText(
            '${t('Created student awaiting enrolment', 'طالب تم إنشاؤه بانتظار التسجيل')}: ${_pendingEnrollment!.displayName}\n${_pendingEnrollment!.id}',
          ),
          OutlinedButton(
            onPressed: _busy
                ? null
                : () => _run(() async {
                    await widget.repository.enrollStudent(
                      classroomId: widget.classroom.id,
                      studentId: _pendingEnrollment!.id,
                    );
                    _pendingEnrollment = null;
                  }, t('Student enrolled.', 'تم تسجيل الطالب.')),
            child: Text(t('Retry enrolment', 'إعادة محاولة التسجيل')),
          ),
        ],
        OutlinedButton.icon(
          onPressed: () => _enrolExisting(t),
          icon: const Icon(Icons.how_to_reg_outlined),
          label: Text(t('Enrol by student ID', 'تسجيل باستخدام معرّف الطالب')),
        ),
        const SizedBox(height: 16),
        if (_students.isEmpty)
          Text(t('No enrolled students.', 'لا يوجد طلاب مسجلون.')),
        for (final student in _students)
          Card(
            child: ListTile(
              title: Text(student.displayName),
              subtitle: Text(student.studafyId),
              trailing: PopupMenuButton<String>(
                onSelected: (value) => value == 'withdraw'
                    ? _withdraw(student, t)
                    : _transfer(student, t),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'transfer',
                    child: Text(t('Transfer', 'نقل')),
                  ),
                  PopupMenuItem(
                    value: 'withdraw',
                    child: Text(t('Withdraw', 'سحب')),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  Widget _staffTab(String Function(String, String) t) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(
          onPressed: () => _assignStaff(t),
          icon: const Icon(Icons.person_add_outlined),
          label: Text(t('Assign staff', 'تعيين معلم')),
        ),
        const SizedBox(height: 16),
        if (_staff.isEmpty)
          Text(t('No staff assignments.', 'لا توجد تعيينات للمعلمين.')),
        for (final member in _staff)
          Card(
            child: ListTile(
              title: Text(member.displayName),
              subtitle: Text('${member.role} · ${member.userId}'),
              trailing: IconButton(
                tooltip: t('Remove', 'إزالة'),
                icon: const Icon(Icons.person_remove_outlined),
                onPressed: () =>
                    _confirm(
                      t(
                        'Remove ${member.displayName} from this class?',
                        'إزالة ${member.displayName} من هذا الفصل؟',
                      ),
                      t,
                    ).then((ok) {
                      if (ok) {
                        _run(
                          () => widget.repository.removeStaff(
                            classroomId: widget.classroom.id,
                            assignmentId: member.assignmentId,
                          ),
                          t('Staff removed.', 'تمت إزالة المعلم.'),
                        );
                      }
                    }),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _meetingsTab(String Function(String, String) t) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      FilledButton.icon(
        onPressed: () => _requestMeeting(t),
        icon: const Icon(Icons.video_call_outlined),
        label: Text(t('Request meeting', 'طلب اجتماع')),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () => _lookupMeeting(t),
        icon: const Icon(Icons.search),
        label: Text(
          t(
            'Check or cancel by meeting ID',
            'فحص أو إلغاء باستخدام معرّف الاجتماع',
          ),
        ),
      ),
      const SizedBox(height: 16),
      Text(
        t(
          'Save the meeting ID shown after creation to check its status or cancel it later.',
          'احفظ معرّف الاجتماع الذي يظهر بعد إنشائه للتحقق من حالته أو إلغائه لاحقًا.',
        ),
        style: const TextStyle(color: studafyMuted),
      ),
    ],
  );

  Future<void> _addStudent(String Function(String, String) t) async {
    if (_pendingEnrollment != null || _busy) return;
    final name = TextEditingController();
    final userId = TextEditingController();
    final ok = await _form(t('Create student', 'إنشاء طالب'), [
      TextField(
        controller: name,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: t('Display name', 'الاسم الظاهر'),
        ),
      ),
      TextField(
        controller: userId,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: t(
            'Account UUID (optional)',
            'معرّف الحساب UUID (اختياري)',
          ),
        ),
      ),
    ], t);
    if (!ok || name.text.trim().isEmpty) return;
    await _run(() async {
      final student = await widget.repository.createStudent(
        displayName: name.text,
        userId: userId.text,
      );
      _pendingEnrollment = student;
      await widget.repository.enrollStudent(
        classroomId: widget.classroom.id,
        studentId: student.id,
      );
      _pendingEnrollment = null;
    }, t('Student created and enrolled.', 'تم إنشاء الطالب وتسجيله.'));
  }

  Future<void> _enrolExisting(String Function(String, String) t) async {
    final id = TextEditingController();
    final ok = await _form(t('Enrol student', 'تسجيل طالب'), [
      TextField(
        controller: id,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: t('Student record ID', 'معرّف سجل الطالب'),
        ),
      ),
    ], t);
    if (ok && id.text.trim().isNotEmpty) {
      await _run(
        () => widget.repository.enrollStudent(
          classroomId: widget.classroom.id,
          studentId: id.text.trim(),
        ),
        t('Student enrolled.', 'تم تسجيل الطالب.'),
      );
    }
  }

  Future<void> _withdraw(
    RosterStudent student,
    String Function(String, String) t,
  ) async {
    if (!await _confirm(
      t(
        'Withdraw ${student.displayName} from this class?',
        'سحب ${student.displayName} من هذا الفصل؟',
      ),
      t,
    )) {
      return;
    }
    await _run(
      () => widget.repository.withdrawStudent(
        classroomId: widget.classroom.id,
        studentId: student.id,
      ),
      t('Student withdrawn.', 'تم سحب الطالب.'),
    );
  }

  Future<void> _transfer(
    RosterStudent student,
    String Function(String, String) t,
  ) async {
    final targets = widget.classrooms
        .where((c) => c.id != widget.classroom.id)
        .toList();
    if (targets.isEmpty) return;
    var target = targets.first.id;
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialog) => AlertDialog(
              title: Text(
                t(
                  'Transfer ${student.displayName}',
                  'نقل ${student.displayName}',
                ),
              ),
              content: DropdownButtonFormField<String>(
                initialValue: target,
                decoration: InputDecoration(
                  labelText: t('Target class', 'الفصل المستهدف'),
                ),
                items: [
                  for (final c in targets)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (value) => setDialog(() => target = value!),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(t('Cancel', 'إلغاء')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(t('Transfer', 'نقل')),
                ),
              ],
            ),
          ),
        ) ??
        false;
    if (ok) {
      await _run(
        () => widget.repository.transferStudent(
          classroomId: widget.classroom.id,
          studentId: student.id,
          targetClassroomId: target,
        ),
        t('Student transferred.', 'تم نقل الطالب.'),
      );
    }
  }

  Future<void> _assignStaff(String Function(String, String) t) async {
    final userId = TextEditingController();
    var role = 'co_teacher';
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialog) => AlertDialog(
              title: Text(t('Assign staff', 'تعيين معلم')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: userId,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: t(
                        'Teacher account UUID',
                        'معرّف حساب المعلم UUID',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: InputDecoration(labelText: t('Role', 'الدور')),
                    items: [
                      DropdownMenuItem(
                        value: 'co_teacher',
                        child: Text(t('Co-teacher', 'معلم مشارك')),
                      ),
                      DropdownMenuItem(
                        value: 'lead_teacher',
                        child: Text(t('Lead teacher', 'المعلم الرئيسي')),
                      ),
                    ],
                    onChanged: (value) => setDialog(() => role = value!),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(t('Cancel', 'إلغاء')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(t('Assign', 'تعيين')),
                ),
              ],
            ),
          ),
        ) ??
        false;
    if (ok && userId.text.trim().isNotEmpty) {
      await _run(
        () => widget.repository.assignStaff(
          classroomId: widget.classroom.id,
          userId: userId.text,
          role: role,
        ),
        t('Staff assigned.', 'تم تعيين المعلم.'),
      );
    }
  }

  Future<void> _requestMeeting(String Function(String, String) t) async {
    final title = TextEditingController();
    var starts = DateTime.now().add(const Duration(days: 1));
    var duration = 30;
    var audience = 'guardians';
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialog) => AlertDialog(
              title: Text(t('Request meeting', 'طلب اجتماع')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: title,
                      decoration: InputDecoration(
                        labelText: t('Title', 'العنوان'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(t('Starts', 'يبدأ')),
                      subtitle: Text(
                        MaterialLocalizations.of(context)
                            .formatFullDate(starts),
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: starts,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 730),
                          ),
                        );
                        if (d != null) {
                          setDialog(
                            () => starts = DateTime(
                              d.year,
                              d.month,
                              d.day,
                              starts.hour,
                              starts.minute,
                            ),
                          );
                        }
                      },
                    ),
                    ListTile(
                      title: Text(t('Time', 'الوقت')),
                      subtitle: Text(
                        TimeOfDay.fromDateTime(starts).format(context),
                      ),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(starts),
                        );
                        if (time != null && context.mounted) {
                          setDialog(
                            () => starts = DateTime(
                              starts.year,
                              starts.month,
                              starts.day,
                              time.hour,
                              time.minute,
                            ),
                          );
                        }
                      },
                    ),
                    DropdownButtonFormField<int>(
                      initialValue: duration,
                      decoration: InputDecoration(
                        labelText: t('Duration', 'المدة'),
                      ),
                      items: [30, 45, 60, 90]
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text('$v ${t('minutes', 'دقيقة')}'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setDialog(() => duration = v!),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: audience,
                      decoration: InputDecoration(
                        labelText: t('Audience', 'الحضور'),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'guardians',
                          child: Text(t('Guardians', 'أولياء الأمور')),
                        ),
                        DropdownMenuItem(
                          value: 'students',
                          child: Text(t('Students', 'الطلاب')),
                        ),
                        DropdownMenuItem(
                          value: 'both',
                          child: Text(t('Whole class', 'الفصل بالكامل')),
                        ),
                      ],
                      onChanged: (v) => setDialog(() => audience = v!),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(t('Cancel', 'إلغاء')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(t('Request', 'طلب')),
                ),
              ],
            ),
          ),
        ) ??
        false;
    if (!ok || title.text.trim().isEmpty) return;
    try {
      final meeting = await widget.repository.requestMeeting(
        classroomId: widget.classroom.id,
        title: title.text,
        startsAt: starts,
        endsAt: starts.add(Duration(minutes: duration)),
        audience: audience,
      );
      if (mounted) {
        await _showMeeting(meeting, t);
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(Failure.fromError(error).message)),
        );
      }
    }
  }

  Future<void> _lookupMeeting(String Function(String, String) t) async {
    final id = TextEditingController();
    final ok = await _form(t('Find meeting', 'البحث عن اجتماع'), [
      TextField(
        controller: id,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: t('Meeting ID', 'معرّف الاجتماع'),
        ),
      ),
    ], t);
    if (!ok || id.text.trim().isEmpty) return;
    try {
      final meeting = await widget.repository.getMeeting(id.text);
      if (mounted) {
        await _showMeeting(meeting, t);
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(Failure.fromError(error).message)),
        );
      }
    }
  }

  Future<void> _showMeeting(
    ManagedMeeting meeting,
    String Function(String, String) t,
  ) async {
    final cancel =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(meeting.title),
            content: SelectableText(
              '${t('Meeting ID', 'معرّف الاجتماع')}: ${meeting.id}\n${t('State', 'الحالة')}: ${meeting.state}\n${t('Recipients', 'المستلمون')}: ${meeting.recipientCount}\n${meeting.startsAt}\n${meeting.meetUrl ?? ''}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(t('Close', 'إغلاق')),
              ),
              if (meeting.state != 'cancelled')
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(t('Cancel meeting', 'إلغاء الاجتماع')),
                ),
            ],
          ),
        ) ??
        false;
    if (cancel) {
      await _run(() async {
        await widget.repository.cancelMeeting(
          meetingId: meeting.id,
          expectedVersion: meeting.version,
        );
      }, t('Meeting cancelled.', 'تم إلغاء الاجتماع.'));
    }
  }

  Future<bool> _form(
    String title,
    List<Widget> fields,
    String Function(String, String) t,
  ) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final field in fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: field,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t('Cancel', 'إلغاء')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(t('Save', 'حفظ')),
            ),
          ],
        ),
      ) ??
      false;

  Future<bool> _confirm(
    String message,
    String Function(String, String) t,
  ) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(message),
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
}
