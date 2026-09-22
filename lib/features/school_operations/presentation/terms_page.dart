import 'package:flutter/material.dart';

import '../../../core/studafy_design.dart';
import '../../../core/failures.dart';
import '../domain/school_operations_repository.dart';

class TermsPage extends StatefulWidget {
  const TermsPage({super.key, required this.repository});
  final SchoolOperationsRepository repository;

  @override
  State<TermsPage> createState() => _TermsPageState();
}

class _TermsPageState extends State<TermsPage> {
  List<SchoolTerm> _terms = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final value = await widget.repository.listTerms();
      if (mounted) {
        setState(() {
          _terms = value;
          _loading = false;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error = Failure.fromError(error).message;
          _loading = false;
        });
      }
    }
  }

  String _t(String en, String ar) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: studafyCanvas,
    appBar: AppBar(
      title: Text(_t('Academic terms', 'الفصول الدراسية')),
      actions: [
        IconButton(
          onPressed: _create,
          icon: const Icon(Icons.add),
          tooltip: _t('Create term', 'إنشاء فصل دراسي'),
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
                if (_terms.isEmpty)
                  Text(_t('No terms created.', 'لم يتم إنشاء فصول دراسية.')),
                for (final term in _terms)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.date_range_outlined),
                      title: Text(term.name),
                      subtitle: Text(
                        '${_date(term.startsOn)} – ${_date(term.endsOn)}',
                      ),
                      trailing: Chip(label: Text(term.status)),
                    ),
                  ),
              ],
            ),
          ),
  );

  Future<void> _create() async {
    final name = TextEditingController();
    var starts = DateTime.now();
    var ends = DateTime.now().add(const Duration(days: 120));
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialog) => AlertDialog(
              title: Text(_t('Create academic term', 'إنشاء فصل دراسي')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: InputDecoration(labelText: _t('Name', 'الاسم')),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_t('Starts', 'البداية')),
                    subtitle: Text(_date(starts)),
                    onTap: () async {
                      final value = await showDatePicker(
                        context: context,
                        initialDate: starts,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2040),
                      );
                      if (value != null && context.mounted) {
                        setDialog(() {
                          starts = value;
                          if (!ends.isAfter(starts)) {
                            ends = starts.add(const Duration(days: 1));
                          }
                        });
                      }
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_t('Ends', 'النهاية')),
                    subtitle: Text(_date(ends)),
                    onTap: () async {
                      final value = await showDatePicker(
                        context: context,
                        initialDate: ends,
                        firstDate: starts.add(const Duration(days: 1)),
                        lastDate: DateTime(2040),
                      );
                      if (value != null) setDialog(() => ends = value);
                    },
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
                  child: Text(_t('Create', 'إنشاء')),
                ),
              ],
            ),
          ),
        ) ??
        false;
    if (!ok || name.text.trim().isEmpty) return;
    try {
      await widget.repository.createTerm(
        name: name.text,
        startsOn: starts,
        endsOn: ends,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t('Term created.', 'تم إنشاء الفصل الدراسي.')),
          ),
        );
        await _load();
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(Failure.fromError(error).message)),
        );
      }
    }
  }

  static String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
