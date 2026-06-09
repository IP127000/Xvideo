import type {
  CachedLibraryPage,
  FavoriteMovie,
  LibraryCacheKey,
  VideoSource,
  WatchProgressItem
} from "../types";

const SOURCE_KEY = "xvideo.videoSources.v1";
const FAVORITES_KEY = "xvideo.favorites.v1";
const WATCH_PROGRESS_KEY = "xvideo.watchProgress.v1";
const CACHE_PREFIX = "xvideo.libraryCache.v1.";

interface SourceFile {
  sources: VideoSource[];
  activeSourceID?: string;
}

interface CacheFile {
  categories: unknown[];
  records: Array<{ key: LibraryCacheKey; page: CachedLibraryPage }>;
}

export function loadSources(): SourceFile {
  const parsed = readJSON<SourceFile>(SOURCE_KEY);
  if (!parsed) {
    return { sources: [] };
  }

  const sources = parsed.sources.filter((source) => !source.isBuiltIn);
  const activeSourceID = parsed.activeSourceID && sources.some((source) => source.id === parsed.activeSourceID)
    ? parsed.activeSourceID
    : sources[0]?.id;
  return { sources, activeSourceID };
}

export function saveSources(sources: VideoSource[], activeSourceID?: string) {
  const userSources = sources
    .filter((source) => !source.isBuiltIn)
    .slice()
    .sort((lhs, rhs) => lhs.name.localeCompare(rhs.name, "zh-Hans-CN"));
  writeJSON<SourceFile>(SOURCE_KEY, {
    sources: userSources,
    activeSourceID: activeSourceID && userSources.some((source) => source.id === activeSourceID) ? activeSourceID : undefined
  });
}

export function loadFavorites(): FavoriteMovie[] {
  return readJSON<FavoriteMovie[]>(FAVORITES_KEY) ?? [];
}

export function saveFavorites(items: FavoriteMovie[]) {
  writeJSON(FAVORITES_KEY, items);
}

export function loadWatchProgress(): WatchProgressItem[] {
  return readJSON<WatchProgressItem[]>(WATCH_PROGRESS_KEY) ?? [];
}

export function saveWatchProgress(items: WatchProgressItem[]) {
  writeJSON(WATCH_PROGRESS_KEY, items.slice(0, 80));
}

export function loadLibraryCache(sourceID?: string): CacheFile {
  if (!sourceID) {
    return { categories: [], records: [] };
  }
  return readJSON<CacheFile>(`${CACHE_PREFIX}${sourceID}`) ?? { categories: [], records: [] };
}

export function saveLibraryCache(sourceID: string, file: CacheFile) {
  writeJSON(`${CACHE_PREFIX}${sourceID}`, file);
}

export function cacheKeyString(key: LibraryCacheKey): string {
  return `${key.categoryID ?? "home"}::${key.keyword.trim()}::${key.page}`;
}

function readJSON<T>(key: string): T | undefined {
  try {
    const raw = window.localStorage.getItem(key);
    return raw ? JSON.parse(raw) as T : undefined;
  } catch {
    return undefined;
  }
}

function writeJSON<T>(key: string, value: T) {
  window.localStorage.setItem(key, JSON.stringify(value));
}
