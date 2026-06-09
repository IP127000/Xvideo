import { describe, expect, it } from "vitest";
import { decode } from "./api";

describe("api decode", () => {
  it("normalizes JSON vod responses", () => {
    const response = decode(JSON.stringify({
      code: "1",
      page: "2",
      pagecount: "3",
      total: "10",
      list: [{ vod_id: "7", vod_name: "风暴", vod_year: 2026 }],
      class: [{ type_id: "1", type_pid: "0", type_name: "电影" }]
    }), "auto");

    expect(response.page).toBe(2);
    expect(response.list[0]?.vod_id).toBe(7);
    expect(response.list[0]?.vod_year).toBe("2026");
    expect(response.class?.[0]?.type_name).toBe("电影");
  });

  it("normalizes XML categories and playback fields", () => {
    const response = decode(`
      <rss>
        <class><ty id="1">电影</ty><ty id="6">动作片</ty></class>
        <list page="1" pagecount="2" recordcount="3">
          <video>
            <id>8</id><tid>6</tid><name>追光</name><type>动作片</type>
            <dl><dd flag="M3U8">第1集$https://example.com/1.m3u8</dd></dl>
          </video>
        </list>
      </rss>
    `, "auto");

    expect(response.pagecount).toBe(2);
    expect(response.list[0]?.vod_play_from).toBe("M3U8");
    expect(response.class?.find((category) => category.type_id === 6)?.type_pid).toBe(1);
  });

  it("normalizes XML CDATA text nodes", () => {
    const response = decode(`
      <rss>
        <list>
          <video>
            <id>9</id>
            <name><![CDATA[左撇子艾伦]]></name>
            <note><![CDATA[更新至第10集]]></note>
            <des><![CDATA[<p>简介</p>]]></des>
            <dl><dd flag="lzm3u8"><![CDATA[第01集$https://example.com/1.m3u8]]></dd></dl>
          </video>
        </list>
      </rss>
    `, "xml");

    expect(response.list[0]?.vod_name).toBe("左撇子艾伦");
    expect(response.list[0]?.vod_remarks).toBe("更新至第10集");
    expect(response.list[0]?.vod_content).toBe("<p>简介</p>");
    expect(response.list[0]?.vod_play_url).toBe("第01集$https://example.com/1.m3u8");
  });
});
