import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/feedback.dart';
import '../../../core/studafy_components.dart';
import '../../../core/studafy_design.dart';
import '../../../l10n/generated/app_l10n.dart';
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

  /// Blocks being undone right now, so each button shows it is working and
  /// cannot be pressed twice.
  final Set<String> _unblocking = {};

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
    if (!_unblocking.add(block.blockId)) return;
    setState(() {});
    final result = await MessagingScope.of(context).unblock(block.blockId);
    if (!mounted) return;
    setState(() => _unblocking.remove(block.blockId));
    result.fold(
      onSuccess: (_) {
        setState(
          () => _blocks = [
            for (final b in _blocks)
              if (b.blockId != block.blockId) b,
          ],
        );
        ScaffoldMessenger.of(context)
            .showMessage(AppL10n.of(context).msgUnblockDone);
      },
      onFailure: (failure) =>
          ScaffoldMessenger.of(context)
              .showMessage(messagingFailureText(context, failure)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.msgBlockedTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: StudafyEmptyState(
                icon: Icons.wifi_off_rounded,
                title: l10n.msgErrorTitle,
                message: _error!,
                actionLabel: l10n.msgRetry,
                onAction: _load,
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 14),
                    child: Text(
                      l10n.msgBlockedIntro,
                      style: const TextStyle(color: studafyMuted, height: 1.4),
                    ),
                  ),
                  if (_blocks.isEmpty)
                    StudafyEmptyState(
                      icon: Icons.verified_user_outlined,
                      title: l10n.msgBlockedEmpty,
                      message: l10n.msgBlockedEmptyDetail,
                    )
                  else
                    FeatureCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (final (index, block) in _blocks.indexed) ...[
                            if (index > 0)
                              const Divider(
                                height: 1,
                                indent: 72,
                                color: studafyHairline,
                              ),
                            _BlockedRow(
                              name:
                                  _names[block.blockedId] ??
                                  l10n.msgUnknownPerson,
                              busy: _unblocking.contains(block.blockId),
                              onUnblock: () => _unblock(block),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

/// One blocked person: who, and the way to undo it.
class _BlockedRow extends StatelessWidget {
  const _BlockedRow({
    required this.name,
    required this.onUnblock,
    this.busy = false,
  });

  final String name;
  final VoidCallback onUnblock;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 12, 12),
      child: Row(
        children: [
          InitialsAvatar(name: name, radius: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: studafyInk,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.block_rounded,
                      size: 14,
                      color: studafyMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      l10n.msgBlockedLabel,
                      style: const TextStyle(
                        color: studafyMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: busy ? null : onUnblock,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 44),
              foregroundColor: studafyNavy,
              side: const BorderSide(color: studafyHairline),
              shape: const StadiumBorder(),
            ),
            child: busy
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.msgUnblock),
          ),
        ],
      ),
    );
  }
}
