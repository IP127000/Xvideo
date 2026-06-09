import { useCallback, useEffect, useMemo, useState } from "react";
import type { Episode, FavoriteMovie, LibrarySection, PlaybackSource, VodItem, WatchProgressItem } from "./types";
import { AppContext } from "./appContext";
import { useDownloads } from "./hooks/useDownloads";
import { useLibrary } from "./hooks/useLibrary";
import { useFavorites, useWatchProgress } from "./hooks/usePersistentStores";
import { parsePlaybackSources } from "./services/sourceParser";
import { AppSidebar } from "./components/Sidebar";
import { MediaBrowser } from "./components/Browser";
import { MovieDetailPage } from "./components/Player";
import { DownloadShelf } from "./components/Shared";

export default function App() {
  const library = useLibrary();
  const favorites = useFavorites();
  const watchProgress = useWatchProgress();
  const downloads = useDownloads();

  const [searchDraft, setSearchDraft] = useState("");
  const [selectedSection, setSelectedSection] = useState<LibrarySection>({ kind: "home" });
  const [route, setRoute] = useState<"browse" | "watch">("browse");
  const [selectedPlaybackSourceID, setSelectedPlaybackSourceID] = useState<string | undefined>();
  const [selectedEpisode, setSelectedEpisode] = useState<Episode | undefined>();
  const [pendingWatchProgress, setPendingWatchProgress] = useState<WatchProgressItem | undefined>();

  const movie = library.detailMovie ?? library.selectedMovie;
  const playbackSources = useMemo(() => parsePlaybackSources(movie), [movie]);
  const selectedSource = useMemo(() => {
    return playbackSources.find((source) => source.id === selectedPlaybackSourceID) ?? playbackSources[0];
  }, [playbackSources, selectedPlaybackSourceID]);

  useEffect(() => {
    setSearchDraft(library.searchText);
  }, [library.searchText]);

  useEffect(() => {
    setRoute("browse");
  }, [selectedSection]);

  useEffect(() => {
    selectPreferredPlayback(movie);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [movie?.vod_id, library.activeVideoSourceID]);

  const selectPlaybackFromProgress = useCallback((progress: WatchProgressItem, currentMovie: VodItem) => {
    const sources = parsePlaybackSources(currentMovie);
    const source = sources.find((item) => item.id === progress.playbackSourceID) ??
      sources.find((item) => item.episodes.some((episode) => episode.url === progress.episodeURL)) ??
      sources[0];
    const episode = source?.episodes.find((item) => item.url === progress.episodeURL) ?? source?.episodes[0];
    setSelectedPlaybackSourceID(source?.id);
    setSelectedEpisode(episode);
    setPendingWatchProgress(undefined);
  }, []);

  const openMovie = useCallback((item: VodItem) => {
    void library.selectMovie(item);
  }, [library]);

  const playMovie = useCallback(async (item: VodItem) => {
    await library.selectMovie(item);
    setRoute("watch");
  }, [library]);

  const selectFavorite = useCallback(async (favorite: FavoriteMovie) => {
    if (favorite.sourceID && favorite.sourceID !== library.activeVideoSourceID) {
      const source = library.videoSources.find((item) => item.id === favorite.sourceID);
      if (source) {
        const switched = await library.selectVideoSource(source);
        if (!switched) {
          return false;
        }
      } else if (!favorite.item.vod_play_url) {
        library.setErrorMessage("收藏所属的数据源已不可用，无法重新加载详情。");
        return false;
      }
    }
    await library.selectMovie(favorite.item, true);
    return true;
  }, [library]);

  const openFavorite = useCallback(async (favorite: FavoriteMovie) => {
    if (await selectFavorite(favorite)) {
      setRoute("watch");
    }
  }, [selectFavorite]);

  const selectProgress = useCallback(async (progress: WatchProgressItem) => {
    if (progress.sourceID && progress.sourceID !== library.activeVideoSourceID) {
      const source = library.videoSources.find((item) => item.id === progress.sourceID);
      if (source) {
        const switched = await library.selectVideoSource(source);
        if (!switched) {
          return false;
        }
      } else if (!progress.item.vod_play_url) {
        library.setErrorMessage("观看记录所属的数据源已不可用，无法继续播放。");
        return false;
      }
    }
    setPendingWatchProgress(progress);
    await library.selectMovie(progress.item, true);
    return true;
  }, [library]);

  const openProgress = useCallback(async (progress: WatchProgressItem) => {
    if (await selectProgress(progress)) {
      setRoute("watch");
      selectPlaybackFromProgress(progress, library.detailMovie ?? library.selectedMovie ?? progress.item);
    }
  }, [library.detailMovie, library.selectedMovie, selectPlaybackFromProgress, selectProgress]);

  const value = useMemo(() => ({
    library,
    favorites,
    watchProgress,
    downloads
  }), [library, favorites, watchProgress, downloads]);

  function selectPreferredPlayback(currentMovie?: VodItem) {
    if (!currentMovie) {
      setSelectedPlaybackSourceID(undefined);
      setSelectedEpisode(undefined);
      return;
    }

    if (pendingWatchProgress && watchProgressMatches(pendingWatchProgress, currentMovie, library.activeVideoSourceID)) {
      selectPlaybackFromProgress(pendingWatchProgress, currentMovie);
      return;
    }

    const progress = watchProgress.progressFor(currentMovie, library.activeVideoSourceID);
    if (progress) {
      selectPlaybackFromProgress(progress, currentMovie);
      return;
    }

    const sources = parsePlaybackSources(currentMovie);
    const preferredSource = sources.find((source) => source.name.toLowerCase().includes("m3u8")) ?? sources[0];
    setSelectedPlaybackSourceID(preferredSource?.id);
    setSelectedEpisode(preferredSource?.episodes[0]);
  }

  return (
    <AppContext.Provider value={value}>
      <main className="app-shell">
        <AppSidebar
          searchDraft={searchDraft}
          selectedSection={selectedSection}
          onSearchDraftChange={setSearchDraft}
          onSelectedSectionChange={setSelectedSection}
        />
        <section className="main-stage">
          {route === "browse" ? (
            <MediaBrowser
              searchDraft={searchDraft}
              selectedSection={selectedSection}
              onSearchDraftChange={setSearchDraft}
              onOpenMovie={openMovie}
              onPlayMovie={playMovie}
              onOpenFavorite={(favorite) => void openFavorite(favorite)}
              onPlayFavorite={(favorite) => void openFavorite(favorite)}
              onOpenProgress={(progress) => void openProgress(progress)}
              onPlayProgress={(progress) => void openProgress(progress)}
            />
          ) : (
            <MovieDetailPage
              selectedPlaybackSourceID={selectedPlaybackSourceID}
              selectedEpisode={selectedEpisode}
              selectedSource={selectedSource}
              playbackSources={playbackSources}
              onPlaybackSourceChange={(sourceID) => {
                setSelectedPlaybackSourceID(sourceID);
                setSelectedEpisode(playbackSources.find((source) => source.id === sourceID)?.episodes[0]);
              }}
              onEpisodeChange={setSelectedEpisode}
              onBack={() => setRoute("browse")}
            />
          )}
        </section>
        <DownloadShelf />
      </main>
    </AppContext.Provider>
  );
}

function watchProgressMatches(progress: WatchProgressItem, item: VodItem, sourceID?: string): boolean {
  if (progress.item.vod_id !== item.vod_id) {
    return false;
  }
  if (!progress.sourceID) {
    return true;
  }
  return progress.sourceID === sourceID;
}
