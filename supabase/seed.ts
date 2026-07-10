/**
 * Seed script: pushes songs.ts data into Supabase.
 *
 * Usage:
 *   NEXT_PUBLIC_SUPABASE_URL=... NEXT_PUBLIC_SUPABASE_ANON_KEY=... npx tsx supabase/seed.ts
 *
 * Or with .env.local loaded:
 *   npx dotenv -e .env.local -- npx tsx supabase/seed.ts
 */

import { createClient } from "@supabase/supabase-js";
import { songs } from "../src/data/songs";

const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

if (!url || !key) {
  console.error("Missing NEXT_PUBLIC_SUPABASE_URL or NEXT_PUBLIC_SUPABASE_ANON_KEY");
  process.exit(1);
}

const supabase = createClient(url, key, { db: { schema: "kh" } });

async function seed() {
  console.log(`Seeding ${songs.length} songs...`);

  for (let si = 0; si < songs.length; si++) {
    const song = songs[si];

    // Upsert song
    const { error: songErr } = await supabase.from("songs").upsert({
      id: song.id,
      title: song.title,
      artist: song.artist,
      youtube_id: song.youtubeId,
      theme: song.theme,
      sort_order: si,
    });

    if (songErr) {
      console.error(`Error inserting song ${song.id}:`, songErr);
      continue;
    }

    console.log(`  ✓ ${song.artist} - ${song.title} (${song.words.length} words)`);

    // Delete existing words for this song (to avoid duplicates on re-seed)
    await supabase.from("words").delete().eq("song_id", song.id);

    // Insert words in batches
    const wordRows = song.words.map((w, wi) => ({
      song_id: song.id,
      korean: w.korean,
      romanization: w.romanization,
      english: w.english,
      spanish: w.spanish,
      portuguese: w.portuguese,
      indonesian: w.indonesian,
      japanese: w.japanese,
      thai: w.thai,
      french: w.french,
      part_of_speech: w.partOfSpeech,
      emoji: w.emoji,
      example: w.example,
      example_translation: w.exampleTranslation,
      sort_order: wi,
    }));

    const { error: wordsErr } = await supabase.from("words").insert(wordRows);
    if (wordsErr) {
      console.error(`Error inserting words for ${song.id}:`, wordsErr);
    }
  }

  console.log("\nDone!");
}

seed();
