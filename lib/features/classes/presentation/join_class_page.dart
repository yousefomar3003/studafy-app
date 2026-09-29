import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/class_join_link.dart';
import '../../../core/failures.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../application/class_list_interactor.dart';
import '../domain/classroom.dart';

/// Where a student redeems a class link their teacher shared (JOIN-052).
///
/// Opened either from a tapped link, with [initialToken] already filled in,
/// or from the student's own screen when they were sent the link some other
/// way and are pasting it by hand.
class JoinClassPage extends StatefulWidget {
  const JoinClassPage({
    super.key,
    required this.classes,
    this.initialToken,
    this.onJoined,
  });

  final ClassListInteractor classes;

  /// Token recovered from a tapped link, if the student arrived that way.
  final String? initialToken;

  /// Called once the student is in the class, so the shell can refresh.
  final ValueChanged<JoinedClass>? onJoined;

  @override
  State<JoinClassPage> createState() => _JoinClassPageState();
}

class _JoinClassPageState extends State<JoinClassPage> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialToken ?? '',
  );
  bool _joining = false;
  String? _error;
  JoinedClass? _joined;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (_joining) return;
    // Accepts a class code, the whole link or the bare token: people type
    // the first and paste the other two, and working out which they were
    // given is not the student's job.
    final credential = classJoinCredentialFrom(_controller.text);
    if (credential == null) {
      setState(() => _error = AppL10n.of(context).joinClassInvalid);
      return;
    }
    setState(() {
      _joining = true;
      _error = null;
    });
    final result = await switch (credential) {
      ClassJoinToken(:final token) => widget.classes.joinWithLink(token),
      ClassJoinCode(:final code) => widget.classes.joinWithCode(code),
    };
    if (!mounted) return;
    result.fold(
      onSuccess: (joined) {
        setState(() {
          _joining = false;
          _joined = joined;
        });
        widget.onJoined?.call(joined);
      },
      onFailure: (failure) => setState(() {
        _joining = false;
        // Redeeming refuses with FORBIDDEN for exactly one reason: this
        // account already teaches at, or otherwise staffs, the school the
        // link belongs to, and opening your own link must not move you into
        // your own class roster. The generic "no access" wording sent a
        // teacher checking their own link looking for a permissions fault
        // that does not exist, so it is named here.
        _error = failure.code == Failure.forbiddenCode
            ? AppL10n.of(context).joinClassAlreadyStaff
            : failure.message;
      }),
    );
  }

  /// Reads the clipboard only when asked, never on its own.
  ///
  /// iOS offers Paste in the text menu only when there is text to paste, so an
  /// empty clipboard used to leave nothing but "Scan Text" and no hint why.
  /// The usual reason is that the link was copied on another account and a
  /// sign-in in between replaced it, so the message points at the two ways
  /// that do not depend on the clipboard at all.
  Future<void> _paste() async {
    final l10n = AppL10n.of(context);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      setState(() => _error = l10n.joinClassNothingToPaste);
      return;
    }
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final joined = _joined;
    final l10n = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.joinClassTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: joined != null
              ? _JoinedView(joined: joined)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.joinClassPrompt),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _controller,
                      autofocus: widget.initialToken == null,
                      enabled: !_joining,
                      // A code is typed in capitals; a link is pasted whole.
                      // Neither wants autocorrect rewriting it.
                      textCapitalization: TextCapitalization.characters,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: l10n.joinClassField,
                        hintText: 'K7QM-4XTR',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: l10n.joinClassPaste,
                          icon: const Icon(Icons.content_paste_rounded),
                          onPressed: _joining ? null : _paste,
                        ),
                      ),
                      onSubmitted: (_) => _join(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _joining ? null : _join,
                      child: Text(
                        _joining ? l10n.joinClassBusy : l10n.joinClassAction,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _JoinedView extends StatelessWidget {
  const _JoinedView({required this.joined});

  final JoinedClass joined;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.check_circle_outline, size: 56),
      const SizedBox(height: 16),
      Text(
        AppL10n.of(context).joinClassDone(joined.classroomName),
        style: Theme.of(context).textTheme.titleLarge,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(joined),
        child: Text(AppL10n.of(context).joinClassContinue),
      ),
    ],
  );
}
