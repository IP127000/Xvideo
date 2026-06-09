import { useState } from "react";
import { CheckCircle, PlayCircle, PlusCircle, Server, Trash2, X } from "lucide-react";
import type { VideoSourceFormat } from "../types";
import { useAppContext } from "../appContext";
import { Modal } from "./Shared";

interface SourceManagerProps {
  onClose: () => void;
}

export function SourceManager({ onClose }: SourceManagerProps) {
  const { library } = useAppContext();
  const [name, setName] = useState("");
  const [homepageURL, setHomepageURL] = useState("");
  const [apiURL, setAPIURL] = useState("");
  const [format, setFormat] = useState<VideoSourceFormat>("auto");
  const [isWorking, setIsWorking] = useState(false);
  const [statusText, setStatusText] = useState<string | undefined>();
  const [statusIsError, setStatusIsError] = useState(false);

  async function runSourceAction(clearOnSuccess: boolean, action: () => Promise<{ categoryCount: number; itemCount: number }>) {
    setIsWorking(true);
    try {
      const result = await action();
      setStatusIsError(false);
      setStatusText(`连接成功：${result.categoryCount} 个分类，${result.itemCount} 条影片`);
      if (clearOnSuccess) {
        setName("");
        setHomepageURL("");
        setAPIURL("");
        setFormat("auto");
      }
    } catch (error) {
      setStatusIsError(true);
      setStatusText(error instanceof Error ? error.message : "连接失败");
    } finally {
      setIsWorking(false);
    }
  }

  return (
    <Modal title="视频源" onClose={onClose}>
      <div className="source-manager">
        <header className="modal-header">
          <div>
            <h2>视频源</h2>
            <p>添加、测试并切换你自己的视频采集接口</p>
          </div>
          <button type="button" className="icon-button" aria-label="关闭" onClick={onClose}>
            <X size={17} />
          </button>
        </header>

        <div className="source-manager-grid">
          <section className="source-panel">
            <h3><Server size={18} /> 已保存资源</h3>
            <div className="source-list">
              {library.videoSources.length === 0 ? (
                <div className="source-empty">
                  <PlusCircle size={26} />
                  <strong>还没有保存的视频源</strong>
                  <span>Xvideo 不内置任何数据源，请添加你自己的采集接口。</span>
                </div>
              ) : library.videoSources.map((source) => {
                const isActive = source.id === library.activeVideoSourceID;
                return (
                  <div className={`source-row ${isActive ? "is-active" : ""}`} key={source.id}>
                    {isActive ? <CheckCircle size={19} /> : <Server size={19} />}
                    <div>
                      <strong>{source.name}</strong>
                      <span>{source.apiURL}</span>
                    </div>
                    {isActive ? (
                      <em>当前</em>
                    ) : (
                      <button type="button" aria-label="启用" title="启用" onClick={() => void library.selectVideoSource(source)} disabled={library.isSwitchingVideoSource}>
                        <PlayCircle size={18} />
                      </button>
                    )}
                    {!source.isBuiltIn ? (
                      <button type="button" aria-label="删除" title="删除" onClick={() => void library.deleteVideoSource(source)}>
                        <Trash2 size={17} />
                      </button>
                    ) : null}
                  </div>
                );
              })}
            </div>
          </section>

          <section className="source-panel">
            <h3><PlusCircle size={18} /> 添加资源</h3>
            <label>
              名称
              <input value={name} onChange={(event) => setName(event.target.value)} placeholder="名称" />
            </label>
            <label>
              网站地址（可选）
              <input value={homepageURL} onChange={(event) => setHomepageURL(event.target.value)} placeholder="https://example.com" />
            </label>
            <label>
              采集接口 URL
              <input value={apiURL} onChange={(event) => setAPIURL(event.target.value)} placeholder="https://example.com/api.php/provide/vod/" />
            </label>
            <div className="segmented-control" role="radiogroup" aria-label="格式">
              {(["auto", "json", "xml"] as VideoSourceFormat[]).map((item) => (
                <button
                  type="button"
                  key={item}
                  className={format === item ? "is-active" : ""}
                  onClick={() => setFormat(item)}
                >
                  {item === "auto" ? "自动" : item.toUpperCase()}
                </button>
              ))}
            </div>
            {statusText ? <p className={`source-status ${statusIsError ? "is-error" : ""}`}>{statusText}</p> : null}
            <div className="source-actions">
              <button
                type="button"
                onClick={() => void runSourceAction(false, () => library.testVideoSource(name || "临时资源", homepageURL, apiURL, format))}
                disabled={isWorking || !apiURL.trim()}
              >
                测试
              </button>
              <button
                type="button"
                className="primary-button"
                onClick={() => void runSourceAction(true, () => library.addVideoSource(name, homepageURL, apiURL, format))}
                disabled={isWorking || !name.trim() || !apiURL.trim()}
              >
                测试并启用
              </button>
            </div>
          </section>
        </div>

        {library.isSwitchingVideoSource || isWorking ? (
          <p className="working-line"><span className="spinner" /> 正在验证或切换数据源</p>
        ) : null}
      </div>
    </Modal>
  );
}
