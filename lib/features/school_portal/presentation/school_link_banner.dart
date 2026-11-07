import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/feedback.dart';
import '../../../core/studafy_design.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../application/school_links_interactor.dart';
import 'school_link_text.dart';

/// "Your classes are visible to (the school)." on the teacher's Today and
/// Classes tabs, with Unlink one tap (and a confirmation) away. Nothing at
/// all while no school is linked.
class SchoolLinkBanner extends StatefulWidget {
  const SchoolLinkBanner({super.key, required this.links});

  final SchoolLinksInteractor links;

  @override
  State<SchoolLinkBanner> createState() => _SchoolLinkBannerState();
}

class _SchoolLinkBannerState extends State<SchoolLinkBanner> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Read once per app run; every change on the School pages re-reads it.
    if (widget.links.current.value == null) unawaited(widget.links.load());
  }

  Future<void> _unlink() async {
    final link = widget.links.linked;
    if (link == null) return;
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await confirmSchoolLink(
      context,
      title: l10n.schoolLinkUnlinkTitle,
      body: l10n.schoolLinkUnlinkBody(link.org.name),
      confirm: l10n.schoolLinkUnlink,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    final result = await widget.links.unlink(link);
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold(
      onSuccess: (_) => messenger.showMessage(l10n.schoolLinkUnlinked),
      onFailure: (failure) =>
          messenger.showMessage(schoolLinkFailureText(l10n, failure)),
    );
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: widget.links.current,
    builder: (context, _, _) {
      final link = widget.links.linked;
      if (link == null) return const SizedBox.shrink();
      final l10n = AppL10n.of(context);
      return Padding(
        padding: const EdgeInsetsDirectional.only(bottom: 12),
        child: FeatureCard(
          tint: studafyWash,
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 12),
          child: Row(
            children: [
              const Icon(Icons.visibility_outlined, color: studafyNavy),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.schoolLinkBanner(link.org.name),
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: _busy ? null : _unlink,
                child: Text(l10n.schoolLinkUnlink),
              ),
            ],
          ),
        ),
      );
    },
  );
}
