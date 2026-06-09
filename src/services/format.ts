import type { VodItem, WatchProgressItem } from "../types";

export function nilIfBlank(value?: string | null): string | undefined {
  const trimmed = value?.trim();
  return trimmed ? trimmed : undefined;
}

export function stripHTML(value?: string | null): string {
  return (value ?? "")
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<\/p>/gi, "\n")
    .replace(/<[^>]+>/g, "")
    .replaceAll("&nbsp;", " ")
    .replaceAll("&amp;", "&")
    .replaceAll("&quot;", "\"")
    .replaceAll("&#39;", "'")
    .trim();
}

export function scoreText(item?: VodItem): string {
  if (!item) {
    return "暂无";
  }
  return [item.vod_douban_score, item.vod_score].find((value) => {
    const normalized = nilIfBlank(value);
    return normalized && normalized !== "0.0";
  }) ?? "暂无";
}

export function summary(item?: VodItem): string {
  if (!item) {
    return "暂无简介";
  }
  return stripHTML(nilIfBlank(item.vod_content) ?? nilIfBlank(item.vod_blurb) ?? "暂无简介");
}

export function posterURL(item?: VodItem): string | undefined {
  const raw = nilIfBlank(item?.vod_pic_thumb) ?? nilIfBlank(item?.vod_pic);
  if (!raw) {
    return undefined;
  }
  try {
    return new URL(raw).toString();
  } catch {
    try {
      return encodeURI(raw);
    } catch {
      return undefined;
    }
  }
}

export function metadataText(item: VodItem, includePeople = false): string {
  const parts = [
    item.vod_year,
    item.vod_area,
    item.vod_lang,
    item.vod_class,
    includePeople ? item.vod_director && `导演：${item.vod_director}` : undefined,
    includePeople ? item.vod_actor && `主演：${item.vod_actor}` : undefined
  ]
    .map(nilIfBlank)
    .filter(Boolean);
  return parts.join("  ·  ");
}

export function formattedUpdateDate(item: VodItem): string | undefined {
  const raw = nilIfBlank(item.vod_time);
  if (!raw) {
    return undefined;
  }
  return (raw.split(" ")[0] ?? raw).replaceAll("/", "-");
}

export function formatTime(seconds: number): string {
  const total = Math.max(Math.floor(Number.isFinite(seconds) ? seconds : 0), 0);
  const hours = Math.floor(total / 3600);
  const minutes = Math.floor((total % 3600) / 60);
  const remainingSeconds = total % 60;
  if (hours > 0) {
    return `${hours}:${String(minutes).padStart(2, "0")}:${String(remainingSeconds).padStart(2, "0")}`;
  }
  return `${String(minutes).padStart(2, "0")}:${String(remainingSeconds).padStart(2, "0")}`;
}

export function progressFraction(item?: WatchProgressItem): number | undefined {
  if (!item?.durationSeconds || item.durationSeconds <= 0 || item.positionSeconds <= 0) {
    return undefined;
  }
  return Math.min(Math.max(item.positionSeconds / item.durationSeconds, 0), 1);
}

export function progressLabel(item: WatchProgressItem): string {
  if (!Number.isFinite(item.positionSeconds) || item.positionSeconds < 5) {
    return item.episodeTitle;
  }
  return `${item.episodeTitle} · ${formatTime(item.positionSeconds)}`;
}

export function normalizePosition(positionSeconds: number, durationSeconds?: number): number {
  if (!Number.isFinite(positionSeconds) || positionSeconds <= 0) {
    return 0;
  }
  if (durationSeconds && Number.isFinite(durationSeconds) && durationSeconds > 0 && durationSeconds - positionSeconds < 20) {
    return 0;
  }
  return positionSeconds;
}

export function safeFileName(value: string): string {
  return value.replace(/[/:\\]/g, "-").replace(/\s+/g, " ").trim() || "Xvideo";
}

export function extensionFromURL(url: string, fallback = "mp4"): string {
  try {
    const pathname = new URL(url).pathname;
    const ext = pathname.split(".").pop();
    return ext && ext !== pathname ? ext : fallback;
  } catch {
    return fallback;
  }
}
