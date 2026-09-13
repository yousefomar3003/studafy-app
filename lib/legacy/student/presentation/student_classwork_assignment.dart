import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../studafy_database.dart';
import 'student_shared.dart';

class StudentAssignmentCard extends StatelessWidget {
  const StudentAssignmentCard({
    super.key,
    required this.item,
    required this.onTap,
  });
  final Map<String, Object?> item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final status = studentAssignmentStatus(item),
        color = studentStatusColor(status);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: .24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Color(
                        ('${item['class_name']}'.hashCode & 0x00FFFFFF) |
                            0xFF000000,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '${item['class_name']}',
                      style: const TextStyle(
                        color: studentMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  StudentWorkStatus(label: status, color: color),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                '${item['title']}',
                style: const TextStyle(
                  color: studentNavy,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 15,
                    color: status == 'Late' ? color : studentMuted,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      status == 'Late'
                          ? 'Overdue · ${studentShortDate('${item['due_at']}')}'
                          : 'Due ${studentShortDate('${item['due_at']}')}',
                      style: TextStyle(
                        color: status == 'Late' ? color : studentMuted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  if (item['score'] != null)
                    Text(
                      'Score ${studentScore(item['score'])}',
                      style: const TextStyle(
                        color: studentNavy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StudentAssignmentDetail extends StatefulWidget {
  const StudentAssignmentDetail({
    super.key,
    required this.item,
    required this.studentId,
  });
  final Map<String, Object?> item;
  final int studentId;
  @override
  State<StudentAssignmentDetail> createState() =>
      _StudentAssignmentDetailState();
}

class _StudentAssignmentDetailState extends State<StudentAssignmentDetail> {
  final files = <Map<String, String>>[];
  bool submitting = false;

  Future<void> _pick() async {
    final result = await FilePicker.pickFiles();
    for (final file in result) {
      if (file.path == null) continue;
      final stored = await StudafyDatabase.instance.persistAttachmentFile(
        file.path!,
        file.name,
      );
      files.add({
        'kind': _kindForFile(file.name),
        'name': file.name,
        'uri': stored,
      });
    }
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    if (files.isEmpty) return;
    setState(() => submitting = true);
    final submissionId = await StudafyDatabase.instance.submitAssignment(
      widget.item['id'] as int,
      widget.studentId,
    );
    await StudafyDatabase.instance.addAttachments(
      'submission',
      submissionId,
      files,
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFF15885D),
          size: 42,
        ),
        title: const Text('Assignment submitted'),
        content: const Text(
          'Your files were uploaded successfully. You can return before the deadline to add a revised submission.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: studentCanvas,
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: const Text('Assignment'),
      actions: [
        const CircleAvatar(
          radius: 18,
          backgroundColor: studentNavy,
          child: Text(
            'LH',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 14),
      ],
    ),
    body: FutureBuilder<List<List<Map<String, Object?>>>>(
      future: Future.wait([
        StudafyDatabase.instance.attachments(
          'assignment',
          widget.item['id'] as int,
        ),
        if (widget.item['submission_id'] != null)
          StudafyDatabase.instance.attachments(
            'submission',
            widget.item['submission_id'] as int,
          )
        else
          Future.value(<Map<String, Object?>>[]),
      ]),
      builder: (context, snapshot) {
        final teacherFiles = snapshot.data?[0] ?? [],
            submittedFiles = snapshot.data?[1] ?? [];
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '${widget.item['class_name']}',
              style: const TextStyle(
                color: studentMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              '${widget.item['title']}',
              style: const TextStyle(
                color: studentNavy,
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Due ${widget.item['due_at']}',
              style: const TextStyle(color: studentMuted),
            ),
            const SizedBox(height: 18),
            const Text(
              'Instructions',
              style: TextStyle(
                color: studentNavy,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Complete the work using the lesson material in your Notebook. Include clear working or sources where appropriate, then review every attached file before submitting.',
              style: TextStyle(color: Color(0xFF626981), height: 1.45),
            ),
            if (teacherFiles.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text(
                'Teacher attachments',
                style: TextStyle(
                  color: studentNavy,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              for (final file in teacherFiles) _ClassworkFile(item: file),
            ],
            const SizedBox(height: 20),
            const Text(
              'Your submission',
              style: TextStyle(
                color: studentNavy,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            if (submittedFiles.isNotEmpty) ...[
              for (final file in submittedFiles) _ClassworkFile(item: file),
              const SizedBox(height: 8),
            ],
            for (var i = 0; i < files.length; i++)
              _ClassworkFile(
                item: files[i],
                onRemove: () => setState(() => files.removeAt(i)),
              ),
            OutlinedButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.upload_file_rounded),
              label: Text(
                files.isEmpty ? 'Add submission files' : 'Add more files',
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFAED),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Accepted: images, PDF, Word, slides, spreadsheets, audio, video, and other teacher-approved files.',
                style: TextStyle(color: Color(0xFF8A7650), fontSize: 10),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: files.isEmpty || submitting ? null : _submit,
              icon: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                widget.item['submitted_at'] == null
                    ? 'Submit assignment'
                    : 'Submit revision',
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _ClassworkFile extends StatelessWidget {
  const _ClassworkFile({required this.item, this.onRemove});
  final Map<String, Object?> item;
  final VoidCallback? onRemove;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE0E2ED)),
    ),
    child: Row(
      children: [
        Icon(
          studentAttachmentIcon('${item['kind']}', '${item['name']}'),
          color: studentNavy,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '${item['name']}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: studentInk,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (onRemove != null)
          IconButton(
            onPressed: onRemove,
            icon: const Icon(
              Icons.close_rounded,
              color: studentMuted,
              size: 18,
            ),
          )
        else
          const Icon(Icons.download_outlined, color: studentMuted),
      ],
    ),
  );
}

String _kindForFile(String name) {
  final ext = name.toLowerCase().split('.').last;
  return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'].contains(ext)
      ? 'image'
      : 'file';
}
