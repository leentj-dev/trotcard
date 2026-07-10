"use client";

import { useState, useCallback, useRef, useEffect } from "react";
import { type SongData } from "@/data/songs";
import { useSongs } from "@/hooks/useSongs";

const INITIALS = ["ㄱ","ㄲ","ㄴ","ㄷ","ㄸ","ㄹ","ㅁ","ㅂ","ㅃ","ㅅ","ㅆ","ㅇ","ㅈ","ㅉ","ㅊ","ㅋ","ㅌ","ㅍ","ㅎ"];
const MEDIALS = ["ㅏ","ㅐ","ㅑ","ㅒ","ㅓ","ㅔ","ㅕ","ㅖ","ㅗ","ㅘ","ㅙ","ㅚ","ㅛ","ㅜ","ㅝ","ㅞ","ㅟ","ㅠ","ㅡ","ㅢ","ㅣ"];
const FINALS = ["","ㄱ","ㄲ","ㄳ","ㄴ","ㄵ","ㄶ","ㄷ","ㄹ","ㄺ","ㄻ","ㄼ","ㄽ","ㄾ","ㄿ","ㅀ","ㅁ","ㅂ","ㅄ","ㅅ","ㅆ","ㅇ","ㅈ","ㅊ","ㅋ","ㅌ","ㅍ","ㅎ"];

function decomposeHangul(text: string) {
  return text.split("").map((char) => {
    const code = char.charCodeAt(0);
    if (code < 0xAC00 || code > 0xD7A3) return { char, parts: [char] };
    const offset = code - 0xAC00;
    const initial = INITIALS[Math.floor(offset / (21 * 28))];
    const medial = MEDIALS[Math.floor((offset % (21 * 28)) / 28)];
    const final = FINALS[offset % 28];
    return { char, parts: final ? [initial, medial, final] : [initial, medial] };
  });
}

type ViewMode = "feed" | "detail";

export default function Home() {
  const { songs, loading } = useSongs();
  const [view, setView] = useState<ViewMode>("feed");
  const [dark, setDark] = useState(false);
  const [selectedSong, setSelectedSong] = useState<SongData | null>(null);
  const [selectedIndex, setSelectedIndex] = useState<number | null>(null);
  const [isSpeaking, setIsSpeaking] = useState(false);
  type Lang = "english" | "spanish" | "portuguese" | "indonesian" | "japanese" | "thai" | "french";
  const [lang, setLang] = useState<Lang>("english");
  const [searchQuery, setSearchQuery] = useState("");
  const [showSearch, setShowSearch] = useState(false);
  const [miniPlayer, setMiniPlayer] = useState(false);
  const [practiceMode, setPracticeMode] = useState(false);
  const feedScrollPos = useRef(0);
  const searchInputRef = useRef<HTMLInputElement>(null);
  const playerContainerRef = useRef<HTMLDivElement>(null);
  const playerRef = useRef<any>(null);
  const carouselRef = useRef<HTMLDivElement>(null);
  const scrollTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const isUserScrolling = useRef(false);
  const wordRefs = useRef<(HTMLButtonElement | null)[]>([]);
  const lastIndexRef = useRef<number>(0);
  const videoSectionRef = useRef<HTMLDivElement>(null);
  const swipeStartY = useRef<number | null>(null);
  const swipeStartX = useRef<number | null>(null);
  const swipeDirection = useRef<"none" | "horizontal" | "vertical">("none");
  const shouldScrollCarousel = useRef(false);
  const swipeCardRef = useRef<HTMLDivElement>(null);

  // Restore saved preferences after mount
  useEffect(() => {
    const savedDark = localStorage.getItem("kpop-dark");
    if (savedDark !== null) setDark(savedDark === "true");
    else if (window.matchMedia("(prefers-color-scheme: dark)").matches) setDark(true);
    const savedLang = localStorage.getItem("kpop-lang") as Lang;
    if (savedLang) setLang(savedLang);
  }, []);

  const normalizeQuery = (q: string) => q.toLowerCase().replace(/\s/g, "");
  const filteredSongs = searchQuery
    ? songs.filter((s) => normalizeQuery(s.title).includes(normalizeQuery(searchQuery)) || normalizeQuery(s.artist).includes(normalizeQuery(searchQuery)))
    : songs;

  useEffect(() => {
    if (showSearch && searchInputRef.current) searchInputRef.current.focus();
  }, [showSearch]);

  const currentSong = selectedSong ?? songs[0];
  const t = currentSong?.theme;

  // Load YouTube IFrame API
  useEffect(() => {
    if (typeof window === "undefined") return;
    if (!(window as any).YT) {
      const tag = document.createElement("script");
      tag.src = "https://www.youtube.com/iframe_api";
      document.head.appendChild(tag);
    }
  }, []);

  // Create player when entering detail view
  useEffect(() => {
    if (view !== "detail" || !currentSong?.youtubeId) return;
    const createPlayer = () => {
      if (!playerContainerRef.current) return;
      if (playerRef.current) playerRef.current.destroy();
      playerRef.current = new (window as any).YT.Player(playerContainerRef.current, {
        videoId: currentSong.youtubeId,
        playerVars: { enablejsapi: 1, rel: 0, fs: 0, modestbranding: 1, disablekb: 0, iv_load_policy: 3, autoplay: 1 },
      });
    };
    // Wait for both YT API and DOM ref
    const tryCreate = () => {
      if ((window as any).YT?.Player && playerContainerRef.current) createPlayer();
      else setTimeout(tryCreate, 100);
    };
    setTimeout(tryCreate, 50);
    return () => { if (playerRef.current) { playerRef.current.destroy(); playerRef.current = null; } };
  }, [view, currentSong?.youtubeId]);

  // Mini player: detect scroll past video in detail view
  useEffect(() => {
    if (view !== "detail") { setMiniPlayer(false); return; }
    const handleScroll = () => {
      if (!videoSectionRef.current) return;
      const rect = videoSectionRef.current.getBoundingClientRect();
      setMiniPlayer(rect.bottom < 0);
    };
    window.addEventListener("scroll", handleScroll, { passive: true });
    return () => window.removeEventListener("scroll", handleScroll);
  }, [view]);

  // Back button support
  useEffect(() => {
    if (view === "detail") {
      window.history.pushState({ view: "detail" }, "");
      const handlePop = () => {
        setView("feed");
        setMiniPlayer(false);
        setSelectedIndex(null);
      };
      window.addEventListener("popstate", handlePop);
      return () => window.removeEventListener("popstate", handlePop);
    }
  }, [view]);

  const LANG_CODES: Record<string, string> = {
    korean: "ko-KR", english: "en-US", spanish: "es-ES", portuguese: "pt-BR",
    indonesian: "id-ID", japanese: "ja-JP", thai: "th-TH", french: "fr-FR",
  };

  const handleSpeak = useCallback((text: string, isWord = false, speechLang = "ko-KR") => {
    if (isWord) setIsSpeaking(true);
    if (typeof window !== "undefined" && window.speechSynthesis) {
      window.speechSynthesis.cancel();
      const u = new SpeechSynthesisUtterance(text);
      u.lang = speechLang; u.rate = 0.8;
      u.onend = () => setIsSpeaking(false);
      u.onerror = () => setIsSpeaking(false);
      window.speechSynthesis.speak(u);
    }
  }, []);

  const getTimestamp = useCallback((index: number) => {
    const word = currentSong?.words[index];
    if (word?.timestamp != null) return word.timestamp;
    const duration = playerRef.current?.getDuration?.() || 210;
    return Math.floor(index * (duration / (currentSong?.words.length || 20)));
  }, [currentSong?.words]);

  const formatTime = (seconds: number) => {
    const m = Math.floor(seconds / 60);
    const s = seconds % 60;
    return `${m}:${s.toString().padStart(2, "0")}`;
  };

  const seekToWord = useCallback((index: number) => {
    const time = getTimestamp(index);
    if (playerRef.current?.seekTo) {
      playerRef.current.seekTo(time, true);
      if (playerRef.current.getPlayerState?.() !== 1) playerRef.current.playVideo?.();
    }
  }, [getTimestamp]);

  const selectWord = useCallback((index: number) => {
    lastIndexRef.current = index;
    shouldScrollCarousel.current = true;
    setSelectedIndex(index);
    seekToWord(index);
  }, [seekToWord]);

  const goNext = useCallback(() => {
    if (selectedIndex !== null && selectedIndex < currentSong.words.length - 1) selectWord(selectedIndex + 1);
  }, [selectedIndex, currentSong?.words?.length, selectWord]);

  const goPrev = useCallback(() => {
    if (selectedIndex !== null && selectedIndex > 0) selectWord(selectedIndex - 1);
  }, [selectedIndex, selectWord]);

  useEffect(() => {
    const handleKey = (e: KeyboardEvent) => {
      if (selectedIndex === null) return;
      if (e.key === "ArrowRight") goNext();
      if (e.key === "ArrowLeft") goPrev();
      if (e.key === "Escape") setSelectedIndex(null);
    };
    window.addEventListener("keydown", handleKey);
    return () => window.removeEventListener("keydown", handleKey);
  }, [selectedIndex, goNext, goPrev]);

  const setCarouselRef = useCallback((el: HTMLDivElement | null) => {
    carouselRef.current = el;
    if (el && lastIndexRef.current > 0) {
      const card = el.children[lastIndexRef.current] as HTMLElement;
      if (card) el.scrollTo({ left: card.offsetLeft - (el.offsetWidth - card.offsetWidth) / 2, behavior: "instant" });
    }
  }, []);

  useEffect(() => {
    if (selectedIndex !== null) document.body.style.overflow = "hidden";
    else document.body.style.overflow = "";
    return () => { document.body.style.overflow = ""; };
  }, [selectedIndex]);

  useEffect(() => {
    if (selectedIndex === null) return;
    if (carouselRef.current && shouldScrollCarousel.current) {
      shouldScrollCarousel.current = false;
      requestAnimationFrame(() => {
        if (!carouselRef.current) return;
        const card = carouselRef.current.children[selectedIndex] as HTMLElement;
        if (card) carouselRef.current.scrollTo({ left: card.offsetLeft - (carouselRef.current.offsetWidth - card.offsetWidth) / 2, behavior: "smooth" });
      });
    }
    wordRefs.current[selectedIndex]?.scrollIntoView({ behavior: "smooth", block: "nearest" });
  }, [selectedIndex]);

  const closePopup = useCallback(() => {
    setSelectedIndex(null);
    if (practiceMode) { setPracticeMode(false); playerRef.current?.playVideo?.(); }
    if (swipeCardRef.current) { swipeCardRef.current.style.transform = ""; swipeCardRef.current.style.opacity = ""; }
  }, [practiceMode]);

  const handleSwipeStart = (e: React.TouchEvent) => {
    swipeStartY.current = e.touches[0].clientY;
    swipeStartX.current = e.touches[0].clientX;
    swipeDirection.current = "none";
  };

  const handleSwipeMove = (e: React.TouchEvent) => {
    if (swipeStartY.current === null || swipeStartX.current === null || !swipeCardRef.current) return;
    const dy = e.touches[0].clientY - swipeStartY.current;
    const dx = e.touches[0].clientX - swipeStartX.current;

    // Determine direction on first significant move
    if (swipeDirection.current === "none" && (Math.abs(dy) > 8 || Math.abs(dx) > 8)) {
      swipeDirection.current = Math.abs(dx) > Math.abs(dy) ? "horizontal" : "vertical";
    }

    // Only apply vertical swipe effect
    if (swipeDirection.current === "vertical") {
      const abs = Math.abs(dy);
      swipeCardRef.current.style.transform = `translateY(${dy}px)`;
      swipeCardRef.current.style.opacity = `${Math.max(0, 1 - abs / 200)}`;
    }
  };

  const handleSwipeEnd = (e: React.TouchEvent) => {
    if (swipeStartY.current === null || !swipeCardRef.current) return;
    if (swipeDirection.current === "vertical") {
      const dy = e.changedTouches[0].clientY - swipeStartY.current;
      if (Math.abs(dy) > 80) {
        closePopup();
      } else {
        swipeCardRef.current.style.transform = "";
        swipeCardRef.current.style.opacity = "";
      }
    }
    swipeStartY.current = null;
    swipeStartX.current = null;
    swipeDirection.current = "none";
  };

  const openSong = (song: SongData) => {
    feedScrollPos.current = window.scrollY;
    setSelectedSong(song);
    setSelectedIndex(null);
    setMiniPlayer(false);
    setView("detail");
    setTimeout(() => window.scrollTo(0, 0), 0);
  };

  const goBack = () => {
    setView("feed");
    setMiniPlayer(false);
    setSelectedIndex(null);
    if (playerRef.current?.pauseVideo) playerRef.current.pauseVideo();
    setTimeout(() => window.scrollTo(0, feedScrollPos.current), 0);
  };

  if (!currentSong || !t) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-white">
        <p className="animate-pulse text-lg text-gray-400">Loading...</p>
      </div>
    );
  }

  // ═══════════════════════ FEED VIEW ═══════════════════════
  if (view === "feed") {
    return (
      <div className={`min-h-screen ${dark ? "bg-gray-950" : "bg-gray-50"}`}>
        {/* Header */}
        <div className={`sticky top-0 z-40 border-b ${dark ? "bg-gray-900 border-gray-800" : "bg-white border-gray-200"}`}>
          <header className="flex items-center justify-between px-4 py-3">
            <h1 className="text-xl font-bold">
              <span className="bg-gradient-to-r from-amber-500 via-pink-500 to-purple-600 bg-clip-text text-transparent">
                K-pop Hangul
              </span>
            </h1>
            <div className="flex items-center gap-2">
              <button onClick={() => { const next = !dark; setDark(next); localStorage.setItem("kpop-dark", String(next)); }} className={`rounded-full p-2 ${dark ? "text-yellow-400 hover:bg-gray-700" : "text-gray-600 hover:bg-gray-100"}`}>
                {dark ? <svg className="h-5 w-5" fill="currentColor" viewBox="0 0 24 24"><path d="M12 3a9 9 0 109 9c0-.46-.04-.92-.1-1.36a5.389 5.389 0 01-4.4 2.26 5.403 5.403 0 01-3.14-9.8c-.44-.06-.9-.1-1.36-.1z"/></svg>
                  : <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z" /></svg>}
              </button>
              <button onClick={() => { setShowSearch(!showSearch); if (showSearch) setSearchQuery(""); }} className={`rounded-full p-2 ${dark ? "text-gray-300 hover:bg-gray-700" : "text-gray-600 hover:bg-gray-100"}`}>
                <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" /></svg>
              </button>
              <select value={lang} onChange={(e) => { const v = e.target.value as Lang; setLang(v); localStorage.setItem("kpop-lang", v); }} className={`rounded-lg border px-2 py-1 text-xs outline-none ${dark ? "border-gray-600 bg-gray-800 text-gray-300" : "border-gray-200 bg-white text-gray-700"}`}>
                <option value="english">🇺🇸 EN</option>
                <option value="spanish">🇪🇸 ES</option>
                <option value="portuguese">🇧🇷 PT</option>
                <option value="indonesian">🇮🇩 ID</option>
                <option value="japanese">🇯🇵 JA</option>
                <option value="thai">🇹🇭 TH</option>
                <option value="french">🇫🇷 FR</option>
              </select>
            </div>
          </header>
          {showSearch && (
            <div className="px-4 pb-3">
              <div className="relative">
                <svg className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" /></svg>
                <input ref={searchInputRef} type="text" value={searchQuery} onChange={(e) => setSearchQuery(e.target.value)} placeholder="Search songs, artists..." className={`w-full rounded-xl py-2 pl-9 pr-8 text-sm placeholder-gray-400 outline-none ${dark ? "bg-gray-800 text-white" : "bg-gray-100 text-gray-900"}`} />
                {searchQuery && <button onClick={() => setSearchQuery("")} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400"><svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" /></svg></button>}
              </div>
            </div>
          )}
        </div>

        {/* Song Feed */}
        <div className="mx-auto max-w-2xl">
          {filteredSongs.map((song) => (
            <div key={song.id} className={`mb-2 cursor-pointer ${dark ? "bg-gray-900" : "bg-white"}`} onClick={() => openSong(song)}>
              <img
                src={`https://img.youtube.com/vi/${song.youtubeId}/hqdefault.jpg`}
                alt={song.title}
                className="w-full aspect-video object-cover"
              />
              <div className="px-4 py-3 flex items-start gap-3">
                <img
                  src={`https://img.youtube.com/vi/${song.youtubeId}/default.jpg`}
                  className="h-9 w-9 rounded-full object-cover shrink-0 mt-0.5"
                  alt=""
                />
                <div className="min-w-0">
                  <h3 className={`text-sm font-semibold leading-snug line-clamp-2 ${dark ? "text-white" : "text-gray-900"}`}>{song.title}</h3>
                  <p className="text-xs text-gray-500 mt-0.5">{song.artist} · {song.words.length} words</p>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    );
  }

  // ═══════════════════════ DETAIL VIEW ═══════════════════════
  return (
    <div className={`min-h-screen ${dark ? "bg-gray-950" : "bg-white"}`}>
      {/* Video Section */}
      <div ref={videoSectionRef} className="sticky top-0 z-30 bg-black">
        {/* Back button */}
        <button onClick={goBack} className="absolute left-2 top-2 z-10 rounded-full bg-black/40 p-2 text-white">
          <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" /></svg>
        </button>
        <div className="relative pt-[56.25%]">
          <div ref={playerContainerRef} className="absolute inset-0 h-full w-full" />
        </div>
      </div>

      {/* Song Info */}
      <div className={`px-4 py-3 border-b ${dark ? "border-gray-800" : "border-gray-100"}`}>
        <h2 className={`text-base font-bold ${dark ? "text-white" : "text-gray-900"}`}>{currentSong.title}</h2>
        <p className="text-xs text-gray-500 mt-0.5">{currentSong.artist}</p>
      </div>

      {/* Words Grid */}
      <div className="px-4 py-3">
        <p className="text-xs font-medium text-gray-400 mb-2">WORDS · {currentSong.words.length}</p>
        <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">
          {currentSong.words.map((word, i) => (
            <button
              key={`${word.korean}-${i}`}
              ref={(el) => { wordRefs.current[i] = el; }}
              onClick={() => selectWord(i)}
              className={`flex items-center gap-3 rounded-xl border px-3 py-3 text-left transition-all ${
                selectedIndex === i
                  ? dark ? "border-pink-500 bg-pink-950 shadow-sm" : "border-pink-300 bg-pink-50 shadow-sm"
                  : dark ? "border-gray-800 bg-gray-900 hover:bg-gray-800" : "border-gray-100 bg-white hover:bg-gray-50"
              }`}
            >
              <span className="text-2xl shrink-0">{word.emoji}</span>
              <div className="min-w-0 flex-1">
                <span className={`block text-base font-bold leading-tight ${dark ? "text-white" : "text-gray-900"}`}>{word.korean}</span>
                <span className="block text-[11px] text-gray-400 truncate">{word[lang]}</span>
              </div>
              <span className="shrink-0 text-[10px] text-gray-300">{formatTime(getTimestamp(i))}</span>
            </button>
          ))}
        </div>
      </div>

      {/* Mini Player (PiP style) */}
      {miniPlayer && (
        <div className={`fixed bottom-0 left-0 right-0 z-50 border-t shadow-lg ${dark ? "bg-gray-900 border-gray-800" : "bg-white border-gray-200"}`}>
          <div className="flex items-center gap-3 px-3 py-2">
            <img
              src={`https://img.youtube.com/vi/${currentSong.youtubeId}/default.jpg`}
              className="h-12 w-20 rounded object-cover shrink-0"
              alt=""
            />
            <div className="min-w-0 flex-1">
              <p className={`text-sm font-semibold truncate ${dark ? "text-white" : "text-gray-900"}`}>{currentSong.title}</p>
              <p className="text-xs text-gray-500 truncate">{currentSong.artist}</p>
            </div>
            <button
              onClick={() => { if (playerRef.current?.getPlayerState?.() === 1) playerRef.current.pauseVideo(); else playerRef.current?.playVideo?.(); }}
              className="rounded-full p-2 text-gray-700 hover:bg-gray-100"
            >
              <svg className="h-6 w-6" fill="currentColor" viewBox="0 0 24 24"><path d="M8 5v14l11-7z"/></svg>
            </button>
            <button onClick={() => { window.scrollTo({ top: 0, behavior: "smooth" }); }} className="rounded-full p-2 text-gray-400 hover:bg-gray-100">
              <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 15l7-7 7 7" /></svg>
            </button>
            <button onClick={goBack} className="rounded-full p-2 text-gray-400 hover:bg-gray-100">
              <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" /></svg>
            </button>
          </div>
        </div>
      )}

      {/* Word Card Popup */}
      {selectedIndex !== null && (
        <div className="fixed inset-0 z-50 flex flex-col justify-end">
          <div className="absolute inset-0 bg-black/40" onClick={closePopup} />
          <button onClick={closePopup} className="absolute right-3 top-3 z-10 rounded-full bg-white/20 p-2 text-white">
            <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" /></svg>
          </button>
          <div
            ref={(el) => { setCarouselRef(el); swipeCardRef.current = el; }}
            className="relative flex snap-x overflow-x-auto pb-6 pt-4 scrollbar-hide"
            style={{ WebkitOverflowScrolling: "touch" }}
            onTouchStart={(e) => { handleSwipeStart(e); }}
            onTouchMove={(e) => { if (swipeDirection.current !== "horizontal") handleSwipeMove(e); }}
            onTouchEnd={(e) => { handleSwipeEnd(e); }}
            onScroll={() => {
              if (scrollTimerRef.current) clearTimeout(scrollTimerRef.current);
              scrollTimerRef.current = setTimeout(() => {
                const el = carouselRef.current;
                if (!el) return;
                const cardWidth = el.firstElementChild ? (el.firstElementChild as HTMLElement).offsetWidth : 280;
                const newIndex = Math.round(el.scrollLeft / cardWidth);
                if (newIndex >= 0 && newIndex < currentSong.words.length && newIndex !== selectedIndex) {
                  lastIndexRef.current = newIndex;
                  setSelectedIndex(newIndex);
                }
              }, 300);
            }}
          >
            {currentSong.words.map((word, i) => (
              <div key={`card-${i}`} className="w-[80vw] max-w-[320px] shrink-0 snap-center px-2 first:ml-[10vw] last:mr-[10vw]">
                <div className={`rounded-2xl p-5 shadow-lg transition-all ${
                  i === selectedIndex
                    ? dark ? "bg-gray-900 opacity-100" : "bg-white opacity-100"
                    : dark ? "bg-gray-900/90 opacity-60 scale-95" : "bg-white/90 opacity-60 scale-95"
                }`}>
                  <div className="flex items-center justify-between">
                    <span className="text-3xl">{word.emoji}</span>
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        const next = !practiceMode;
                        setPracticeMode(next);
                        if (next) playerRef.current?.pauseVideo?.();
                        else playerRef.current?.playVideo?.();
                      }}
                      className={`flex items-center gap-1.5 rounded-full px-3 py-1 text-sm font-semibold transition-colors ${
                        practiceMode ? "bg-pink-500 text-white" : "practice-glow " + (dark ? "bg-gray-800 text-gray-400" : "bg-gray-100 text-gray-500")
                      }`}
                    >
                      Practice {practiceMode ? "ON" : "OFF"}
                    </button>
                  </div>
                  <div
                    className={`mt-3 inline-flex flex-col rounded-xl px-4 py-2 cursor-pointer transition-all ${
                      isSpeaking && i === selectedIndex
                        ? dark ? "bg-gradient-to-r from-amber-950 via-pink-950 to-purple-950 ring-2 ring-pink-500 animate-pulse" : "bg-gradient-to-r from-amber-50 via-pink-50 to-purple-50 ring-2 ring-pink-300 animate-pulse"
                        : dark ? "bg-gray-800 hover:bg-gray-700 active:bg-pink-950" : "bg-gray-50 hover:bg-gray-100 active:bg-pink-50"
                    }`}
                    onClick={(e) => { e.stopPropagation(); handleSpeak(word.korean, true); if (!practiceMode) seekToWord(i); }}
                  >
                    <span className={`text-3xl font-bold ${dark ? "text-white" : "text-gray-900"}`}>{word.korean}</span>
                    <span className="text-sm text-pink-500">[ {word.romanization} ]</span>
                  </div>
                  <div className="mt-2 grid grid-cols-6 gap-1">
                    {decomposeHangul(word.korean).flatMap((s, si) =>
                      s.parts.map((p, pi) => (
                        <button key={`${si}-${pi}`} onClick={(e) => { e.stopPropagation(); handleSpeak(p); }} className={`rounded-lg border px-2.5 py-1.5 text-base font-bold transition-colors ${
                          dark ? "border-gray-700 bg-gray-800 hover:bg-gray-700 active:bg-pink-950" : "border-gray-100 bg-gray-50 hover:bg-gray-100 active:bg-pink-50"
                        } ${pi === 0 ? "text-purple-400" : pi === 1 ? "text-green-400" : "text-orange-400"}`}>{p}</button>
                      ))
                    )}
                  </div>
                  <div className={`mt-3 inline-block rounded-xl px-4 py-2 cursor-pointer transition-colors ${
                    dark ? "bg-gray-800 hover:bg-gray-700 active:bg-pink-950" : "bg-gray-50 hover:bg-gray-100 active:bg-pink-50"
                  }`} onClick={(e) => { e.stopPropagation(); handleSpeak(word[lang], false, LANG_CODES[lang]); }}>
                    <p className={`text-lg ${dark ? "text-gray-200" : "text-gray-700"}`}>{word[lang]}</p>
                  </div>
                  <div className="mt-2 flex items-center justify-between text-xs text-gray-400">
                    <button onClick={(e) => { e.stopPropagation(); seekToWord(i); }} className={`flex items-center gap-1 rounded-full px-2 py-0.5 text-pink-400 transition-colors ${dark ? "bg-gray-800 hover:bg-pink-950" : "bg-gray-50 hover:bg-pink-50"}`}>
                      <svg className="h-3 w-3" fill="currentColor" viewBox="0 0 24 24"><path d="M8 5v14l11-7z"/></svg>
                      {formatTime(getTimestamp(i))}
                    </button>
                    <span>{i + 1} / {currentSong.words.length}</span>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
