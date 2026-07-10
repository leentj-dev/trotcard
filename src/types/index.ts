export interface Word {
  id: string;
  korean: string;
  romanization: string;
  english: string;
  category: WordCategory;
  emoji?: string;
  songs: SongReference[];
}

export interface Idiom {
  id: string;
  korean: string;
  romanization: string;
  english: string;
  literal?: string;
  emoji?: string;
  songs: SongReference[];
}

export interface SongReference {
  title: string;
  artist: string;
  youtubeUrl: string;
}

export type WordCategory =
  | 'love'
  | 'emotion'
  | 'nature'
  | 'time'
  | 'daily'
  | 'greeting'
  | 'body'
  | 'food';

export interface QuizQuestion {
  type: 'meaning' | 'pronunciation' | 'listening';
  question: string;
  options: string[];
  correctIndex: number;
}

export interface UserProgress {
  userId: string;
  wordId: string;
  learned: boolean;
  correctCount: number;
  totalAttempts: number;
}

export interface Favorite {
  userId: string;
  wordId: string;
  createdAt: string;
}
