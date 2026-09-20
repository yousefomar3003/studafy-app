import 'package:flutter/material.dart';

import '../../../core/studafy_design.dart';
import '../domain/teacher_dashboard_repository.dart';
import 'teacher_dashboard_repository_scope.dart';
import '../../../core/studafy_formatting.dart';
import '../../../core/user_content_text.dart';
import '../../../l10n/generated/app_l10n.dart';

part 'teacher_dashboard_components.dart';
part 'teacher_dashboard_dialogs.dart';

const navy = studafyNavy;
const cyan = studafyCyan;
const ink = studafyInk;
const muted = studafyMuted;
const canvas = studafyCanvas;

class TeacherDashboardActions {
  const TeacherDashboardActions({
    required this.openChats,
    required this.openNotifications,
    required this.openProfile,
  });

  final VoidCallback openChats;
  final VoidCallback openNotifications;
  final VoidCallback openProfile;
}

class TeacherHeader extends StatelessWidget {
  const TeacherHeader({
    super.key,
    required this.actions,
    this.title = 'Al-Noor International',
  });

  final TeacherDashboardActions actions;
  final String title;
  @override
  Widget build(BuildContext c) => Container(
    color: Colors.white,
    padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 16, 14),
    child: SafeArea(
      bottom: false,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const StudafyLogo(size: 23),
                const SizedBox(height: 5),
                Text(title, style: const TextStyle(color: muted)),
              ],
            ),
          ),
          Badge(
            label: Text(studafyNumber(c, 3)),
            child: IconButton(
              onPressed: actions.openChats,
              icon: const Icon(Icons.chat_bubble_outline),
            ),
          ),
          FutureBuilder<int>(
            future: TeacherDashboardRepositoryScope.read(c)
                .unreadNotificationCount(),
            builder: (context, snapshot) => Badge(
              isLabelVisible: (snapshot.data ?? 0) > 0,
              backgroundColor: Colors.red,
              label: Text(studafyNumber(context, snapshot.data ?? 0)),
              child: IconButton(
                tooltip: AppL10n.of(context).dashNotifications,
                onPressed: actions.openNotifications,
                icon: const Icon(Icons.notifications_none),
              ),
            ),
          ),
          InkWell(
            onTap: actions.openProfile,
            borderRadius: BorderRadius.circular(24),
            child: const CircleAvatar(
              backgroundColor: navy,
              child: Text(
                'RH',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class TeacherHome extends StatefulWidget {
  const TeacherHome({super.key, required this.actions});

  final TeacherDashboardActions actions;

  @override
  State<TeacherHome> createState() => _TeacherHomeState();
}

class _TeacherHomeState extends State<TeacherHome> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Column(
    children: [
      TeacherHeader(actions: widget.actions),
      Expanded(
        child: Scrollbar(
          controller: _scrollController,
          interactive: true,
          child: ListView(
            key: const PageStorageKey('teacher-home-scroll'),
            controller: _scrollController,
            primary: false,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 20, 48),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Good morning, Rana',
                          style: Theme.of(c).textTheme.headlineSmall,
                        ),
                        const Text(
                          'Thursday, August 27',
                          style: TextStyle(color: muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              const SectionTitle("Today's sessions"),
              const SizedBox(height: 12),
              SessionCard(
                time: '08:30–09:20',
                title: 'Biology · Grade 10 B',
                room: 'Lab 2',
                status: 'NOW',
              ),
              const SizedBox(height: 12),
              SessionCard(
                time: '09:30–10:20',
                title: 'Biology · Grade 9 A',
                room: 'Lab 2',
                status: 'NEXT',
              ),
              const SizedBox(height: 12),
              SessionCard(
                time: '11:00–11:50',
                title: 'Chemistry · Grade 10 A',
                room: 'Lab 1',
                completed: true,
              ),
              const SizedBox(height: 26),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SectionTitle('Pending grading'),
                  Text(
                    'View all',
                    style: TextStyle(
                      color: Color(0xFF087D99),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const InfoCard(
                child: Column(
                  children: [
                    SmallRow(
                      'Photosynthesis lab report',
                      'Grade 10 B',
                      '6 to grade',
                      navy,
                    ),
                    Divider(),
                    SmallRow(
                      'Cell diagram worksheet',
                      'Grade 9 A',
                      '4 to grade',
                      cyan,
                    ),
                    Divider(),
                    SmallRow(
                      'Titration write-up',
                      'Grade 10 A',
                      '2 to grade',
                      Color(0xFF7737EE),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              const SectionTitle('Recent submissions'),
              const SizedBox(height: 12),
              const InfoCard(
                child: Column(
                  children: [
                    StudentRow(
                      'LH',
                      'Layla Hassan',
                      'Photosynthesis report · 18 min ago',
                    ),
                    Divider(),
                    StudentRow(
                      'OF',
                      'Omar Fathy',
                      'Photosynthesis report · 1 hour ago',
                    ),
                    Divider(),
                    StudentRow(
                      'MA',
                      'Mariam Adel',
                      'Cell diagram worksheet · Late',
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
}
