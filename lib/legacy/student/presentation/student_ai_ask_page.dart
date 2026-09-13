import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/runtime_environment.dart';
import '../../../features/study_coach/presentation/study_coach_scope.dart';
import 'student_shared.dart';

class AskAiPage extends StatefulWidget {
  const AskAiPage({super.key});
  @override
  State<AskAiPage> createState() => _AskAiPageState();
}

class _AskAiPageState extends State<AskAiPage> {
  final controller = TextEditingController();
  final messages = <({bool user, String body})>[];
  String? attachment, attachmentLocalPath;
  bool sending = false;

  Future<void> _attach() async {
    if (!StudafyRuntime.policy.allowsRemoteFileUploads) return;
    final files = await FilePicker.pickFiles();
    if (files.isNotEmpty && files.first.path != null) {
      setState(() {
        attachment = files.first.name;
        attachmentLocalPath = files.first.path;
      });
    }
  }

  Future<void> _send() async {
    final value = controller.text.trim();
    if (value.isEmpty || sending) return;
    setState(() {
      sending = true;
      messages.add((user: true, body: value));
      messages.add((user: false, body: 'Reading your authorized materials…'));
      controller.clear();
    });
    try {
      final answer = await StudyCoachScope.read(context).ask(question: value);
      if (mounted) {
        setState(
          () => messages[messages.length - 1] = (user: false, body: answer),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => messages[messages.length - 1] = (
            user: false,
            body: '$error'.replaceFirst('Bad state: ', ''),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          sending = false;
          attachment = null;
          attachmentLocalPath = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: studentCanvas,
    appBar: AppBar(title: const Text('Ask Me')),
    body: Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(35),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 45,
                          color: studentNavy,
                        ),
                        SizedBox(height: 14),
                        Text(
                          'Ask about your class materials',
                          style: TextStyle(
                            color: studentInk,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 7),
                        Text(
                          'Your notebooks and teacher attachments are already available here. New file attachments are temporarily unavailable.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: studentMuted, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final message = messages[i];
                    final user = message.user;
                    return Align(
                      alignment: user
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        constraints: const BoxConstraints(maxWidth: 310),
                        decoration: BoxDecoration(
                          color: user ? studentNavy : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          message.body,
                          style: TextStyle(
                            color: user ? Colors.white : studentInk,
                            height: 1.4,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (attachment != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                const Icon(
                  Icons.attach_file_rounded,
                  size: 18,
                  color: studentNavy,
                ),
                Expanded(
                  child: Text(attachment!, overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  onPressed: () => setState(() {
                    attachment = null;
                    attachmentLocalPath = null;
                  }),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Ask about your materials',
                prefixIcon: IconButton(
                  key: const Key('study-coach-attachment-control'),
                  tooltip: 'File attachments are temporarily unavailable',
                  onPressed: StudafyRuntime.policy.allowsRemoteFileUploads
                      ? _attach
                      : null,
                  icon: const Icon(Icons.attach_file_rounded),
                ),
                suffixIcon: IconButton(
                  onPressed: _send,
                  icon: const Icon(
                    Icons.arrow_upward_rounded,
                    color: studentNavy,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
