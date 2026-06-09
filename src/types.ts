export type VideoSourceFormat = "auto" | "json" | "xml";

export interface VideoSource {
  id: string;
  name: string;
  homepageURL?: string;
  apiURL: string;
  searchURL?: string;
  format: VideoSourceFormat;
  isBuiltIn: boolean;
}

export interface SourceTestResult {
  categoryCount: number;
  itemCount: number;
}

export interface VodListResponse {
  code: number;
  msg?: string;
  page?: number;
  pagecount?: number;
  total?: number;
  list: VodItem[];
  class?: VodCategory[];
}

export interface VodCategory {
  type_id: number;
  type_pid: number;
  type_name: string;
}

export interface VodItem {
  vod_id: number;
  vod_name: string;
  type_id?: number;
  type_name?: string;
  vod_pic?: string;
  vod_pic_thumb?: string;
  vod_pic_slide?: string;
  vod_pic_screenshot?: string;
  vod_remarks?: string;
  vod_area?: string;
  vod_lang?: string;
  vod_year?: string;
  vod_score?: string;
  vod_douban_score?: string;
  vod_time?: string;
  vod_class?: string;
  vod_actor?: string;
  vod_director?: string;
  vod_content?: string;
  vod_blurb?: string;
  vod_play_from?: string;
  vod_play_url?: string;
  vod_down_url?: string;
}

export interface LibraryPage {
  items: VodItem[];
  page: number;
  pageCount: number;
  total: number;
  remoteCategories?: VodCategory[];
}

export interface LibraryCacheKey {
  categoryID?: number;
  keyword: string;
  page: number;
}

export interface CachedLibraryPage {
  page: LibraryPage;
  loadedAt: string;
  isComplete: boolean;
}

export interface Episode {
  id: string;
  title: string;
  url: string;
}

export interface PlaybackSource {
  id: string;
  name: string;
  episodes: Episode[];
}

export interface FavoriteMovie {
  item: VodItem;
  addedAt: string;
  sourceID?: string;
  sourceName?: string;
}

export interface WatchProgressItem {
  item: VodItem;
  sourceID?: string;
  sourceName?: string;
  playbackSourceID?: string;
  playbackSourceName?: string;
  episodeTitle: string;
  episodeURL: string;
  positionSeconds: number;
  durationSeconds?: number;
  updatedAt: string;
}

export interface DownloadTaskInfo {
  id: string;
  title: string;
  sourceURL: string;
  progress: number;
  status: "queued" | "downloading" | "finished" | "failed";
  statusLabel: string;
  localURL?: string;
}

export type LibrarySection =
  | { kind: "home" }
  | { kind: "favorites" }
  | { kind: "continueWatching" }
  | { kind: "category"; id: number };

export type ContentRoute = "browse" | "watch";

export type ContentMode = "preview" | "onlineCategory" | "search";
