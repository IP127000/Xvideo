import { useCallback, useEffect, useMemo, useState } from "react";
import type { Episode, FavoriteMovie, PlaybackSource, VideoSource, VodItem, WatchProgressItem } from "../types";
import { normalizePosition } from "../services/format";
import { loadFavorites, loadWatchProgress, saveFavorites, saveWatchProgress } from "../services/storage";

export function favoriteID(item: VodItem, sourceID?: string): string {
  return `${sourceID ?? "legacy"}-${item.vod_id}`;
}

export function watchProgressID(item: VodItem, sourceID?: string): string {
  return `${sourceID ?? "legacy"}-${item.vod_id}`;
}

export function useFavorites() {
  const [items, setItems] = useState<FavoriteMovie[]>(() => loadFavorites());

  useEffect(() => {
    saveFavorites(items);
  }, [items]);

  const isFavorite = useCallback((item?: VodItem, sourceID?: string) => {
    if (!item) {
      return false;
    }
    const id = favoriteID(item, sourceID);
    return items.some((favorite) => favoriteID(favorite.item, favorite.sourceID) === id);
  }, [items]);

  const toggle = useCallback((item: VodItem, source?: VideoSource) => {
    setItems((current) => {
      const id = favoriteID(item, source?.id);
      if (current.some((favorite) => favoriteID(favorite.item, favorite.sourceID) === id)) {
        return current.filter((favorite) => favoriteID(favorite.item, favorite.sourceID) !== id);
      }
      return [{ item, addedAt: new Date().toISOString(), sourceID: source?.id, sourceName: source?.name }, ...current];
    });
  }, []);

  return useMemo(() => ({ items, isFavorite, toggle }), [items, isFavorite, toggle]);
}

export function useWatchProgress() {
  const [items, setItems] = useState<WatchProgressItem[]>(() => loadWatchProgress());

  useEffect(() => {
    saveWatchProgress(items);
  }, [items]);

  const progressFor = useCallback((item?: VodItem, sourceID?: string) => {
    if (!item) {
      return undefined;
    }
    const id = watchProgressID(item, sourceID);
    return items.find((progress) => watchProgressID(progress.item, progress.sourceID) === id);
  }, [items]);

  const record = useCallback((
    item: VodItem,
    source: VideoSource | undefined,
    playbackSource: PlaybackSource | undefined,
    episode: Episode,
    positionSeconds: number,
    durationSeconds?: number
  ) => {
    const progress: WatchProgressItem = {
      item,
      sourceID: source?.id,
      sourceName: source?.name,
      playbackSourceID: playbackSource?.id,
      playbackSourceName: playbackSource?.name,
      episodeTitle: episode.title,
      episodeURL: episode.url,
      positionSeconds: normalizePosition(positionSeconds, durationSeconds),
      durationSeconds: durationSeconds && Number.isFinite(durationSeconds) && durationSeconds > 0 ? durationSeconds : undefined,
      updatedAt: new Date().toISOString()
    };
    const id = watchProgressID(item, source?.id);
    setItems((current) => [progress, ...current.filter((entry) => watchProgressID(entry.item, entry.sourceID) !== id)].slice(0, 80));
  }, []);

  const remove = useCallback((item: WatchProgressItem) => {
    const id = watchProgressID(item.item, item.sourceID);
    setItems((current) => current.filter((entry) => watchProgressID(entry.item, entry.sourceID) !== id));
  }, []);

  return useMemo(() => ({ items, progressFor, record, remove }), [items, progressFor, record, remove]);
}
