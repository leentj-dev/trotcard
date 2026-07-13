import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// 신청곡 입력 바텀시트를 띄운다. 서버 없이 Firestore `requests`에 바로 저장.
Future<void> showSongRequestSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true, // 키보드가 떠도 시트가 올라오게
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _SongRequestSheet(),
  );
}

class _SongRequestSheet extends StatefulWidget {
  const _SongRequestSheet();

  @override
  State<_SongRequestSheet> createState() => _SongRequestSheetState();
}

class _SongRequestSheetState extends State<_SongRequestSheet> {
  final _title = TextEditingController();
  final _artist = TextEditingController();
  final _note = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _artist.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('듣고 싶은 곡 제목을 적어주세요')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final artist = _artist.text.trim();
      final note = _note.text.trim();
      await FirebaseFirestore.instance.collection('requests').add({
        'title': title,
        if (artist.isNotEmpty) 'artist': artist,
        if (note.isNotEmpty) 'note': note,
        'platform': Platform.isAndroid
            ? 'android'
            : (Platform.isIOS ? 'ios' : 'other'),
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('신청곡을 보냈어요. 고맙습니다! 🎵')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('전송에 실패했어요. 잠시 후 다시 시도해 주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // 키보드 높이만큼 아래 여백 → 입력창이 가리지 않게.
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('신청곡 보내기',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('듣고 싶은 트로트를 알려주세요',
              style: TextStyle(
                  fontSize: 15, color: cs.onSurface.withValues(alpha: 0.6))),
          const SizedBox(height: 18),
          _field(_title, '곡 제목 *', '예) 사랑은 늘 도망가', 100, cs,
              autofocus: true),
          const SizedBox(height: 12),
          _field(_artist, '가수 (선택)', '예) 임영웅', 60, cs),
          const SizedBox(height: 12),
          _field(_note, '한마디 (선택)', '어머니가 좋아하세요', 300, cs, lines: 2),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: _sending ? null : _send,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00704A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              icon: _sending
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 22),
              label: const Text('보내기',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label, String hint, int max,
      ColorScheme cs,
      {int lines = 1, bool autofocus = false}) {
    return TextField(
      controller: c,
      autofocus: autofocus,
      maxLength: max,
      maxLines: lines,
      textInputAction:
          lines > 1 ? TextInputAction.newline : TextInputAction.next,
      style: const TextStyle(fontSize: 17),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        filled: true,
        fillColor: cs.onSurface.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
