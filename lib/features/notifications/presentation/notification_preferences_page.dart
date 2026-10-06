import 'package:flutter/material.dart';

import '../../../core/feedback.dart';
import '../../../core/studafy_design.dart';
import '../../../core/studafy_domain.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/notifications_repository.dart';
import 'notifications_scope.dart';

class NotificationPreferencesPage extends StatefulWidget {
  const NotificationPreferencesPage({super.key});
  @override
  State<NotificationPreferencesPage> createState() =>
      _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState
    extends State<NotificationPreferencesPage> {
  List<NotificationPreference> _items = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await NotificationsScope.of(context).loadPreferences();
    if (!mounted) return;
    result.fold(
      onSuccess: (value) => setState(() {
        _items = value;
        _loading = false;
      }),
      onFailure: (failure) => setState(() {
        _error = failure.message;
        _loading = false;
      }),
    );
  }

  Future<void> _toggle(NotificationPreference item, bool enabled) async {
    if (_saving) return;
    setState(() => _saving = true);
    final updated = item.copyWith(enabled: enabled);
    setState(
      () => _items = [
        for (final value in _items) value == item ? updated : value,
      ],
    );
    final result = await NotificationsScope.of(context)
        .updatePreference(updated);
    if (!mounted) return;
    setState(() => _saving = false);
    result.fold(
      onSuccess: (_) {},
      onFailure: (failure) {
        setState(
          () => _items = [
            for (final value in _items) value == updated ? item : value,
          ],
        );
        ScaffoldMessenger.of(context).showMessage(failure.message);
      },
    );
  }

  Future<void> _add() async {
    final interactor = NotificationsScope.of(context);
    var channel = 'in_app';
    var category = 'academic';
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialog) => AlertDialog(
              title: Text(AppL10n.of(context).notificationPrefsAddPreference),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: channel,
                    decoration: InputDecoration(
                      labelText: AppL10n.of(context).notificationPrefsChannel,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'in_app',
                        child: Text(AppL10n.of(context).notificationPrefsInApp),
                      ),
                      DropdownMenuItem(
                        value: 'email',
                        child: Text(AppL10n.of(context).notificationPrefsEmail),
                      ),
                      DropdownMenuItem(
                        value: 'push',
                        child: Text(AppL10n.of(context).notificationPrefsPush),
                      ),
                    ],
                    onChanged: (value) => setDialog(() => channel = value!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: InputDecoration(
                      labelText: AppL10n.of(context).notificationPrefsCategory,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'academic',
                        child: Text(
                          AppL10n.of(context).notificationPrefsAcademic,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'communications',
                        child: Text(
                          AppL10n.of(context)
                              .notificationPrefsMessagesAndAnnouncements,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'meetings',
                        child: Text(
                          AppL10n.of(context).notificationPrefsMeetings,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'family',
                        child: Text(
                          AppL10n.of(context).notificationPrefsFamily,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'billing',
                        child: Text(
                          AppL10n.of(context).notificationPrefsBilling,
                        ),
                      ),
                    ],
                    onChanged: (value) => setDialog(() => category = value!),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(AppL10n.of(context).academicCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(AppL10n.of(context).notificationPrefsAdd),
                ),
              ],
            ),
          ),
        ) ??
        false;
    if (!mounted || !ok) return;
    final existing = _items
        .where(
          (item) =>
              item.schoolId ==
                  ActiveContextController.instance.membership?.schoolId &&
              item.channel == channel &&
              item.category == category,
        )
        .firstOrNull;
    if (existing != null) {
      await _toggle(existing, true);
      return;
    }
    final preference = NotificationPreference(
      schoolId: ActiveContextController.instance.membership?.schoolId,
      channel: channel,
      category: category,
      enabled: true,
    );
    final result = await interactor.updatePreference(preference);
    if (!mounted) return;
    result.fold(
      onSuccess: (value) => setState(() => _items = [..._items, value]),
      onFailure: (failure) =>
          ScaffoldMessenger.of(context).showMessage(failure.message),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: studafyCanvas,
    appBar: AppBar(
      title: Text(AppL10n.of(context).notificationsNotificationPreferences),
      actions: [
        IconButton(
          onPressed: _add,
          icon: const Icon(Icons.add),
          tooltip: AppL10n.of(context).notificationPrefsAddPreference,
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(child: Text(_error!))
        : StudafyRefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFAED),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    AppL10n.of(context)
                        .notificationPrefsPushPreferencesAreSavedBut,
                    style: const TextStyle(color: Color(0xFF8A7650)),
                  ),
                ),
                const SizedBox(height: 12),
                if (_items.isEmpty)
                  Text(
                    AppL10n.of(context)
                        .notificationPrefsNoPreferencesSavedAddOne,
                  ),
                for (final item in _items)
                  Card(
                    child: SwitchListTile(
                      value: item.enabled,
                      onChanged: (value) => _toggle(item, value),
                      title: Text(_category(item.category)),
                      subtitle: Text(_channel(item.channel)),
                    ),
                  ),
              ],
            ),
          ),
  );

  String _channel(String value) => switch (value) {
    'in_app' => AppL10n.of(context).notificationPrefsInApp,
    'email' => AppL10n.of(context).notificationPrefsEmail,
    'push' => AppL10n.of(context).notificationPrefsPush,
    _ => value,
  };
  String _category(String value) => switch (value) {
    'academic' => AppL10n.of(context).notificationPrefsAcademic,
    'communications' => AppL10n.of(
      context,
    ).notificationPrefsMessagesAndAnnouncements,
    'meetings' => AppL10n.of(context).notificationPrefsMeetings,
    'family' => AppL10n.of(context).notificationPrefsFamily,
    'billing' => AppL10n.of(context).notificationPrefsBilling,
    _ => value,
  };
}
