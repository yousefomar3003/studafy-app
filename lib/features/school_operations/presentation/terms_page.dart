import 'package:flutter/material.dart';

import '../../../core/studafy_design.dart';
import '../../../core/failures.dart';
import '../domain/school_operations_repository.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../../../core/feedback.dart';
import '../../../core/studafy_formatting.dart';

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

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: studafyCanvas,
    appBar: AppBar(
      title: Text(AppL10n.of(context).termsAcademicTerms),
      actions: [
        IconButton(
          onPressed: _create,
          icon: const Icon(Icons.add),
          tooltip: AppL10n.of(context).termsCreateTerm,
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
                  Text(AppL10n.of(context).termsNoTermsCreated),
                for (final term in _terms)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.date_range_outlined),
                      title: Text(term.name),
                      subtitle: Text(
                        '${studafyShortDate(context, term.startsOn)} – ${studafyShortDate(context, term.endsOn)}',
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
              title: Text(AppL10n.of(context).termsCreateAcademicTerm),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: InputDecoration(
                      labelText: AppL10n.of(context).termsName,
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(AppL10n.of(context).termsStarts),
                    subtitle: Text(studafyShortDate(context, starts)),
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
                    title: Text(AppL10n.of(context).termsEnds),
                    subtitle: Text(studafyShortDate(context, ends)),
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
                  child: Text(AppL10n.of(context).academicCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(AppL10n.of(context).termsCreate),
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
        ScaffoldMessenger.of(context)
            .showMessage(AppL10n.of(context).termsTermCreated);
        await _load();
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showMessage(Failure.fromError(error).message);
      }
    }
  }
}
