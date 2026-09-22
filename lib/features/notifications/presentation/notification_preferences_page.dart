import 'package:flutter/material.dart';

import '../../../core/studafy_design.dart';
import '../../../core/studafy_domain.dart';
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

  String _t(String en, String ar) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure.message)));
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
              title: Text(_t('Add preference', 'إضافة تفضيل')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: channel,
                    decoration: InputDecoration(
                      labelText: _t('Channel', 'القناة'),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'in_app',
                        child: Text(_t('In app', 'داخل التطبيق')),
                      ),
                      DropdownMenuItem(
                        value: 'email',
                        child: Text(_t('Email', 'البريد الإلكتروني')),
                      ),
                      DropdownMenuItem(
                        value: 'push',
                        child: Text(_t('Push', 'إشعار فوري')),
                      ),
                    ],
                    onChanged: (value) => setDialog(() => channel = value!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: InputDecoration(
                      labelText: _t('Category', 'الفئة'),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'academic',
                        child: Text(_t('Academic', 'أكاديمي')),
                      ),
                      DropdownMenuItem(
                        value: 'communications',
                        child: Text(
                          _t(
                            'Messages and announcements',
                            'الرسائل والإعلانات',
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'meetings',
                        child: Text(_t('Meetings', 'الاجتماعات')),
                      ),
                      DropdownMenuItem(
                        value: 'family',
                        child: Text(_t('Family', 'العائلة')),
                      ),
                      DropdownMenuItem(
                        value: 'billing',
                        child: Text(_t('Billing', 'الفوترة')),
                      ),
                    ],
                    onChanged: (value) => setDialog(() => category = value!),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(_t('Cancel', 'إلغاء')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(_t('Add', 'إضافة')),
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
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: studafyCanvas,
    appBar: AppBar(
      title: Text(_t('Notification preferences', 'تفضيلات الإشعارات')),
      actions: [
        IconButton(
          onPressed: _add,
          icon: const Icon(Icons.add),
          tooltip: _t('Add preference', 'إضافة تفضيل'),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(child: Text(_error!))
        : RefreshIndicator(
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
                    _t(
                      'Push preferences are saved, but push delivery is not available on this device yet.',
                      'يتم حفظ تفضيلات الإشعارات الفورية، لكن استقبالها غير متاح على هذا الجهاز بعد.',
                    ),
                    style: const TextStyle(color: Color(0xFF8A7650)),
                  ),
                ),
                const SizedBox(height: 12),
                if (_items.isEmpty)
                  Text(
                    _t(
                      'No preferences saved. Add one to choose a channel and category.',
                      'لا توجد تفضيلات محفوظة. أضف تفضيلًا لاختيار القناة والفئة.',
                    ),
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
    'in_app' => _t('In app', 'داخل التطبيق'),
    'email' => _t('Email', 'البريد الإلكتروني'),
    'push' => _t('Push', 'إشعار فوري'),
    _ => value,
  };
  String _category(String value) => switch (value) {
    'academic' => _t('Academic', 'أكاديمي'),
    'communications' => _t('Messages and announcements', 'الرسائل والإعلانات'),
    'meetings' => _t('Meetings', 'الاجتماعات'),
    'family' => _t('Family', 'العائلة'),
    'billing' => _t('Billing', 'الفوترة'),
    _ => value,
  };
}
