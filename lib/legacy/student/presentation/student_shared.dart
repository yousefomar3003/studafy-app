import 'package:flutter/material.dart';

const studentNavy = Color(0xFF241D73);
const studentCyan = Color(0xFF20C6E8);
const studentInk = Color(0xFF171441);
const studentMuted = Color(0xFF9299B4);
const studentCanvas = Color(0xFFF7F6FE);

class StudentWorkStatus extends StatelessWidget {
  const StudentWorkStatus({
    super.key,
    required this.label,
    required this.color,
  });
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800),
    ),
  );
}

class StudentEmptyState extends StatelessWidget {
  const StudentEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title, message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 70, horizontal: 28),
      child: Column(
        children: [
          Icon(icon, color: studentNavy, size: 45),
          const SizedBox(height: 13),
          Text(
            title,
            style: const TextStyle(
              color: studentInk,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: studentMuted),
          ),
        ],
      ),
    ),
  );
}

IconData studentAttachmentIcon(String kind, String name) {
  final extension = name.toLowerCase().split('.').last;
  if (kind == 'link') return Icons.link_rounded;
  if (kind == 'image') return Icons.image_outlined;
  if (extension == 'pdf') return Icons.picture_as_pdf_outlined;
  if (['doc', 'docx'].contains(extension)) return Icons.description_outlined;
  if (['ppt', 'pptx'].contains(extension)) return Icons.slideshow_outlined;
  if (['xls', 'xlsx', 'csv'].contains(extension)) {
    return Icons.table_chart_outlined;
  }
  if (['mp3', 'm4a', 'wav'].contains(extension)) {
    return Icons.audio_file_outlined;
  }
  if (['mp4', 'mov'].contains(extension)) return Icons.video_file_outlined;
  return Icons.insert_drive_file_outlined;
}

String studentAssignmentStatus(Map<String, Object?> item) {
  if (item['score'] != null) return 'Graded';
  if (item['submitted_at'] != null) return 'Submitted';
  final due = DateTime.tryParse('${item['due_at']}');
  if (due != null && due.isBefore(DateTime.now())) return 'Late';
  return 'Due';
}

Color studentStatusColor(String status) => switch (status) {
  'Graded' || 'Submitted' => const Color(0xFF15885D),
  'Late' => const Color(0xFFFF4757),
  _ => const Color(0xFFB87500),
};

String studentFileType(String name) {
  final parts = name.split('.');
  return parts.length > 1 ? '${parts.last.toUpperCase()} document' : 'file';
}

String studentShortDate(String raw) {
  final date = DateTime.tryParse(raw);
  if (date == null) return raw;
  return '${date.day}/${date.month}';
}

String studentScore(Object? value) {
  if (value is num) {
    return value == value.roundToDouble()
        ? '${value.toInt()}'
        : value.toStringAsFixed(1);
  }
  return '—';
}
