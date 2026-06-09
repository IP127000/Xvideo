import type { ReactNode } from "react";
import { ArrowDownCircle, Film, FolderOpen, ImageOff } from "lucide-react";
import type { VodItem } from "../types";
import { useAppContext } from "../appContext";
import { posterURL } from "../services/format";

interface PosterProps {
  item?: VodItem;
  width?: number;
  height?: number;
  className?: string;
}

export function Poster({ item, width, height, className }: PosterProps) {
  const url = posterURL(item);
  const style = {
    "--poster-width": width ? `${width}px` : undefined,
    "--poster-height": height ? `${height}px` : undefined
  } as React.CSSProperties;

  return (
    <div className={`poster ${className ?? ""}`} style={style}>
      {url ? <img src={url} alt={item?.vod_name ?? "海报"} loading="lazy" /> : <ImageOff aria-hidden="true" />}
    </div>
  );
}

interface BadgeProps {
  children: ReactNode;
  tone?: "red" | "gold" | "blue" | "teal" | "pink" | "muted";
}

export function Badge({ children, tone = "red" }: BadgeProps) {
  return <span className={`badge badge-${tone}`}>{children}</span>;
}

interface EmptyStateProps {
  title: string;
  description: string;
  icon?: ReactNode;
}

export function EmptyState({ title, description, icon }: EmptyStateProps) {
  return (
    <div className="empty-state">
      <div className="empty-icon">{icon ?? <Film aria-hidden="true" />}</div>
      <h2>{title}</h2>
      <p>{description}</p>
    </div>
  );
}

interface LoadingStateProps {
  title: string;
  subtitle: string;
}

export function LoadingState({ title, subtitle }: LoadingStateProps) {
  return (
    <div className="loading-state">
      <span className="spinner" aria-hidden="true" />
      <h2>{title}</h2>
      <p>{subtitle}</p>
    </div>
  );
}

export function IconButton({
  label,
  children,
  onClick,
  disabled = false,
  active = false
}: {
  label: string;
  children: ReactNode;
  onClick?: () => void;
  disabled?: boolean;
  active?: boolean;
}) {
  return (
    <button className={`icon-button ${active ? "is-active" : ""}`} type="button" aria-label={label} title={label} onClick={onClick} disabled={disabled}>
      {children}
    </button>
  );
}

export function DownloadShelf() {
  const { downloads } = useAppContext();
  if (downloads.tasks.length === 0) {
    return null;
  }

  return (
    <aside className="download-shelf" aria-label="下载任务">
      <header>
        <span><ArrowDownCircle size={18} /> 下载</span>
        <strong>{downloads.tasks.length}</strong>
      </header>
      {downloads.tasks.slice(0, 3).map((task) => (
        <div className="download-task" key={task.id}>
          <div className="download-task-title">
            <span>{task.title}</span>
            {task.localURL ? (
              <a href={task.localURL} download title="再次保存下载文件">
                <FolderOpen size={14} />
              </a>
            ) : null}
          </div>
          <progress value={task.progress} max={1} />
          <small>{task.statusLabel}</small>
        </div>
      ))}
    </aside>
  );
}

export function Modal({
  title,
  children,
  onClose
}: {
  title: string;
  children: ReactNode;
  onClose: () => void;
}) {
  return (
    <div className="modal-backdrop" role="presentation" onMouseDown={onClose}>
      <section className="modal-panel" role="dialog" aria-modal="true" aria-label={title} onMouseDown={(event) => event.stopPropagation()}>
        {children}
      </section>
    </div>
  );
}
