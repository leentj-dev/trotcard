-- Songs table
CREATE TABLE songs (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  artist TEXT NOT NULL,
  youtube_id TEXT NOT NULL,
  theme JSONB NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Words table
CREATE TABLE words (
  id SERIAL PRIMARY KEY,
  song_id TEXT NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
  korean TEXT NOT NULL,
  romanization TEXT NOT NULL,
  english TEXT NOT NULL,
  spanish TEXT NOT NULL DEFAULT '',
  portuguese TEXT NOT NULL DEFAULT '',
  indonesian TEXT NOT NULL DEFAULT '',
  japanese TEXT NOT NULL DEFAULT '',
  thai TEXT NOT NULL DEFAULT '',
  french TEXT NOT NULL DEFAULT '',
  part_of_speech TEXT NOT NULL DEFAULT '',
  emoji TEXT NOT NULL DEFAULT '',
  example TEXT NOT NULL DEFAULT '',
  example_translation TEXT NOT NULL DEFAULT '',
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for fast lookup by song
CREATE INDEX idx_words_song_id ON words(song_id);

-- Enable Row Level Security
ALTER TABLE songs ENABLE ROW LEVEL SECURITY;
ALTER TABLE words ENABLE ROW LEVEL SECURITY;

-- Public read access (no auth needed to read)
CREATE POLICY "Public read songs" ON songs FOR SELECT USING (true);
CREATE POLICY "Public read words" ON words FOR SELECT USING (true);
