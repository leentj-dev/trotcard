import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/song.dart';
import '../utils/themes.dart';

class WordCard extends StatelessWidget {
  final WordEntry word;
  final String lang;
  final SongTheme theme;
  final bool active;
  final VoidCallback? onSpeak;
  final VoidCallback? onTap;

  const WordCard({
    super.key,
    required this.word,
    required this.lang,
    required this.theme,
    this.active = false,
    this.onSpeak,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chips = appConfig.target.breakdown(word);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: active ? 0.14 : 0.06),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: active ? theme.accent : Colors.white24,
            width: active ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (word.emoji.isNotEmpty)
                  Text(word.emoji, style: const TextStyle(fontSize: 28))
                else
                  const SizedBox(width: 28),
                if (word.partOfSpeech.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      word.partOfSpeech,
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    word.korean,
                    style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onSpeak,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.volume_up_rounded, color: theme.accent),
                  tooltip: 'Listen',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              alignment: WrapAlignment.center,
              children: [
                for (final chip in chips)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      chip,
                      style: TextStyle(fontSize: 13, color: theme.accent),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              word.romanization,
              style: TextStyle(
                fontSize: 16,
                fontStyle: FontStyle.italic,
                color: theme.accent,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              word.translation(lang),
              style: const TextStyle(fontSize: 20, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            if (word.example.isNotEmpty) ...[
              const Divider(color: Colors.white12),
              Text(
                word.example,
                style: const TextStyle(fontSize: 15, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                word.exampleTranslation,
                style: const TextStyle(fontSize: 13, color: Colors.white54),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
