import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';

import 'studafy_database.dart';
import 'student_linking.dart';
import 'core/studafy_design.dart' show FeatureCard;
import 'core/studafy_domain.dart';
import 'core/studafy_localizations.dart';
import 'core/runtime_environment.dart';
import 'data/backend.dart';
import 'data/studafy_repository.dart';
import 'data/supabase_repository.dart';
import 'data/session_service.dart';
import 'features/account/presentation/delete_account_page.dart';

part 'legacy/teacher/presentation/teacher_shared.dart';
part 'legacy/teacher/presentation/class_workspace_page.dart';
part 'legacy/teacher/presentation/gradebook_page.dart';
part 'legacy/teacher/presentation/assessment_detail_page.dart';
part 'legacy/teacher/presentation/content_page.dart';
part 'legacy/teacher/presentation/communications_page.dart';
part 'legacy/teacher/presentation/communications_forms.dart';
part 'legacy/teacher/presentation/chats_page.dart';
part 'legacy/teacher/presentation/notifications_page.dart';
part 'legacy/teacher/presentation/teacher_account_page.dart';
part 'legacy/teacher/presentation/family_workspace_page.dart';
part 'legacy/teacher/presentation/profile_page.dart';
part 'legacy/teacher/presentation/policies_page.dart';
part 'legacy/teacher/presentation/connections_page.dart';
