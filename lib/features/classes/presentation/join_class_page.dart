import 'package:flutter/material.dart';

import '../../../core/class_join_link.dart';
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
    // Accepts the whole link or the bare token: people paste both, and
    // working out which half to copy is not the student's job.
    final token = classJoinTokenFrom(_controller.text);
    if (token == null) {
      setState(() => _error = 'That does not look like a class link.');
      return;
    }
    setState(() {
      _joining = true;
      _error = null;
    });
    final result = await widget.classes.joinWithLink(token);
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
        _error = failure.message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final joined = _joined;
    return Scaffold(
      appBar: AppBar(title: const Text('Join a class')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: joined != null
              ? _JoinedView(joined: joined)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Paste the class link your teacher shared with you.',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _controller,
                      autofocus: widget.initialToken == null,
                      enabled: !_joining,
                      decoration: const InputDecoration(
                        labelText: 'Class link',
                        border: OutlineInputBorder(),
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
                      child: Text(_joining ? 'Joining…' : 'Join class'),
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
        "You're in ${joined.classroomName}",
        style: Theme.of(context).textTheme.titleLarge,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(joined),
        child: const Text('Done'),
      ),
    ],
  );
}
