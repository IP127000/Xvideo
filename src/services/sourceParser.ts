import type { Episode, PlaybackSource, VodItem } from "../types";
import { nilIfBlank } from "./format";

export function parsePlaybackSources(item?: VodItem): PlaybackSource[] {
  if (!item) {
    return [];
  }

  const sourceNames = splitSourceNames(item.vod_play_from);
  const groups = splitGroups(item.vod_play_url);

  return groups.flatMap((group, index) => {
    const episodes = parseEpisodes(group);
    if (episodes.length === 0) {
      return [];
    }
    const name = sourceNames[index] ?? `播放源 ${index + 1}`;
    return [{ id: `${index}-${name}`, name, episodes }];
  });
}

export function parseDownloads(item?: VodItem): Episode[] {
  return parseEpisodes(item?.vod_down_url ?? "");
}

export function episodeCount(item?: VodItem): number {
  return Math.max(0, ...parsePlaybackSources(item).map((source) => source.episodes.length));
}

function splitGroups(raw?: string): string[] {
  return (raw ?? "").split("$$$").filter(Boolean);
}

function splitSourceNames(raw?: string): string[] {
  return splitGroups(raw)
    .flatMap((group) => group.split(","))
    .map((value) => value.trim())
    .filter(Boolean);
}

function parseEpisodes(raw: string): Episode[] {
  return raw.split("#").flatMap((pair) => {
    const pieces = pair.split("$");
    if (pieces.length < 2) {
      return [];
    }

    const title = nilIfBlank(pieces[0]) ?? "未命名";
    const url = pieces.slice(1).join("$").trim();
    if (!url) {
      return [];
    }

    try {
      const normalizedURL = new URL(encodeURI(url)).toString();
      return [{ id: normalizedURL, title, url: normalizedURL }];
    } catch {
      return [];
    }
  });
}
