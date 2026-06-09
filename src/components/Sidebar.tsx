import { useState } from "react";
import {
  Clapperboard,
  Film,
  Heart,
  Play,
  PlayCircle,
  Search,
  Server,
  SlidersHorizontal,
  Sparkles,
  Tv,
  Users,
  Volleyball
} from "lucide-react";
import type { LibrarySection, VodCategory } from "../types";
import { useAppContext } from "../appContext";
import { SourceManager } from "./SourceManager";
import { progressLabel } from "../services/format";

interface AppSidebarProps {
  searchDraft: string;
  selectedSection: LibrarySection;
  onSearchDraftChange: (value: string) => void;
  onSelectedSectionChange: (section: LibrarySection) => void;
}

export function AppSidebar({
  searchDraft,
  selectedSection,
  onSearchDraftChange,
  onSelectedSectionChange
}: AppSidebarProps) {
  const { library, favorites, watchProgress } = useAppContext();
  const [isShowingSourceManager, setIsShowingSourceManager] = useState(false);
  const submitSearch = (value: string) => {
    void library.search(value);
    onSelectedSectionChange({ kind: "home" });
  };

  return (
    <aside className="sidebar">
      <div className="sidebar-header">
        <div className="brand-row">
          <div className="brand-mark"><Play size={17} fill="currentColor" /></div>
          <div>
            <h1>Xvideo</h1>
            <p>私人媒体库</p>
          </div>
        </div>
        <form
          className="sidebar-search"
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
        </form>
        <div className="metric-grid">
          <Metric value={String(library.total)} label="资源" />
          <Metric value={String(favorites.items.length)} label="收藏" />
          <Metric value={String(watchProgress.items.length)} label="追番" />
        </div>
      </div>

      <nav className="sidebar-nav" aria-label="媒体库">
        <SectionTitle title="媒体库" />
        <SidebarButton
          title="最新更新"
          subtitle={library.isRefreshingPreviewCache ? "正在更新本地缓存" : "本地预览优先"}
          icon={<Sparkles size={18} />}
          selected={selectedSection.kind === "home"}
          onClick={() => {
            onSelectedSectionChange({ kind: "home" });
            onSearchDraftChange("");
            void library.selectCategory(undefined);
          }}
        />
        <SidebarButton
          title="我的收藏"
          subtitle={favorites.items.length ? `${favorites.items.length} 部影片` : "还没有收藏"}
          icon={<Heart size={18} fill="currentColor" />}
          selected={selectedSection.kind === "favorites"}
          onClick={() => {
            onSelectedSectionChange({ kind: "favorites" });
            onSearchDraftChange("");
          }}
        />
        <SidebarButton
          title="继续观看"
          subtitle={watchProgress.items[0] ? progressLabel(watchProgress.items[0]) : "播放后自动记录"}
          icon={<PlayCircle size={18} fill="currentColor" />}
          selected={selectedSection.kind === "continueWatching"}
          onClick={() => {
            onSelectedSectionChange({ kind: "continueWatching" });
            onSearchDraftChange("");
          }}
        />

        <SectionTitle title="分类" />
        {library.rootCategories.map((category) => (
          <CategoryRow
            category={category}
            key={category.type_id}
            selected={selectedSection.kind === "category" && selectedSection.id === category.type_id}
            onSelect={() => {
              onSelectedSectionChange({ kind: "category", id: category.type_id });
              onSearchDraftChange("");
              void library.selectCategory(category);
            }}
            onFilter={() => {
              onSelectedSectionChange({ kind: "category", id: category.type_id });
              onSearchDraftChange("");
              void library.openFilterSearch(category);
            }}
          />
        ))}
      </nav>

      <footer className="source-footer">
        <div className="source-icon"><Server size={18} /></div>
        <div>
          <strong>{library.activeVideoSource?.name ?? "未配置视频源"}</strong>
          <span>{library.activeVideoSource ? `${formatTitle(library.activeVideoSource.format)} 数据源` : "添加自己的接口"}</span>
        </div>
        <button type="button" onClick={() => setIsShowingSourceManager(true)}>
          <SlidersHorizontal size={16} />
          配置源
        </button>
      </footer>

      {isShowingSourceManager ? <SourceManager onClose={() => setIsShowingSourceManager(false)} /> : null}
    </aside>
  );
}

function Metric({ value, label }: { value: string; label: string }) {
  return (
    <div className="metric">
      <strong>{value}</strong>
      <span>{label}</span>
    </div>
  );
}

function SectionTitle({ title }: { title: string }) {
  return <h2 className="sidebar-section-title">{title}</h2>;
}

function SidebarButton({
  title,
  subtitle,
  icon,
  selected,
  onClick
}: {
  title: string;
  subtitle: string;
  icon: React.ReactNode;
  selected: boolean;
  onClick: () => void;
}) {
  return (
    <button type="button" className={`sidebar-button ${selected ? "is-selected" : ""}`} onClick={onClick}>
      <span className="sidebar-button-icon">{icon}</span>
      <span>
        <strong>{title}</strong>
        <small>{subtitle}</small>
      </span>
    </button>
  );
}

function CategoryRow({
  category,
  selected,
  onSelect,
  onFilter
}: {
  category: VodCategory;
  selected: boolean;
  onSelect: () => void;
  onFilter: () => void;
}) {
  return (
    <div className={`category-row ${selected ? "is-selected" : ""}`}>
      <button type="button" onClick={onSelect}>
        {categoryIcon(category.type_name)}
        <span>{category.type_name}</span>
      </button>
      <button type="button" className="category-more" onClick={onFilter} title={`打开${category.type_name}筛选搜索`}>
        <SlidersHorizontal size={14} />
        More
      </button>
    </div>
  );
}

function categoryIcon(name: string) {
  if (name.includes("电影")) return <Film size={17} />;
  if (name.includes("连续") || name.includes("短剧")) return <Tv size={17} />;
  if (name.includes("动漫")) return <Clapperboard size={17} />;
  if (name.includes("综艺")) return <Users size={17} />;
  if (name.includes("体育")) return <Volleyball size={17} />;
  return <Film size={17} />;
}

function formatTitle(format: string): string {
  if (format === "auto") return "自动";
  return format.toUpperCase();
}

function formSearchValue(form: HTMLFormElement, fallback: string): string {
  return form.querySelector("input")?.value ?? fallback;
}
