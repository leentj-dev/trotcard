import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import { songs as localSongs, type SongData, type WordEntry } from "@/data/songs";

interface DbSong {
  id: string;
  title: string;
  artist: string;
  youtube_id: string;
  theme: SongData["theme"];
  sort_order: number;
}

interface DbWord {
  id: number;
  song_id: string;
  korean: string;
  romanization: string;
  english: string;
  spanish: string;
  portuguese: string;
  indonesian: string;
  japanese: string;
  thai: string;
  french: string;
  part_of_speech: string;
  emoji: string;
  example: string;
  example_translation: string;
  sort_order: number;
  timestamp: number | null;
}

function toSongData(dbSong: DbSong, dbWords: DbWord[]): SongData {
  return {
    id: dbSong.id,
    title: dbSong.title,
    artist: dbSong.artist,
    youtubeId: dbSong.youtube_id,
    theme: dbSong.theme,
    words: dbWords
      .sort((a, b) => a.sort_order - b.sort_order)
      .map((w): WordEntry => ({
        korean: w.korean,
        romanization: w.romanization,
        english: w.english,
        spanish: w.spanish,
        portuguese: w.portuguese,
        indonesian: w.indonesian,
        japanese: w.japanese,
        thai: w.thai,
        french: w.french,
        partOfSpeech: w.part_of_speech,
        emoji: w.emoji,
        example: w.example,
        exampleTranslation: w.example_translation,
        ...(w.timestamp != null && { timestamp: w.timestamp }),
      })),
  };
}

export function useSongs() {
  const [songs, setSongs] = useState<SongData[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetchSongs() {
      try {
        const { data: dbSongs, error: songsErr } = await supabase
          .from("songs")
          .select("*")
          .order("sort_order");

        if (songsErr || !dbSongs || dbSongs.length === 0) {
          setLoading(false);
          return;
        }

        const { data: dbWords, error: wordsErr } = await supabase
          .from("words")
          .select("*");

        if (wordsErr || !dbWords) {
          setLoading(false);
          return;
        }

        const wordsBySong = dbWords.reduce<Record<string, DbWord[]>>((acc, w) => {
          if (!acc[w.song_id]) acc[w.song_id] = [];
          acc[w.song_id].push(w);
          return acc;
        }, {});

        const result = dbSongs
          .map((s) => toSongData(s, wordsBySong[s.id] || []))
          .filter((s) => s.words.some((w) => w.timestamp != null));
        setSongs(result);
      } catch {
        // Network error
      } finally {
        setLoading(false);
      }
    }

    fetchSongs();
  }, []);

  return { songs, loading };
}
