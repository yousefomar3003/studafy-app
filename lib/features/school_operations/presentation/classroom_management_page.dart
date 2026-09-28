import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

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
    this.openLink,
  });
  final SchoolOperationsRepository repository;
  final ManagedClassroom classroom;
  final List<ManagedClassroom> classrooms;

  /// Opens a link outside the app. Tests supply their own.
  final Future<bool> Function(Uri url)? openLink;

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
  List<ManagedMeeting> _meetings = const [];

  /// The shape of a Google Meet link; the server enforces the same.
  static final _meetLink = RegExp(
    r'^https://meet\.google\.com/[A-Za-z0-9-]{3,64}(\?[A-Za-z0-9=&._-]{0,200})?$',
  );

  Future<bool> _open(Uri url) =>
      (widget.openLink ??
      (u) => launchUrl(u, mode: LaunchMode.externalApplication))(url);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
    _loadMeetings();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  /// Separate from the roster: a meeting list that fails to load must not
  /// take the students and staff tabs down with it.
  Future<void> _loadMeetings() async {
    try {
      final meetings = await widget.repository.listMeetings(
        widget.classroom.id,
      );
      if (mounted) setState(() => _meetings = meetings);
    } on Object {
      // The tab shows its empty state; scheduling still works.
    }
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

  String _when(DateTime start) {
    final l = MaterialLocalizations.of(context);
    return '${l.formatMediumDate(start)} · '
        '${l.formatTimeOfDay(TimeOfDay.fromDateTime(start))}';
  }

  String _audience(String value, String Function(String, String) t) =>
      switch (value) {
        'guardians' => t('Guardians', 'أولياء الأمور'),
        'students' => t('Students', 'الطلاب'),
        _ => t('Whole class', 'الفصل بالكامل'),
      };

  Widget _meetingsTab(String Function(String, String) t) => RefreshIndicator(
    onRefresh: _loadMeetings,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(
          onPressed: _busy ? null : () => _requestMeeting(t),
          icon: const Icon(Icons.video_call_outlined),
          label: Text(t('Schedule meeting', 'جدولة اجتماع')),
        ),
        const SizedBox(height: 8),
        Text(
          t(
            'Create the meeting in Google Meet, then paste its link here. '
                'Everyone invited is told in the app and can join from it.',
            'أنشئ الاجتماع في Google Meet ثم الصق رابطه هنا. '
                'سيُبلَّغ المدعوون في التطبيق ويمكنهم الانضمام منه.',
          ),
          style: const TextStyle(color: studafyMuted),
        ),
        const SizedBox(height: 16),
        if (_meetings.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              t('No upcoming meetings.', 'لا توجد اجتماعات قادمة.'),
              textAlign: TextAlign.center,
            ),
          ),
        for (final meeting in _meetings)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meeting.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(_when(meeting.startsAt)),
                  Text(
                    '${_audience(meeting.audience, t)} · '
                    '${meeting.state == 'cancelled' ? t('Cancelled', 'أُلغي') : t('${meeting.recipientCount} invited', 'المدعوون: ${meeting.recipientCount}')}',
                    style: const TextStyle(color: studafyMuted),
                  ),
                  if (meeting.state != 'cancelled')
                    Wrap(
                      spacing: 8,
                      children: [
                        if (meeting.meetUrl case final url?) ...[
                          TextButton.icon(
                            onPressed: () => _open(url),
                            icon: const Icon(Icons.videocam_outlined),
                            label: Text(t('Join', 'انضمام')),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: url.toString()),
                              );
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    t('Link copied.', 'تم نسخ الرابط.'),
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy_rounded),
                            label: Text(t('Copy link', 'نسخ الرابط')),
                          ),
                        ],
                        TextButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _run(
                                  () async {
                                    await widget.repository.cancelMeeting(
                                      meetingId: meeting.id,
                                      expectedVersion: meeting.version,
                                    );
                                    await _loadMeetings();
                                  },
                                  t('Meeting cancelled.', 'تم إلغاء الاجتماع.'),
                                ),
                          icon: const Icon(Icons.event_busy_outlined),
                          label: Text(t('Cancel meeting', 'إلغاء الاجتماع')),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
      ],
    ),
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
    final link = TextEditingController();
    String? linkError;
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialog) => AlertDialog(
              title: Text(t('Schedule meeting', 'جدولة اجتماع')),
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
                    const SizedBox(height: 12),
                    // Studafy does not host the call. The teacher makes it in
                    // Google Meet and hands over the link.
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: () =>
                            _open(Uri.parse('https://meet.google.com/new')),
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: Text(
                          t('Create it in Google Meet', 'أنشئه في Google Meet'),
                        ),
                      ),
                    ),
                    TextField(
                      controller: link,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: t('Google Meet link', 'رابط Google Meet'),
                        hintText: 'https://meet.google.com/abc-defg-hij',
                        errorText: linkError,
                        suffixIcon: IconButton(
                          tooltip: t('Paste', 'لصق'),
                          icon: const Icon(Icons.content_paste_rounded),
                          onPressed: () async {
                            final data = await Clipboard.getData(
                              Clipboard.kTextPlain,
                            );
                            final text = data?.text?.trim();
                            if (text != null && text.isNotEmpty) {
                              setDialog(() => link.text = text);
                            }
                          },
                        ),
                      ),
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
                  onPressed: () {
                    // Checked here, not only by the server, so the teacher
                    // fixes the link without losing the rest of the form.
                    if (!_meetLink.hasMatch(link.text.trim())) {
                      setDialog(
                        () => linkError = t(
                          'Paste a link that starts with https://meet.google.com/',
                          'الصق رابطًا يبدأ بـ https://meet.google.com/',
                        ),
                      );
                      return;
                    }
                    Navigator.pop(context, true);
                  },
                  child: Text(t('Schedule', 'جدولة')),
                ),
              ],
            ),
          ),
        ) ??
        false;
    if (!ok || title.text.trim().isEmpty) return;
    await _run(
      () async {
        await widget.repository.requestMeeting(
          classroomId: widget.classroom.id,
          title: title.text,
          startsAt: starts,
          endsAt: starts.add(Duration(minutes: duration)),
          audience: audience,
          meetUrl: Uri.parse(link.text.trim()),
        );
        await _loadMeetings();
      },
      t(
        'Meeting scheduled. Everyone invited has been told.',
        'تمت جدولة الاجتماع وإبلاغ المدعوين.',
      ),
    );
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
