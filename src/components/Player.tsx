import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  ArrowDownCircle,
  ArrowLeft,
  ExternalLink,
  FastForward,
  Heart,
  Play,
  Rewind,
  StepBack,
  StepForward
} from "lucide-react";
import type { Episode, PlaybackSource, VodItem } from "../types";
import { useAppContext } from "../appContext";
import { parseDownloads } from "../services/sourceParser";
import { metadataText, progressLabel, scoreText, summary } from "../services/format";
import { proxyURL, resolvePlaybackURL } from "../services/api";
import { Badge, EmptyState, Poster } from "./Shared";

interface MovieDetailPageProps {
  selectedPlaybackSourceID?: string;
  selectedEpisode?: Episode;
  selectedSource?: PlaybackSource;
  playbackSources: PlaybackSource[];
  onPlaybackSourceChange: (sourceID?: string) => void;
  onEpisodeChange: (episode?: Episode) => void;
  onBack: () => void;
}

export function MovieDetailPage({
  selectedPlaybackSourceID,
  selectedEpisode,
  selectedSource,
  playbackSources,
  onPlaybackSourceChange,
  onEpisodeChange,
  onBack
}: MovieDetailPageProps) {
  const { library, downloads, favorites, watchProgress } = useAppContext();
  const movie = library.detailMovie ?? library.selectedMovie;
  const downloadEpisodes = useMemo(() => parseDownloads(movie), [movie]);
  const selectedEpisodes = selectedSource?.episodes ?? [];
  const selectedIndex = selectedEpisode ? selectedEpisodes.findIndex((episode) => episode.id === selectedEpisode.id) : -1;
  const previousEpisode = selectedIndex > 0 ? selectedEpisodes[selectedIndex - 1] : undefined;
  const nextEpisode = selectedIndex >= 0 && selectedIndex + 1 < selectedEpisodes.length ? selectedEpisodes[selectedIndex + 1] : undefined;

  if (!movie) {
    return <EmptyState title="等待加载" description="选择一部影片后，这里会显示详情和播放器。" />;
  }

  return (
    <div className="detail-page">
      <header className="player-page-header">
        <button type="button" className="icon-button" aria-label="返回浏览" onClick={onBack}>
          <ArrowLeft size={18} />
        </button>
        <div>
          <h2>{movie.vod_name}</h2>
          <p>{selectedEpisode ? `正在播放：${selectedEpisode.title}` : "选择一集开始播放"}</p>
        </div>
        <div className="badge-row">
          <Badge>{movie.vod_remarks ?? "待播放"}</Badge>
          <Badge tone="gold">评分 {scoreText(movie)}</Badge>
        </div>
      </header>

      <PlayerPanel
        movie={movie}
        episode={selectedEpisode}
        playbackSource={selectedSource}
        previousEpisode={previousEpisode}
        nextEpisode={nextEpisode}
        onEpisodeChange={onEpisodeChange}
      />

      <section className="detail-hero">
        <Poster item={movie} width={172} height={244} />
        <div>
          <header>
            <div>
              <h3>{movie.vod_name}</h3>
              <div className="badge-row">
                <Badge>{movie.vod_remarks ?? "未知进度"}</Badge>
                <Badge tone="gold">评分 {scoreText(movie)}</Badge>
                {movie.type_name ? <Badge tone="blue">{movie.type_name}</Badge> : null}
              </div>
            </div>
            <button type="button" className={`favorite-button ${favorites.isFavorite(movie, library.activeVideoSourceID) ? "is-active" : ""}`} onClick={() => favorites.toggle(movie, library.activeVideoSource)}>
              <Heart size={17} fill="currentColor" />
              {favorites.isFavorite(movie, library.activeVideoSourceID) ? "已收藏" : "收藏"}
            </button>
          </header>
          <p className="metadata">{metadataText(movie, true)}</p>
          {watchProgress.progressFor(movie, library.activeVideoSourceID) ? (
            <p className="resume-line">上次看到 {progressLabel(watchProgress.progressFor(movie, library.activeVideoSourceID)!)}</p>
          ) : null}
          <p>{summary(movie)}</p>
        </div>
      </section>

      {playbackSources.length ? (
        <DetailSection title="播放列表">
          <div className="playlist-toolbar">
            <div>
              <strong>{selectedEpisode?.title ?? "选择剧集"}</strong>
              <span>{selectedSource?.name ?? "暂无播放源"}</span>
            </div>
            <button type="button" onClick={() => previousEpisode && onEpisodeChange(previousEpisode)} disabled={!previousEpisode}>
              <StepBack size={16} /> 上一集
            </button>
            <button type="button" className="primary-button" onClick={() => nextEpisode && onEpisodeChange(nextEpisode)} disabled={!nextEpisode}>
              <StepForward size={16} /> 下一集
            </button>
            <select value={selectedPlaybackSourceID ?? ""} onChange={(event) => onPlaybackSourceChange(event.target.value || undefined)}>
              {playbackSources.map((source) => <option key={source.id} value={source.id}>{source.name}</option>)}
            </select>
          </div>
          <EpisodeGrid episodes={selectedEpisodes} selectedEpisode={selectedEpisode} icon="play" onSelect={onEpisodeChange} />
        </DetailSection>
      ) : null}

      {downloadEpisodes.length ? (
        <DetailSection title="下载">
          <EpisodeGrid episodes={downloadEpisodes} icon="download" onSelect={(episode) => downloads.download(episode, movie.vod_name)} />
        </DetailSection>
      ) : null}
    </div>
  );
}

function PlayerPanel({
  movie,
  episode,
  playbackSource,
  previousEpisode,
  nextEpisode,
  onEpisodeChange
}: {
  movie: VodItem;
  episode?: Episode;
  playbackSource?: PlaybackSource;
  previousEpisode?: Episode;
  nextEpisode?: Episode;
  onEpisodeChange: (episode?: Episode) => void;
}) {
  const { library, watchProgress } = useAppContext();
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const [resolvedURL, setResolvedURL] = useState<string | undefined>();
  const [isResolving, setIsResolving] = useState(false);
  const resumeProgress = watchProgress.progressFor(movie, library.activeVideoSourceID);
  const resumePositionSeconds = resumeProgress?.positionSeconds ?? 0;
  const recordWatchProgress = watchProgress.record;

  useEffect(() => {
    let cancelled = false;
    setResolvedURL(undefined);
    if (!episode) {
      return;
    }
    if (usesWebPlayer(episode.url)) {
      setResolvedURL(episode.url);
      return;
    }
    setIsResolving(true);
    resolvePlaybackURL(episode.url)
      .then((url) => {
        if (!cancelled) {
          setResolvedURL(url);
        }
      })
      .finally(() => {
        if (!cancelled) {
          setIsResolving(false);
        }
      });
    return () => {
      cancelled = true;
    };
  }, [episode?.url]);

  useEffect(() => {
    const video = videoRef.current;
    if (!video || !episode || !resolvedURL || usesWebPlayer(episode.url)) {
      return;
    }

    const proxiedURL = proxyURL(resolvedURL);
    let hls: { destroy: () => void; loadSource: (url: string) => void; attachMedia: (media: HTMLMediaElement) => void } | undefined;
    let disposed = false;
    if (resolvedURL.toLowerCase().includes(".m3u8")) {
      void import("hls.js").then(({ default: Hls }) => {
        if (disposed) {
          return;
        }
        if (Hls.isSupported()) {
          hls = new Hls();
          hls.loadSource(proxiedURL);
          hls.attachMedia(video);
        } else {
          video.src = proxiedURL;
        }
      });
    } else {
      video.src = proxiedURL;
    }

    const resumeSeconds = resumeProgress?.episodeURL === episode.url && resumeProgress.positionSeconds > 5
      ? resumeProgress.positionSeconds
      : 0;
    const onLoadedMetadata = () => {
      if (resumeSeconds > 0 && Number.isFinite(video.duration)) {
        video.currentTime = resumeSeconds;
      }
    };
    const onEnded = () => {
      if (nextEpisode) {
        onEpisodeChange(nextEpisode);
      }
    };
    video.addEventListener("loadedmetadata", onLoadedMetadata);
    video.addEventListener("ended", onEnded);

    return () => {
      disposed = true;
      video.removeEventListener("loadedmetadata", onLoadedMetadata);
      video.removeEventListener("ended", onEnded);
      hls?.destroy();
      video.removeAttribute("src");
      video.load();
    };
  }, [episode, nextEpisode, onEpisodeChange, resolvedURL, resumeProgress]);

  const recordProgress = useCallback(() => {
    if (!episode) {
      return;
    }
    const video = videoRef.current;
    if (video && !usesWebPlayer(episode.url)) {
      recordWatchProgress(
        movie,
        library.activeVideoSource,
        playbackSource,
        episode,
        video.currentTime,
        Number.isFinite(video.duration) ? video.duration : undefined
      );
      return;
    }
    recordWatchProgress(movie, library.activeVideoSource, playbackSource, episode, resumePositionSeconds, undefined);
  }, [episode, library.activeVideoSource, movie, playbackSource, recordWatchProgress, resumePositionSeconds]);

  useEffect(() => {
    const interval = window.setInterval(recordProgress, 5000);
    return () => window.clearInterval(interval);
  }, [recordProgress]);

  useEffect(() => {
    return recordProgress;
  }, [recordProgress]);

  function skip(seconds: number) {
    const video = videoRef.current;
    if (!video) {
      return;
    }
    video.currentTime = Math.max(0, Math.min(video.duration || Number.POSITIVE_INFINITY, video.currentTime + seconds));
  }

  return (
    <section className="player-panel">
      {episode ? (
        <>
          {usesWebPlayer(episode.url) ? (
            <div className="web-player-frame">
              <iframe src={episode.url} title={episode.title} sandbox="allow-scripts allow-same-origin allow-presentation allow-forms allow-popups" />
              <a href={episode.url} target="_blank" rel="noreferrer"><ExternalLink size={16} /> 打开网页播放器</a>
            </div>
          ) : (
            <video ref={videoRef} controls playsInline />
          )}
          <div className="player-topbar">
            <span><Play size={13} fill="currentColor" /> {isResolving ? "正在解析播放地址" : episode.title}</span>
            <div>
              <button type="button" onClick={() => previousEpisode && onEpisodeChange(previousEpisode)} disabled={!previousEpisode} title={previousEpisode ? `上一集：${previousEpisode.title}` : "没有上一集"}>
                <StepBack size={17} />
              </button>
              <button type="button" onClick={() => skip(-15)} disabled={usesWebPlayer(episode.url)} title="后退15秒">
                <Rewind size={17} />
              </button>
              <button type="button" onClick={() => skip(15)} disabled={usesWebPlayer(episode.url)} title="前进15秒">
                <FastForward size={17} />
              </button>
              <button type="button" onClick={() => nextEpisode && onEpisodeChange(nextEpisode)} disabled={!nextEpisode} title={nextEpisode ? `下一集：${nextEpisode.title}` : "没有下一集"}>
                <StepForward size={17} />
              </button>
            </div>
          </div>
        </>
      ) : (
        <div className="player-empty">
          <Play size={48} />
          <strong>选择一集开始播放</strong>
        </div>
      )}
    </section>
  );
}

function DetailSection({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="detail-section">
      <h3>{title}</h3>
      {children}
    </section>
  );
}

function EpisodeGrid({
  episodes,
  selectedEpisode,
  icon,
  onSelect
}: {
  episodes: Episode[];
  selectedEpisode?: Episode;
  icon: "play" | "download";
  onSelect: (episode: Episode) => void;
}) {
  return (
    <div className="episode-grid">
      {episodes.map((episode) => {
        const selected = selectedEpisode?.id === episode.id;
        return (
          <button type="button" className={selected ? "is-selected" : ""} key={episode.id} onClick={() => onSelect(episode)}>
            {icon === "play" ? <Play size={15} /> : <ArrowDownCircle size={15} />}
            {episode.title}
          </button>
        );
      })}
    </div>
  );
}

function usesWebPlayer(url: string): boolean {
  try {
    return new URL(url).pathname.includes("/share/");
  } catch {
    return url.includes("/share/");
  }
}
