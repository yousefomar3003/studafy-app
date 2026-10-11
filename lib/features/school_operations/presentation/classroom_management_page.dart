import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/failures.dart';
import '../../../core/feedback.dart';
import '../../../core/studafy_design.dart';
import '../../../core/studafy_domain.dart';
import '../../../core/studafy_formatting.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/school_operations_repository.dart';
import 'schedule_meeting_dialog.dart';

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
      messenger.showMessage(success);
      await _load();
    } on Object catch (error) {
      if (mounted) {
        messenger.showMessage(Failure.fromError(error).message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Read once here and handed to each tab and action: several of them
    // show a message after an await, when this context may be gone.
    final l10n = AppL10n.of(context);
    return Scaffold(
      backgroundColor: studafyCanvas,
      appBar: AppBar(
        title: Text(widget.classroom.name),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: l10n.announcementAudienceStudents),
            Tab(text: l10n.classroomAdminStaff),
            Tab(text: l10n.notificationPrefsMeetings),
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
                      child: Text(l10n.securityTryAgain),
                    ),
                  ],
                ),
              ),
            )
          : TabBarView(
              controller: _tabs,
              children: [
                _studentsTab(l10n),
                _staffTab(l10n),
                _meetingsTab(l10n),
              ],
            ),
    );
  }

  Widget _studentsTab(AppL10n l10n) => StudafyRefreshIndicator(
    onRefresh: _load,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (ActiveContextController.instance.role == StudafyRole.schoolAdmin)
          FilledButton.icon(
            onPressed: _busy ? null : () => _addStudent(l10n),
            icon: const Icon(Icons.person_add_alt_1),
            label: Text(l10n.classroomAdminCreateAndEnrolStudent),
          ),
        const SizedBox(height: 8),
        if (_pendingEnrollment != null) ...[
          SelectableText(
            '${l10n.classroomAdminCreatedStudentAwaitingEnrolment}: ${_pendingEnrollment!.displayName}\n${_pendingEnrollment!.id}',
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
                  }, l10n.classroomAdminStudentEnrolled),
            child: Text(l10n.classroomAdminRetryEnrolment),
          ),
        ],
        OutlinedButton.icon(
          onPressed: () => _enrolExisting(l10n),
          icon: const Icon(Icons.how_to_reg_outlined),
          label: Text(l10n.classroomAdminEnrolByStudentId),
        ),
        const SizedBox(height: 16),
        if (_students.isEmpty) Text(l10n.classroomAdminNoEnrolledStudents),
        for (final student in _students)
          Card(
            child: ListTile(
              title: Text(student.displayName),
              subtitle: Text(student.studafyId),
              trailing: PopupMenuButton<String>(
                onSelected: (value) => value == 'withdraw'
                    ? _withdraw(student, l10n)
                    : _transfer(student, l10n),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'transfer',
                    child: Text(l10n.classroomAdminTransfer),
                  ),
                  PopupMenuItem(
                    value: 'withdraw',
                    child: Text(l10n.classroomAdminWithdraw),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  Widget _staffTab(AppL10n l10n) => StudafyRefreshIndicator(
    onRefresh: _load,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(
          onPressed: () => _assignStaff(l10n),
          icon: const Icon(Icons.person_add_outlined),
          label: Text(l10n.classroomAdminAssignStaff),
        ),
        const SizedBox(height: 16),
        if (_staff.isEmpty) Text(l10n.classroomAdminNoStaffAssignments),
        for (final member in _staff)
          Card(
            child: ListTile(
              title: Text(member.displayName),
              subtitle: Text('${member.role} · ${member.userId}'),
              trailing: IconButton(
                tooltip: l10n.classroomAdminRemove,
                icon: const Icon(Icons.person_remove_outlined),
                onPressed: () =>
                    _confirm(
                      l10n.classroomAdminRemoveDisplaynameFromThisClass(
                        member.displayName,
                      ),
                      l10n,
                    ).then((ok) {
                      if (ok) {
                        _run(
                          () => widget.repository.removeStaff(
                            classroomId: widget.classroom.id,
                            assignmentId: member.assignmentId,
                          ),
                          l10n.classroomAdminStaffRemoved,
                        );
                      }
                    }),
              ),
            ),
          ),
      ],
    ),
  );

  String _audience(String value, AppL10n l10n) => switch (value) {
    'guardians' => l10n.schoolAdminGuardians,
    'students' => l10n.announcementAudienceStudents,
    _ => l10n.classroomAdminWholeClass,
  };

  Widget _meetingsTab(AppL10n l10n) => StudafyRefreshIndicator(
    onRefresh: _loadMeetings,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(
          onPressed: _busy ? null : () => _requestMeeting(l10n),
          icon: const Icon(Icons.video_call_outlined),
          label: Text(l10n.classroomAdminScheduleMeeting),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.classroomAdminCreateTheMeetingInGoogle,
          style: const TextStyle(color: studafyMuted),
        ),
        const SizedBox(height: 16),
        if (_meetings.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              l10n.classroomAdminNoUpcomingMeetings,
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
                  Text(studafyDateTime(context, meeting.startsAt)),
                  Text(
                    '${_audience(meeting.audience, l10n)} · '
                    '${meeting.state == 'cancelled' ? l10n.meetingsCancelled : l10n.classroomAdminRecipientcountInvited(meeting.recipientCount)}',
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
                            label: Text(l10n.meetingsJoin),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: url.toString()),
                              );
                              if (!mounted) return;
                              ScaffoldMessenger.of(context)
                                  .showMessage(l10n.classroomAdminLinkCopied);
                            },
                            icon: const Icon(Icons.copy_rounded),
                            label: Text(l10n.classroomAdminCopyLink),
                          ),
                        ],
                        TextButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _run(() async {
                                  await widget.repository.cancelMeeting(
                                    meetingId: meeting.id,
                                    expectedVersion: meeting.version,
                                  );
                                  await _loadMeetings();
                                }, l10n.classroomAdminMeetingCancelled),
                          icon: const Icon(Icons.event_busy_outlined),
                          label: Text(l10n.classroomAdminCancelMeeting),
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

  Future<void> _addStudent(AppL10n l10n) async {
    if (_pendingEnrollment != null || _busy) return;
    final name = TextEditingController();
    final userId = TextEditingController();
    final ok = await _form(l10n.classroomAdminCreateStudent, [
      TextField(
        controller: name,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(labelText: l10n.classroomAdminDisplayName),
      ),
      TextField(
        controller: userId,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: l10n.classroomAdminAccountUuidOptional,
        ),
      ),
    ], l10n);
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
    }, l10n.classroomAdminStudentCreatedAndEnrolled);
  }

  Future<void> _enrolExisting(AppL10n l10n) async {
    final id = TextEditingController();
    final ok = await _form(l10n.classroomAdminEnrolStudent, [
      TextField(
        controller: id,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: l10n.classroomAdminStudentRecordId,
        ),
      ),
    ], l10n);
    if (ok && id.text.trim().isNotEmpty) {
      await _run(
        () => widget.repository.enrollStudent(
          classroomId: widget.classroom.id,
          studentId: id.text.trim(),
        ),
        l10n.classroomAdminStudentEnrolled,
      );
    }
  }

  Future<void> _withdraw(RosterStudent student, AppL10n l10n) async {
    if (!await _confirm(
      l10n.classroomAdminWithdrawDisplaynameFromThisClass(student.displayName),
      l10n,
    )) {
      return;
    }
    await _run(
      () => widget.repository.withdrawStudent(
        classroomId: widget.classroom.id,
        studentId: student.id,
      ),
      l10n.classroomAdminStudentWithdrawn,
    );
  }

  Future<void> _transfer(RosterStudent student, AppL10n l10n) async {
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
                l10n.classroomAdminTransferDisplayname(student.displayName),
              ),
              content: DropdownButtonFormField<String>(
                initialValue: target,
                decoration: InputDecoration(
                  labelText: l10n.classroomAdminTargetClass,
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
                  child: Text(l10n.academicCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l10n.classroomAdminTransfer),
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
        l10n.classroomAdminStudentTransferred,
      );
    }
  }

  Future<void> _assignStaff(AppL10n l10n) async {
    final userId = TextEditingController();
    var role = 'co_teacher';
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialog) => AlertDialog(
              title: Text(l10n.classroomAdminAssignStaff),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: userId,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: l10n.classroomAdminTeacherAccountUuid,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: InputDecoration(
                      labelText: l10n.classroomAdminRole,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'co_teacher',
                        child: Text(l10n.classroomAdminCoTeacher),
                      ),
                      DropdownMenuItem(
                        value: 'lead_teacher',
                        child: Text(l10n.classroomAdminLeadTeacher),
                      ),
                    ],
                    onChanged: (value) => setDialog(() => role = value!),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n.academicCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l10n.classroomAdminAssign),
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
        l10n.classroomAdminStaffAssigned,
      );
    }
  }

  Future<void> _requestMeeting(AppL10n l10n) async {
    final draft = await showScheduleMeetingDialog(
      context,
      l10n,
      openLink: _open,
    );
    if (draft == null) return;
    await _run(() async {
      await widget.repository.requestMeeting(
        classroomId: widget.classroom.id,
        title: draft.title,
        startsAt: draft.startsAt,
        endsAt: draft.endsAt,
        audience: draft.audience,
        meetUrl: draft.meetUrl,
      );
      await _loadMeetings();
    }, l10n.classroomAdminMeetingScheduledEveryoneInvitedHas);
  }

  Future<bool> _form(String title, List<Widget> fields, AppL10n l10n) async =>
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
              child: Text(l10n.academicCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.notebookSave),
            ),
          ],
        ),
      ) ??
      false;

  Future<bool> _confirm(String message, AppL10n l10n) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.academicCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.studentFamilyConfirm),
            ),
          ],
        ),
      ) ??
      false;
}
