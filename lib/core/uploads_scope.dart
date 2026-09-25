import 'package:flutter/widgets.dart';

import 'file_upload_repository.dart';

/// Makes the upload pipeline reachable from any screen that offers an
/// attachment control.
///
/// A scope rather than a constructor argument because the screens that need it
/// are opened from several places each - a conversation from the inbox, from a
/// notification, from a class roster - and threading the repository through
/// every one of those call sites is how one of them ends up passing null and
/// silently losing the attach button.
///
/// Installed above the app Navigator, so pushed routes see it too.
class UploadsScope extends InheritedWidget {
  const UploadsScope({super.key, required this.uploads, required super.child});

  final FileUploadRepository uploads;

  /// Null when no scope is installed. Callers hide the attachment control
  /// rather than offering one with nowhere to send bytes.
  static FileUploadRepository? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<UploadsScope>()?.uploads;

  @override
  bool updateShouldNotify(UploadsScope oldWidget) =>
      uploads != oldWidget.uploads;
}
