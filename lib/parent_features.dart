import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/studafy_design.dart';
import 'core/studafy_domain.dart';
import 'core/studafy_localizations.dart';
import 'student_linking.dart';
import 'app/account_scope.dart';
import 'features/account/presentation/delete_account_page.dart';
import 'features/parent/domain/parent_subscription_repository.dart';
import 'features/parent/presentation/parent_repository_scope.dart';

part 'features/parent/presentation/parent_shell.dart';
part 'features/parent/presentation/parent_home.dart';
part 'features/parent/presentation/parent_academics.dart';
part 'features/parent/presentation/parent_academic_components.dart';
part 'features/parent/presentation/parent_insights.dart';
part 'features/parent/presentation/parent_insight_components.dart';
part 'features/parent/presentation/parent_behaviours.dart';
part 'features/parent/presentation/parent_account.dart';
part 'features/parent/presentation/parent_account_components.dart';
part 'features/parent/presentation/parent_messages.dart';
part 'features/parent/presentation/parent_message_components.dart';

const _navy = Color(0xFF241D73);
const _cyan = Color(0xFF20C6E8);
const _ink = Color(0xFF171441);
const _muted = Color(0xFF9299B4);
const _canvas = Color(0xFFF7F6FE);

int _activeChildIndex(List<Map<String, Object?>> rows, int fallback) {
  final activeId = ActiveContextController.instance.selectedStudent?.id;
  final found = rows.indexWhere((row) => '${row['student_id']}' == activeId);
  return found >= 0
      ? found
      : fallback.clamp(0, rows.isEmpty ? 0 : rows.length - 1);
}

void _rememberChild(Map<String, Object?> row) {
  ActiveContextController.instance.selectStudent(
    StudentSummary(
      id: '${row['student_id']}',
      studafyId: '${row['studafy_id']}',
      displayName: '${row['student_name']}',
      verified: row['provisional'] != 1,
    ),
  );
}
