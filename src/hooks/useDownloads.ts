import { useCallback, useMemo, useState } from "react";
import type { DownloadTaskInfo, Episode } from "../types";
import { extensionFromURL, safeFileName } from "../services/format";
import { proxyURL } from "../services/api";

export function useDownloads() {
  const [tasks, setTasks] = useState<DownloadTaskInfo[]>([]);

  const updateTask = useCallback((id: string, update: (task: DownloadTaskInfo) => DownloadTaskInfo) => {
    setTasks((current) => current.map((task) => task.id === id ? update(task) : task));
  }, []);

  const download = useCallback(async (episode: Episode, movieName: string) => {
    const id = crypto.randomUUID();
    const title = `${movieName} ${episode.title}`.trim();
    const task: DownloadTaskInfo = {
      id,
      title,
      sourceURL: episode.url,
      progress: 0,
      status: "queued",
      statusLabel: "等待中"
    };
    setTasks((current) => [task, ...current]);

    try {
      updateTask(id, (current) => ({ ...current, status: "downloading", statusLabel: "下载中" }));
      const response = await fetch(proxyURL(episode.url));
      if (!response.ok) {
        throw new Error("资源请求失败");
      }

      const contentLength = Number(response.headers.get("content-length") ?? 0);
      const reader = response.body?.getReader();
      const chunks: ArrayBuffer[] = [];
      let received = 0;

      if (reader) {
        while (true) {
          const { done, value } = await reader.read();
          if (done) {
            break;
          }
          const copy = new Uint8Array(value.byteLength);
          copy.set(value);
          chunks.push(copy.buffer);
          received += value.length;
          if (contentLength > 0) {
            updateTask(id, (current) => ({ ...current, progress: received / contentLength }));
          }
        }
      } else {
        chunks.push(await response.arrayBuffer());
      }

      const blob = new Blob(chunks);
      const localURL = URL.createObjectURL(blob);
      const fileName = `${safeFileName(title)}.${extensionFromURL(episode.url)}`;
      const anchor = document.createElement("a");
      anchor.href = localURL;
      anchor.download = fileName;
      anchor.click();
      updateTask(id, (current) => ({
        ...current,
        progress: 1,
        status: "finished",
        statusLabel: "已完成",
        localURL
      }));
    } catch (error) {
      updateTask(id, (current) => ({
        ...current,
        status: "failed",
        statusLabel: `失败：${error instanceof Error ? error.message : "下载失败"}`
      }));
    }
  }, [updateTask]);

  return useMemo(() => ({ tasks, download }), [tasks, download]);
}
