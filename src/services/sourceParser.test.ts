import { describe, expect, it } from "vitest";
import { episodeCount, parseDownloads, parsePlaybackSources } from "./sourceParser";

describe("sourceParser", () => {
  it("parses grouped playback sources and episode URLs", () => {
    const sources = parsePlaybackSources({
      vod_id: 1,
      vod_name: "测试影片",
      vod_play_from: "M3U8$$$备用",
      vod_play_url: "第1集$https://example.com/1.m3u8#第2集$https://example.com/2.m3u8$$$HD$https://example.com/a.mp4"
    });

    expect(sources).toHaveLength(2);
    expect(sources[0]?.name).toBe("M3U8");
    expect(sources[0]?.episodes.map((episode) => episode.title)).toEqual(["第1集", "第2集"]);
    expect(sources[1]?.episodes[0]?.url).toBe("https://example.com/a.mp4");
  });

  it("parses downloads and counts the largest episode set", () => {
    const item = {
      vod_id: 1,
      vod_name: "测试影片",
      vod_play_url: "A$https://example.com/a.mp4#B$https://example.com/b.mp4",
      vod_down_url: "下载$https://example.com/file.mp4"
    };

    expect(episodeCount(item)).toBe(2);
    expect(parseDownloads(item)[0]?.title).toBe("下载");
  });
});
