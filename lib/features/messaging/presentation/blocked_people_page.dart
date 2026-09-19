import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/studafy_design.dart';
import '../domain/messaging.dart';
import 'messaging_scope.dart';
import 'messaging_strings.dart';

/// Everyone the user has blocked in one school, each with an Unblock
/// control. A block the user cannot see or undo would be a trap.
class BlockedPeoplePage extends StatefulWidget {
  const BlockedPeoplePage({
    super.key,
    required this.schoolId,
    required this.myUserId,
    this.knownPeople = const {},
  });

  final String schoolId;
  final String myUserId;

  /// Names already on screen, by user id. A block record carries only ids.
  final Map<String, String> knownPeople;

  @override
  State<BlockedPeoplePage> createState() => _BlockedPeoplePageState();
}

class _BlockedPeoplePageState extends State<BlockedPeoplePage> {
  List<BlockedPerson> _blocks = const [];
  Map<String, String> _names = const {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _names = widget.knownPeople;
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final interactor = MessagingScope.of(context);
    final blocks = await interactor.blocks(widget.schoolId);
    final contacts = await interactor.contacts(widget.schoolId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _names = {
        ...contacts.fold(
          onSuccess: (list) => {for (final c in list) c.userId: c.displayName},
          onFailure: (_) => const <String, String>{},
        ),
        ...widget.knownPeople,
      };
      blocks.fold(
        onSuccess: (list) {
          // Blocks others made against this user are not theirs to undo,
          // and listing them would disclose who blocked whom.
          _blocks = [
            for (final block in list)
              if (block.madeBy(widget.myUserId)) block,
          ];
          _error = null;
        },
        onFailure: (failure) => _error = messagingFailureText(context, failure),
      );
    });
  }

  Future<void> _unblock(BlockedPerson block) async {
    final result = await MessagingScope.of(context).unblock(block.blockId);
    if (!mounted) return;
    result.fold(
      onSuccess: (_) {
        setState(
          () => _blocks = [
            for (final b in _blocks)
              if (b.blockId != block.blockId) b,
          ],
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(messagingText(context, 'unblock.done'))),
        );
      },
      onFailure: (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messagingFailureText(context, failure))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => messagingText(context, key);
    return Scaffold(
      backgroundColor: studafyCanvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(t('blocked.title')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? StudafyStatusCard(
              icon: Icons.error_outline_rounded,
              title: t('error.title'),
              message: _error!,
              actionLabel: t('retry'),
              onAction: _load,
            )
          : _blocks.isEmpty
          ? StudafyStatusCard(
              icon: Icons.block_rounded,
              title: t('blocked.title'),
              message: t('blocked.empty'),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final block in _blocks)
                  FeatureCard(
                    child: Row(
                      children: [
                        const Icon(Icons.block_rounded, color: studafyMuted),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _names[block.blockedId] ?? t('unknownPerson'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _unblock(block),
                          child: Text(t('unblock')),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
