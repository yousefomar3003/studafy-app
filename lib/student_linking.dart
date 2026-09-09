import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'studafy_database.dart';

const _navy = Color(0xFF241D73);
const _cyan = Color(0xFF20C6E8);
const _ink = Color(0xFF171441);
const _muted = Color(0xFF9299B4);

class StudentIdentityCard extends StatelessWidget {
  const StudentIdentityCard({
    super.key,
    required this.name,
    required this.email,
    required this.studafyId,
  });

  final String name, email, studafyId;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [_navy, Color(0xFF4037A0)]),
      borderRadius: BorderRadius.circular(25),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white12,
              child: Text(
                'LH',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(email, style: const TextStyle(color: Colors.white60)),
                ],
              ),
            ),
          ],
        ),
        const Divider(color: Colors.white12, height: 28),
        const Text(
          'STUDAFY ID',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: .8,
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                studafyId,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: studafyId));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Studafy ID copied.')),
                  );
                }
              },
              icon: const Icon(Icons.copy_rounded, size: 17),
              label: const Text('Copy'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 13),
        Center(
          child: Container(
            width: 174,
            height: 174,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: CustomPaint(painter: _QrPainter(studafyId)),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'A parent or teacher can scan this code to send a connection request. This code is not a password.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white60, fontSize: 11, height: 1.4),
        ),
      ],
    ),
  );
}

class _QrPainter extends CustomPainter {
  const _QrPainter(this.value);
  final String value;
  @override
  void paint(Canvas canvas, Size size) {
    const cells = 21;
    final cell = size.width / cells;
    final paint = Paint()..color = _navy;
    var seed = value.codeUnits.fold<int>(
      17,
      (a, b) => (a * 31 + b) & 0x7fffffff,
    );
    bool finder(int x, int y, int ox, int oy) {
      final dx = x - ox, dy = y - oy;
      if (dx < 0 || dy < 0 || dx >= 7 || dy >= 7) return false;
      return dx == 0 ||
          dy == 0 ||
          dx == 6 ||
          dy == 6 ||
          (dx >= 2 && dx <= 4 && dy >= 2 && dy <= 4);
    }

    for (var y = 0; y < cells; y++) {
      for (var x = 0; x < cells; x++) {
        final fixed =
            finder(x, y, 0, 0) || finder(x, y, 14, 0) || finder(x, y, 0, 14);
        seed = (seed * 1103515245 + 12345) & 0x7fffffff;
        if (fixed || (seed & 3) == 0) {
          canvas.drawRect(
            Rect.fromLTWH(x * cell, y * cell, cell * .88, cell * .88),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter oldDelegate) =>
      oldDelegate.value != value;
}

Future<String?> scanStudentQr(BuildContext context) => Navigator.push<String>(
  context,
  MaterialPageRoute(builder: (_) => const StudentQrScannerPage()),
);

class StudentQrScannerPage extends StatelessWidget {
  const StudentQrScannerPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF101020),
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      title: const Text('Scan student QR'),
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 270,
              height: 270,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: _cyan, width: 3),
              ),
              child: const Center(
                child: Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Colors.white54,
                  size: 100,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Place the student’s Studafy QR inside the frame',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'The ID will be checked before any connection is created.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, 'ST-4Q2R-58D'),
              icon: const Icon(Icons.qr_code_2_rounded),
              label: const Text('Use detected student'),
              style: FilledButton.styleFrom(
                backgroundColor: _cyan,
                foregroundColor: _ink,
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class StudentLinkPage extends StatefulWidget {
  const StudentLinkPage({super.key, required this.asParent});
  final bool asParent;
  @override
  State<StudentLinkPage> createState() => _StudentLinkPageState();
}

class _StudentLinkPageState extends State<StudentLinkPage> {
  final id = TextEditingController();
  bool busy = false;

  Future<void> _connect() async {
    if (id.text.trim().isEmpty || busy) return;
    setState(() => busy = true);
    try {
      final student = await StudafyDatabase.instance.studentByStudafyId(
        id.text,
      );
      if (student == null) throw StateError('not found');
      if (widget.asParent) {
        await StudafyDatabase.instance.linkChild(student['id'] as int);
      } else {
        await StudafyDatabase.instance.requestConnection(
          'ST-2H9X-46B',
          id.text.trim(),
        );
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          icon: const Icon(
            Icons.verified_rounded,
            color: Color(0xFF168A60),
            size: 36,
          ),
          title: Text(widget.asParent ? 'Student linked' : 'Request sent'),
          content: Text(
            widget.asParent
                ? '${student['name']} is now connected to your family view.'
                : '${student['name']} will appear after the connection is accepted.',
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No student was found with that Studafy ID.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    id.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7F6FE),
    appBar: AppBar(title: const Text('Link a student')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Icon(Icons.family_restroom_rounded, color: _navy, size: 50),
        const SizedBox(height: 14),
        const Text(
          'Connect securely',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _ink,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Use the student’s Studafy ID or scan the QR shown on their profile. Always confirm the student before connecting.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, height: 1.4),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: id,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Student Studafy ID',
            hintText: 'STU-0001',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            final value = await scanStudentQr(context);
            if (value != null) setState(() => id.text = value);
          },
          icon: const Icon(Icons.qr_code_scanner_rounded),
          label: const Text('Scan QR code'),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: busy ? null : _connect,
          style: FilledButton.styleFrom(
            backgroundColor: _navy,
            minimumSize: const Size.fromHeight(52),
          ),
          child: Text(
            busy
                ? 'Checking…'
                : widget.asParent
                ? 'Link student'
                : 'Send request',
          ),
        ),
      ],
    ),
  );
}
