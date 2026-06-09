import { useMemo, useState } from "react";
import {
  ArrowDownCircle,
  Heart,
  LineChart,
  Play,
  PlayCircle,
  RefreshCw,
  Search,
  Shuffle,
  SlidersHorizontal,
  X
} from "lucide-react";
import type { FavoriteMovie, LibrarySection, VodItem, WatchProgressItem } from "../types";
import { useAppContext } from "../appContext";
import { episodeCount } from "../services/sourceParser";
import { formattedUpdateDate, metadataText, progressFraction, progressLabel, scoreText, summary } from "../services/format";
import { Badge, EmptyState, LoadingState, Poster } from "./Shared";

interface MediaBrowserProps {
  searchDraft: string;
  selectedSection: LibrarySection;
  onSearchDraftChange: (value: string) => void;
  onOpenMovie: (movie: VodItem) => void;
  onPlayMovie: (movie: VodItem) => void;
  onOpenFavorite: (favorite: FavoriteMovie) => void;
  onPlayFavorite: (favorite: FavoriteMovie) => void;
  onOpenProgress: (progress: WatchProgressItem) => void;
  onPlayProgress: (progress: WatchProgressItem) => void;
}

export function MediaBrowser(props: MediaBrowserProps) {
  if (props.selectedSection.kind === "favorites") {
    return <FavoritesBrowser onOpenFavorite={props.onOpenFavorite} onPlayFavorite={props.onPlayFavorite} />;
  }
  if (props.selectedSection.kind === "continueWatching") {
    return <ContinueWatchingBrowser onOpenProgress={props.onOpenProgress} onPlayProgress={props.onPlayProgress} />;
  }
  return <MovieListBrowser {...props} />;
}

function MovieListBrowser({
  searchDraft,
  onSearchDraftChange,
  onOpenMovie,
  onOpenProgress,
  onPlayMovie
}: MediaBrowserProps) {
  const { library, favorites, watchProgress } = useAppContext();
  const [isFilterPanelOpen, setIsFilterPanelOpen] = useState(false);
  const [featuredBatchIndex, setFeaturedBatchIndex] = useState(0);
  const [gridBatchIndex, setGridBatchIndex] = useState(0);
  const [previewMovie, setPreviewMovie] = useState<VodItem | undefined>();
  const featuredMovieLimit = 10;
  const gridBatchSize = 12;

  const featuredCandidates = useMemo(() => library.movies
    .map((movie, index) => ({ movie, index, favorite: favorites.isFavorite(movie, library.activeVideoSourceID) }))
    .sort((lhs, rhs) => lhs.favorite === rhs.favorite ? lhs.index - rhs.index : lhs.favorite ? -1 : 1)
    .map((entry) => entry.movie), [favorites, library.activeVideoSourceID, library.movies]);

  const railMovies = useMemo(() => {
    const start = Math.min(featuredBatchIndex * featuredMovieLimit, Math.max(featuredCandidates.length - 1, 0));
    return featuredCandidates.slice(start, start + featuredMovieLimit);
  }, [featuredBatchIndex, featuredCandidates]);

  const gridMovies = useMemo(() => {
    const featuredIDs = new Set(railMovies.map((movie) => movie.vod_id));
    return library.movies.filter((movie) => !featuredIDs.has(movie.vod_id));
  }, [library.movies, railMovies]);

  const visibleGridMovies = useMemo(() => {
    const start = Math.min(gridBatchIndex * gridBatchSize, Math.max(gridMovies.length - 1, 0));
    return gridMovies.slice(start, start + gridBatchSize);
  }, [gridBatchIndex, gridMovies]);

  const spotlightMovie = library.selectedMovie ?? library.movies[0];
  const canShuffleFeatured = featuredCandidates.length > featuredMovieLimit;
  const canShuffleGrid = gridMovies.length > gridBatchSize;

  function nextFeaturedBatch() {
    if (!canShuffleFeatured) return;
    setFeaturedBatchIndex((current) => (current + 1) % Math.ceil(featuredCandidates.length / featuredMovieLimit));
  }

  function nextGridBatch() {
    if (!canShuffleGrid) return;
    setPreviewMovie(undefined);
    setGridBatchIndex((current) => (current + 1) % Math.ceil(gridMovies.length / gridBatchSize));
  }

  return (
    <div className="browser-view">
      <BrowserHeader
        searchDraft={searchDraft}
        isFilterPanelOpen={isFilterPanelOpen}
        onSearchDraftChange={onSearchDraftChange}
        onOpenFilter={() => {
          setIsFilterPanelOpen(true);
          void library.openFilterSearch(library.selectedCategory);
        }}
        onCloseFilter={() => setIsFilterPanelOpen(false)}
      />

      {isFilterPanelOpen && library.isShowingFilterSearch ? (
        <FilterSearchPanel
          searchDraft={searchDraft}
          onSearchDraftChange={onSearchDraftChange}
          onClose={() => setIsFilterPanelOpen(false)}
        />
      ) : null}

      {library.movies.length === 0 && library.isLoadingList ? (
        <LoadingState title="正在加载片库" subtitle="优先读取本地缓存，必要时连接数据源" />
      ) : library.movies.length === 0 ? (
        <EmptyState title="暂无内容" description={library.hasActiveVideoSource ? "可以换个分类或关键词试试。" : "请先配置自己的采集接口。"} />
      ) : (
        <div className="browser-scroll">
          {library.isShowingSearchResults ? (
            <SearchResultsGrid
              movies={library.movies}
              onOpenMovie={onOpenMovie}
              onPlayMovie={onPlayMovie}
            />
          ) : (
            <>
              {spotlightMovie ? <SpotlightHero movie={spotlightMovie} onPlay={() => onPlayMovie(spotlightMovie)} /> : null}
              {watchProgress.items.length ? (
                <ContinueWatchingRail items={watchProgress.items.slice(0, 10)} onOpenProgress={onOpenProgress} />
              ) : null}
              <MovieRail
                title="精选影片"
                subtitle={`${railMovies.length} 部正在展示`}
                movies={railMovies}
                canShuffle={canShuffleFeatured}
                onShuffle={nextFeaturedBatch}
                onOpenMovie={onOpenMovie}
                onPlayMovie={onPlayMovie}
                onPreviewMovie={setPreviewMovie}
              />
              <MovieGrid
                movies={visibleGridMovies}
                canShuffle={canShuffleGrid}
                onShuffle={nextGridBatch}
                onOpenMovie={onOpenMovie}
                onPlayMovie={onPlayMovie}
                onPreviewMovie={setPreviewMovie}
              />
            </>
          )}
          {library.isLoadingList ? <div className="inline-loader"><span className="spinner" /> 正在加载</div> : null}
        </div>
      )}

      {previewMovie ? <MoviePreviewPopover movie={previewMovie} onClose={() => setPreviewMovie(undefined)} /> : null}
      {library.errorMessage ? (
        <div className="toast" role="alert">
          <span>{library.errorMessage}</span>
          <button type="button" onClick={() => library.setErrorMessage(undefined)}><X size={15} /></button>
        </div>
      ) : null}
    </div>
  );
}

function BrowserHeader({
  searchDraft,
  isFilterPanelOpen,
  onSearchDraftChange,
  onOpenFilter,
  onCloseFilter
}: {
  searchDraft: string;
  isFilterPanelOpen: boolean;
  onSearchDraftChange: (value: string) => void;
  onOpenFilter: () => void;
  onCloseFilter: () => void;
}) {
  const { library } = useAppContext();
  const submitSearch = (value: string) => {
    void library.search(value);
  };

  return (
    <header className="browser-header">
      <div>
        <h2>{library.currentTitle}</h2>
        <p>{headerSubtitle(library, isFilterPanelOpen)}</p>
      </div>
      <form
        className="header-search"
        onSubmit={(event) => {
          event.preventDefault();
          submitSearch(formSearchValue(event.currentTarget, searchDraft));
        }}
      >
        <Search size={17} />
        <input
          value={searchDraft}
          onChange={(event) => onSearchDraftChange(event.target.value)}
          onKeyDown={(event) => {
            if (event.key === "Enter") {
              event.preventDefault();
              submitSearch(event.currentTarget.value);
            }
          }}
          placeholder="搜索影片、演员或关键词"
        />
        {searchDraft ? (
          <button
            type="button"
            aria-label="清空搜索"
            onClick={() => {
              onSearchDraftChange("");
              library.setSearchText("");
              void library.selectCategory(library.selectedCategory);
            }}
          >
            <X size={15} />
          </button>
        ) : null}
      </form>
      {library.isRefreshingPreviewCache ? <span className="spinner" aria-label="正在更新本地预览" /> : null}
      <button type="button" className="icon-button" aria-label="刷新" title="刷新" onClick={() => void library.refresh()}>
        <RefreshCw size={17} />
      </button>
      {library.canRequestMoreForCurrentSelection ? (
        <button
          type="button"
          className="filter-button"
          onClick={isFilterPanelOpen ? onCloseFilter : onOpenFilter}
          disabled={library.isLoadingList}
        >
          <SlidersHorizontal size={15} />
          More
        </button>
      ) : null}
      {library.childCategories.length ? <ChildCategoryStrip /> : null}
    </header>
  );
}

function headerSubtitle(library: ReturnType<typeof useAppContext>["library"], isFilterPanelOpen: boolean): string {
  if (library.isShowingSearchResults) {
    return `${library.total} 条匹配结果`;
  }
  if (isFilterPanelOpen) {
    const parts = [library.filterCategory?.type_name, library.filterYear, library.filterArea].filter(Boolean);
    return parts.length ? parts.join(" · ") : "筛选搜索";
  }
  if (library.isShowingPreview) {
    return "大屏浏览模式 · 点击影片查看详情";
  }
  return `${library.total} 条结果`;
}

function formSearchValue(form: HTMLFormElement, fallback: string): string {
  return form.querySelector("input")?.value ?? fallback;
}

function ChildCategoryStrip() {
  const { library } = useAppContext();
  return (
    <div className="child-strip">
      {library.childCategories.map((category) => (
        <div className={`child-category ${library.selectedCategory?.type_id === category.type_id ? "is-selected" : ""}`} key={category.type_id}>
          <button type="button" onClick={() => void library.selectCategory(category)}>{category.type_name}</button>
          <button type="button" title={`打开${category.type_name}筛选搜索`} onClick={() => void library.openFilterSearch(category)}>
            <SlidersHorizontal size={13} /> More
          </button>
        </div>
      ))}
    </div>
  );
}

function FilterSearchPanel({
  searchDraft,
  onSearchDraftChange,
  onClose
}: {
  searchDraft: string;
  onSearchDraftChange: (value: string) => void;
  onClose: () => void;
}) {
  const { library } = useAppContext();
  const submitSearch = (value: string) => {
    void library.search(value);
  };

  return (
    <section className="filter-panel">
      <header>
        <strong><SlidersHorizontal size={17} /> 筛选搜索</strong>
        <button type="button" aria-label="关闭筛选搜索" onClick={onClose}><X size={14} /></button>
      </header>
      <form
        className="filter-search-field"
        onSubmit={(event) => {
          event.preventDefault();
          submitSearch(formSearchValue(event.currentTarget, searchDraft));
        }}
      >
        <Search size={16} />
        <input
          value={searchDraft}
          onChange={(event) => onSearchDraftChange(event.target.value)}
          onKeyDown={(event) => {
            if (event.key === "Enter") {
              event.preventDefault();
              submitSearch(event.currentTarget.value);
            }
          }}
          placeholder="搜索影片、演员或关键词"
        />
      </form>
      <FilterRow title="类型">
        {library.filterCategories.map((category) => (
          <button
            type="button"
            key={category.type_id}
            className={library.filterCategory?.type_id === category.type_id ? "is-selected" : ""}
            onClick={() => void library.updateFilterCategory(category)}
          >
            {category.type_name}
          </button>
        ))}
      </FilterRow>
      <FilterRow title="时间">
        {library.filterYears.map((year) => (
          <button type="button" key={year || "all"} className={library.filterYear === year ? "is-selected" : ""} onClick={() => void library.updateFilterYear(year)}>
            {year || "全部"}
          </button>
        ))}
      </FilterRow>
      <FilterRow title="地区">
        {library.filterAreas.map((area) => (
          <button type="button" key={area || "all"} className={library.filterArea === area ? "is-selected" : ""} onClick={() => void library.updateFilterArea(area)}>
            {area || "全部"}
          </button>
        ))}
      </FilterRow>
      <footer>
        <span><LineChart size={15} /> 高级筛选</span>
        <button type="button" onClick={() => void library.resetFilters()} disabled={!library.filterYear && !library.filterArea}>重置</button>
      </footer>
    </section>
  );
}

function FilterRow({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="filter-row">
      <span>{title}</span>
      <div>{children}</div>
    </div>
  );
}

function SpotlightHero({ movie, onPlay }: { movie: VodItem; onPlay: () => void }) {
  return (
    <section className="spotlight">
      <div className="spotlight-copy">
        <div className="badge-row">
          <Badge>{movie.vod_remarks ?? "最新推荐"}</Badge>
          <Badge tone="gold">评分 {scoreText(movie)}</Badge>
          {movie.type_name ? <Badge tone="teal">{movie.type_name}</Badge> : null}
        </div>
        <h2>{movie.vod_name}</h2>
        <p className="metadata">{metadataText(movie)}</p>
        <p>{summary(movie)}</p>
        <button type="button" className="primary-button" onClick={onPlay}>
          <Play size={17} fill="currentColor" />
          开始播放
        </button>
      </div>
      <Poster item={movie} width={270} height={382} className="spotlight-poster" />
    </section>
  );
}

function ContinueWatchingRail({ items, onOpenProgress }: { items: WatchProgressItem[]; onOpenProgress: (progress: WatchProgressItem) => void }) {
  return (
    <section className="media-section">
      <SectionHeader title="继续观看" subtitle={`${items.length} 部最近播放`} />
      <div className="progress-rail">
        {items.map((item) => <WatchProgressCard item={item} key={`${item.sourceID ?? "legacy"}-${item.item.vod_id}`} onOpen={onOpenProgress} />)}
      </div>
    </section>
  );
}

function MovieRail({
  title,
  subtitle,
  movies,
  canShuffle,
  onShuffle,
  onOpenMovie,
  onPlayMovie,
  onPreviewMovie
}: {
  title: string;
  subtitle: string;
  movies: VodItem[];
  canShuffle: boolean;
  onShuffle: () => void;
  onOpenMovie: (movie: VodItem) => void;
  onPlayMovie: (movie: VodItem) => void;
  onPreviewMovie: (movie: VodItem) => void;
}) {
  return (
    <section className="media-section">
      <SectionHeader title={title} subtitle={subtitle} action={<ShuffleButton disabled={!canShuffle} onClick={onShuffle} />} />
      <div className="movie-rail">
        {movies.map((movie) => (
          <MoviePosterCard key={movie.vod_id} movie={movie} width={150} onOpen={onOpenMovie} onPlay={onPlayMovie} onPreview={onPreviewMovie} />
        ))}
      </div>
    </section>
  );
}

function MovieGrid({
  movies,
  canShuffle,
  onShuffle,
  onOpenMovie,
  onPlayMovie,
  onPreviewMovie
}: {
  movies: VodItem[];
  canShuffle: boolean;
  onShuffle: () => void;
  onOpenMovie: (movie: VodItem) => void;
  onPlayMovie: (movie: VodItem) => void;
  onPreviewMovie: (movie: VodItem) => void;
}) {
  return (
    <section className="media-section">
      <SectionHeader title="全部影片" subtitle={movies.length ? `${movies.length} 部正在展示` : ""} action={<ShuffleButton disabled={!canShuffle} onClick={onShuffle} />} />
      {movies.length ? (
        <div className="movie-grid">
          {movies.map((movie) => <MoviePosterCard key={movie.vod_id} movie={movie} onOpen={onOpenMovie} onPlay={onPlayMovie} onPreview={onPreviewMovie} />)}
        </div>
      ) : (
        <div className="load-all-hint"><ArrowDownCircle size={18} /> 加载全部影片</div>
      )}
    </section>
  );
}

function SearchResultsGrid({ movies, onOpenMovie, onPlayMovie }: { movies: VodItem[]; onOpenMovie: (movie: VodItem) => void; onPlayMovie: (movie: VodItem) => void }) {
  const { library } = useAppContext();
  return (
    <div className="movie-grid search-grid">
      {movies.map((movie) => (
        <MoviePosterCard
          key={movie.vod_id}
          movie={movie}
          onOpen={onOpenMovie}
          onPlay={onPlayMovie}
          onPreview={() => undefined}
          onVisible={() => void library.loadNextPageIfNeeded(movie)}
        />
      ))}
    </div>
  );
}

function SectionHeader({ title, subtitle, action }: { title: string; subtitle?: string; action?: React.ReactNode }) {
  return (
    <header className="section-header">
      <h3>{title}</h3>
      {subtitle ? <span>{subtitle}</span> : null}
      <div>{action}</div>
    </header>
  );
}

function ShuffleButton({ disabled, onClick }: { disabled: boolean; onClick: () => void }) {
  return (
    <button type="button" className="shuffle-button" onClick={onClick} disabled={disabled}>
      <Shuffle size={15} /> 换一批
    </button>
  );
}

function MoviePosterCard({
  movie,
  width,
  onOpen,
  onPlay,
  onPreview,
  onVisible
}: {
  movie: VodItem;
  width?: number;
  onOpen: (movie: VodItem) => void;
  onPlay: (movie: VodItem) => void;
  onPreview: (movie: VodItem) => void;
  onVisible?: () => void;
}) {
  const { library, favorites } = useAppContext();
  const isSelected = library.selectedMovie?.vod_id === movie.vod_id;

  return (
    <article
      className={`movie-card ${isSelected ? "is-selected" : ""}`}
      style={{ "--card-width": width ? `${width}px` : undefined } as React.CSSProperties}
      onMouseEnter={() => onPreview(movie)}
      ref={(node) => {
        if (!node || !onVisible) return;
        const observer = new IntersectionObserver(([entry]) => {
          if (entry?.isIntersecting) {
            onVisible();
            observer.disconnect();
          }
        });
        observer.observe(node);
      }}
    >
      <button type="button" onClick={() => onOpen(movie)} onDoubleClick={() => onPlay(movie)}>
        <div className="movie-poster-wrap">
          <Poster item={movie} />
          {favorites.isFavorite(movie, library.activeVideoSourceID) ? <span className="favorite-dot"><Heart size={13} fill="currentColor" /></span> : null}
          <span className="play-hint"><Play size={13} fill="currentColor" /> 双击播放</span>
        </div>
        <strong>{movie.vod_name}</strong>
        <small>
          {[movie.vod_remarks, episodeCount(movie) > 1 ? `${episodeCount(movie)} 集` : undefined, movie.vod_year, formattedUpdateDate(movie)]
            .filter(Boolean)
            .join(" · ")}
        </small>
      </button>
    </article>
  );
}

function MoviePreviewPopover({ movie, onClose }: { movie: VodItem; onClose: () => void }) {
  return (
    <aside className="movie-preview-popover">
      <button type="button" aria-label="关闭详情预览" onClick={onClose}><X size={14} /></button>
      <header>
        <h3>{movie.vod_name}</h3>
        <Badge>双击播放</Badge>
      </header>
      <p className="metadata">{[movie.vod_year, movie.vod_area, movie.type_name, movie.vod_class].filter(Boolean).join(" · ") || "暂无元数据"}</p>
      <p>{summary(movie)}</p>
      <dl>
        <div><dt>更新</dt><dd>{formattedUpdateDate(movie) ?? movie.vod_time ?? "暂无"}</dd></div>
        <div><dt>剧集</dt><dd>{episodeCount(movie) > 1 ? `${episodeCount(movie)} 集` : movie.vod_remarks ?? "暂无"}</dd></div>
        <div><dt>主演</dt><dd>{movie.vod_actor ?? "暂无"}</dd></div>
        <div><dt>导演</dt><dd>{movie.vod_director ?? "暂无"}</dd></div>
      </dl>
    </aside>
  );
}

function FavoritesBrowser({ onOpenFavorite, onPlayFavorite }: { onOpenFavorite: (favorite: FavoriteMovie) => void; onPlayFavorite: (favorite: FavoriteMovie) => void }) {
  const { favorites } = useAppContext();
  return (
    <div className="collection-page favorites-page">
      <header>
        <h2><Heart size={32} fill="currentColor" /> 我的收藏</h2>
        <p>{favorites.items.length ? `${favorites.items.length} 部常看内容` : "收藏喜欢的影片后会出现在这里"}</p>
      </header>
      {favorites.items.length ? (
        <div className="movie-grid">
          {favorites.items.map((favorite) => (
            <MoviePosterCard
              key={`${favorite.sourceID ?? "legacy"}-${favorite.item.vod_id}`}
              movie={favorite.item}
              onOpen={() => onOpenFavorite(favorite)}
              onPlay={() => onPlayFavorite(favorite)}
              onPreview={() => undefined}
            />
          ))}
        </div>
      ) : <EmptyState title="暂无收藏" description="在播放页点击收藏即可加入这里。" icon={<Heart />} />}
    </div>
  );
}

function ContinueWatchingBrowser({ onOpenProgress, onPlayProgress }: { onOpenProgress: (progress: WatchProgressItem) => void; onPlayProgress: (progress: WatchProgressItem) => void }) {
  const { watchProgress } = useAppContext();
  return (
    <div className="collection-page continue-page">
      <header>
        <h2><PlayCircle size={32} fill="currentColor" /> 继续观看</h2>
        <p>{watchProgress.items.length ? `${watchProgress.items.length} 部最近播放` : "播放过的剧集会出现在这里"}</p>
      </header>
      {watchProgress.items.length ? (
        <div className="watch-grid">
          {watchProgress.items.map((item) => (
            <WatchProgressCard
              item={item}
              key={`${item.sourceID ?? "legacy"}-${item.item.vod_id}`}
              onOpen={(progress) => onPlayProgress(progress)}
              onRemove={() => watchProgress.remove(item)}
            />
          ))}
        </div>
      ) : <EmptyState title="暂无观看记录" description="开始播放任意剧集后，就能从这里继续。" icon={<PlayCircle />} />}
    </div>
  );
}

function WatchProgressCard({
  item,
  onOpen,
  onRemove
}: {
  item: WatchProgressItem;
  onOpen: (progress: WatchProgressItem) => void;
  onRemove?: () => void;
}) {
  return (
    <article className="watch-card">
      <button type="button" onClick={() => onOpen(item)}>
        <Poster item={item.item} width={82} height={116} />
        <div>
          <span className="continue-chip"><Play size={12} fill="currentColor" /> 继续</span>
          <strong>{item.item.vod_name}</strong>
          <small>{progressLabel(item)}</small>
          <progress value={progressFraction(item) ?? 0} max={1} />
          <em>{item.sourceName ?? item.playbackSourceName ?? "本地记录"}</em>
        </div>
      </button>
      {onRemove ? <button type="button" className="remove-progress" onClick={onRemove}>移除记录</button> : null}
    </article>
  );
}
