import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/studafy_design.dart';
import '../domain/messaging.dart';
import 'messaging_scope.dart';
import 'messaging_strings.dart';
import '../../../l10n/generated/app_l10n.dart';

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
          SnackBar(content: Text(AppL10n.of(context).msgUnblockDone)),
        );
      },
      onFailure: (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messagingFailureText(context, failure))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: studafyCanvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(AppL10n.of(context).msgBlockedTitle),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? StudafyStatusCard(
              icon: Icons.error_outline_rounded,
              title: AppL10n.of(context).msgErrorTitle,
              message: _error!,
              actionLabel: AppL10n.of(context).msgRetry,
              onAction: _load,
            )
          : _blocks.isEmpty
          ? StudafyStatusCard(
              icon: Icons.block_rounded,
              title: AppL10n.of(context).msgBlockedTitle,
              message: AppL10n.of(context).msgBlockedEmpty,
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
                            _names[block.blockedId] ??
                                AppL10n.of(context).msgUnknownPerson,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _unblock(block),
                          child: Text(AppL10n.of(context).msgUnblock),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
