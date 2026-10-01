import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/failures.dart';
import '../../../core/studafy_design.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/family.dart';
import 'family_scope.dart';
import 'family_strings.dart';

/// A child's progress from published grades and recorded attendance. Every
/// figure says where it comes from; nothing is inferred or predicted.
class ChildProgressPage extends StatefulWidget {
  const ChildProgressPage({super.key, required this.child});

  final GuardianChild child;

  @override
  State<ChildProgressPage> createState() => _ChildProgressPageState();
}

class _ChildProgressPageState extends State<ChildProgressPage> {
  ChildProgress? _progress;
  Failure? _failure;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await FamilyScope.of(context)
        .progress(widget.child.studentId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      result.fold(
        onSuccess: (value) {
          _progress = value;
          _failure = null;
        },
        onFailure: (failure) => _failure = failure,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    return Scaffold(
      backgroundColor: studafyCanvas,
      appBar: AppBar(
        title: Text(
          AppL10n.of(context).famProgressTitle(widget.child.studentName),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failure != null || progress == null
          ? StudafyStatusCard(
              icon: Icons.error_outline_rounded,
              title: AppL10n.of(context).famErrorTitle,
              message: familyFailureText(context, _failure ?? Failure.unknown),
              actionLabel: AppL10n.of(context).famRetry,
              onAction: _load,
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Metric(
                  label: AppL10n.of(context).famProgressAverage,
                  value: progress.averagePercent == null
                      ? AppL10n.of(context).famProgressNone
                      : '${progress.averagePercent!.toStringAsFixed(0)}%',
                  detail: AppL10n.of(context)
                      .famProgressGraded('${progress.gradedCount}'),
                ),
                const SizedBox(height: 10),
                _Metric(
                  label: AppL10n.of(context).famProgressAttendance,
                  value: progress.attendancePercent == null
                      ? AppL10n.of(context).famProgressNone
                      : '${progress.attendancePercent!.toStringAsFixed(0)}%',
                  detail:
                      '${AppL10n.of(context).famProgressSessions('${progress.sessions}')}\n'
                      '${AppL10n.of(context).famProgressBreakdown('${progress.present}', '${progress.late}', '${progress.absent}', '${progress.excused}')}',
                ),
                const SizedBox(height: 16),
                Text(
                  AppL10n.of(context).famProgressSource,
                  style: const TextStyle(color: studafyMuted, fontSize: 12),
                ),
              ],
            ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '$label: $value. $detail',
    child: ExcludeSemantics(
      child: FeatureCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: studafyMuted)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: studafyInk,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              style: const TextStyle(color: studafyMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}
