import { Readable } from "node:stream";
import type { ReadableStream as NodeReadableStream } from "node:stream/web";
import react from "@vitejs/plugin-react";
import { defineConfig, type Plugin, type ViteDevServer, type PreviewServer } from "vite";

const DEFAULT_HEADERS = {
  "user-agent":
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
  accept: "application/json,application/xml,text/xml,text/plain,video/*,*/*"
};

export default defineConfig({
  plugins: [react(), xvideoProxyPlugin()],
  build: {
    chunkSizeWarningLimit: 650,
    rollupOptions: {
      output: {
        manualChunks(id) {
          if (id.includes("node_modules/react") || id.includes("node_modules/react-dom")) {
            return "react";
          }
          if (id.includes("node_modules/hls.js")) {
            return "hls";
          }
          if (id.includes("node_modules/fast-xml-parser")) {
            return "xml";
          }
          if (id.includes("node_modules/lucide-react")) {
            return "icons";
          }
          return undefined;
        }
      }
    }
  },
  server: {
    port: 5173
  },
  preview: {
    port: 4173
  }
});

function xvideoProxyPlugin(): Plugin {
  return {
    name: "xvideo-local-proxy",
    configureServer(server) {
      mountProxy(server);
    },
    configurePreviewServer(server) {
      mountProxy(server);
    }
  };
}

function mountProxy(server: ViteDevServer | PreviewServer) {
  server.middlewares.use(async (req, res, next) => {
    if (!req.url?.startsWith("/api/")) {
      next();
      return;
    }

    try {
      const requestURL = new URL(req.url, "http://xvideo.local");

      if (requestURL.pathname === "/api/resolve") {
        await handleResolve(requestURL, res);
        return;
      }

      if (requestURL.pathname === "/api/proxy") {
        await handleProxy(requestURL, req.headers.range, res);
        return;
      }

      res.statusCode = 404;
      res.end("Not found");
    } catch (error) {
      res.statusCode = 502;
      res.setHeader("content-type", "application/json; charset=utf-8");
      res.end(JSON.stringify({ error: error instanceof Error ? error.message : "Proxy request failed" }));
    }
  });
}

async function handleProxy(requestURL: URL, range: string | undefined, res: NodeJS.WritableStream & {
  statusCode?: number;
  setHeader: (name: string, value: string | number | readonly string[]) => void;
  end: (chunk?: unknown) => void;
}) {
  const target = parseTargetURL(requestURL);
  const headers = new Headers(DEFAULT_HEADERS);
  headers.set("referer", target.origin);
  if (range) {
    headers.set("range", range);
  }

  const upstream = await fetch(target, { headers, redirect: "follow" });
  const contentType = upstream.headers.get("content-type") ?? "";
  const isM3U8 = contentType.includes("mpegurl") || target.pathname.toLowerCase().endsWith(".m3u8");

  res.statusCode = upstream.status;
  res.setHeader("access-control-allow-origin", "*");
  res.setHeader("cache-control", "no-store");

  for (const header of ["content-type", "content-length", "content-range", "accept-ranges"]) {
    const value = upstream.headers.get(header);
    if (value && !(isM3U8 && header === "content-length")) {
      res.setHeader(header, value);
    }
  }

  if (isM3U8) {
    const text = await upstream.text();
    res.setHeader("content-type", "application/vnd.apple.mpegurl; charset=utf-8");
    res.end(rewriteM3U8(text, target));
    return;
  }

  if (!upstream.body) {
    res.end();
    return;
  }

  Readable.fromWeb(upstream.body as unknown as NodeReadableStream<Uint8Array>).pipe(res);
}

async function handleResolve(requestURL: URL, res: NodeJS.WritableStream & {
  statusCode?: number;
  setHeader: (name: string, value: string | number | readonly string[]) => void;
  end: (chunk?: unknown) => void;
}) {
  const target = parseTargetURL(requestURL);
  const resolvedURL = await resolvePlaybackURL(target);
  res.statusCode = 200;
  res.setHeader("access-control-allow-origin", "*");
  res.setHeader("content-type", "application/json; charset=utf-8");
  res.end(JSON.stringify({ url: resolvedURL.toString() }));
}

function parseTargetURL(requestURL: URL): URL {
  const rawURL = requestURL.searchParams.get("url");
  if (!rawURL) {
    throw new Error("Missing url parameter");
  }

  const target = new URL(rawURL);
  if (!["http:", "https:"].includes(target.protocol)) {
    throw new Error("Only http and https URLs are supported");
  }
  return target;
}

function rewriteM3U8(manifest: string, baseURL: URL): string {
  return manifest
    .split(/\r?\n/)
    .map((line) => {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith("#")) {
        if (trimmed.startsWith("#EXT-X-KEY") && trimmed.includes("URI=\"")) {
          return trimmed.replace(/URI="([^"]+)"/, (_, uri: string) => {
            const keyURL = new URL(uri, baseURL).toString();
            return `URI="${proxyURL(keyURL)}"`;
          });
        }
        return line;
      }
      return proxyURL(new URL(trimmed, baseURL).toString());
    })
    .join("\n");
}

async function resolvePlaybackURL(url: URL, depth = 0): Promise<URL> {
  if (!shouldResolve(url) || depth >= 3) {
    return url;
  }

  const headers = new Headers(DEFAULT_HEADERS);
  headers.set("referer", url.origin);
  const response = await fetch(url, { headers, redirect: "follow" });
  const html = await response.text();
  const candidate = playableCandidate(html, url);
  if (!candidate) {
    return url;
  }

  if (shouldResolve(candidate) && candidate.toString() !== url.toString()) {
    return resolvePlaybackURL(candidate, depth + 1);
  }
  return candidate;
}

function shouldResolve(url: URL): boolean {
  const extension = url.pathname.split(".").pop()?.toLowerCase() ?? "";
  if (["m3u8", "mp4", "m4v", "mov", "webm"].includes(extension)) {
    return false;
  }
  return url.pathname.includes("/share/") || !extension || extension === url.pathname.toLowerCase();
}

function playableCandidate(html: string, baseURL: URL): URL | null {
  const normalizedHTML = html.replaceAll("\\/", "/");
  const directM3U8 = normalizedHTML.match(/https?:\/\/[^"'<>\s]+\.m3u8[^"'<>\s]*/i)?.[0];
  if (directM3U8) {
    return new URL(directM3U8);
  }

  const patterns = [
    /"url"\s*:\s*"([^"]+)"/gi,
    /url\s*:\s*['"]([^'"]+)['"]/gi,
    /(?:src|data-url)\s*=\s*['"]([^'"]+)['"]/gi
  ];

  for (const pattern of patterns) {
    for (const match of normalizedHTML.matchAll(pattern)) {
      const decoded = decodeCandidate(match[1] ?? "", normalizedHTML);
      try {
        const candidate = new URL(decoded, baseURL);
        if (isPlayable(candidate) || shouldResolve(candidate)) {
          return candidate;
        }
      } catch {
        // Try the next candidate.
      }
    }
  }
  return null;
}

function isPlayable(url: URL): boolean {
  const extension = url.pathname.split(".").pop()?.toLowerCase() ?? "";
  return ["m3u8", "mp4", "m4v", "mov", "webm"].includes(extension);
}

function decodeCandidate(raw: string, html: string): string {
  let value = raw.replaceAll("\\/", "/");
  try {
    value = JSON.parse(`"${value.replaceAll("\"", "\\\"")}"`);
  } catch {
    // Keep the raw value.
  }

  if (/"encrypt"\s*:\s*"?2"?/i.test(html)) {
    try {
      value = Buffer.from(value, "base64").toString("utf8");
    } catch {
      // Keep the raw value.
    }
  }

  try {
    return decodeURIComponent(value);
  } catch {
    return value;
  }
}

function proxyURL(url: string): string {
  return `/api/proxy?url=${encodeURIComponent(url)}`;
}
