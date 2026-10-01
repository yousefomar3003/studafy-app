import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/failures.dart';
import '../../core/feedback.dart';
import '../../core/studafy_components.dart';
import '../../features/account/application/account_interactor.dart';
import '../../features/account/domain/data_export.dart';
import '../../l10n/generated/app_l10n.dart';
import 'account_text.dart';

/// Right of access (DL-051): ask for a copy of your data, then share the
/// finished JSON file. Hidden in builds with no server to export from.
class DataExportTile extends StatefulWidget {
  const DataExportTile({super.key, required this.account});

  final AccountInteractor account;

  @override
  State<DataExportTile> createState() => _DataExportTileState();
}

class _DataExportTileState extends State<DataExportTile> {
  DataExportStatus? _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.account.exportAvailable) _refresh();
  }

  Future<void> _refresh() async {
    final result = await widget.account.exportStatus();
    if (!mounted) return;
    setState(
      () => _status = result.fold(onSuccess: (s) => s, onFailure: (_) => null),
    );
  }

  void _say(String key) =>
      ScaffoldMessenger.of(context).showMessage(accountText(context, key));

  Future<void> _request() async {
    setState(() => _busy = true);
    final result = await widget.account.requestExport();
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold(
      onSuccess: (status) {
        setState(() => _status = status);
        _say('export.requested');
      },
      onFailure: (failure) => _say(
        failure.code == 'REAUTH_REQUIRED' ? 'export.reauth' : 'export.failed',
      ),
    );
  }

  Future<void> _download() async {
    setState(() => _busy = true);
    final result = await widget.account.downloadExport();
    if (!mounted) return;
    setState(() => _busy = false);
    final json = result.fold<String?>(
      onSuccess: (v) => v,
      onFailure: (_) => null,
    );
    if (json == null) {
      _say(
        result.fold(onSuccess: (_) => '', onFailure: (f) => f.code) ==
                Failure.notFoundCode
            ? 'export.expired'
            : 'export.failed',
      );
      await _refresh();
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            utf8.encode(json),
            name: 'studafy-my-data.json',
            mimeType: 'application/json',
          ),
        ],
        fileNameOverrides: const ['studafy-my-data.json'],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.account.exportAvailable) return const SizedBox.shrink();
    final state = _status?.state;
    final ready = state == DataExportState.ready;
    final pending = state == DataExportState.pending;
    return SettingsRow(
      icon: Icons.download_rounded,
      title: AppL10n.of(context).accountExport,
      subtitle: ready
          ? AppL10n.of(context).accountExportReady
          : pending
          ? AppL10n.of(context).accountExportPending
          : AppL10n.of(context).accountExportDetail,
      trailing: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton(
              onPressed: ready ? _download : (pending ? _refresh : _request),
              child: Text(
                ready
                    ? AppL10n.of(context).accountExportDownload
                    : pending
                    ? AppL10n.of(context).accountExportCheck
                    : AppL10n.of(context).accountExportRequest,
              ),
            ),
    );
  }
}
