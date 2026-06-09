import { XMLParser } from "fast-xml-parser";
import type {
  LibraryPage,
  SourceTestResult,
  VideoSource,
  VideoSourceFormat,
  VodCategory,
  VodItem,
  VodListResponse
} from "../types";
import { nilIfBlank } from "./format";

export class APIError extends Error {
  static badResponse = new APIError("网站接口返回异常。");
  static emptyDetail = new APIError("没有找到影片详情。");
  static missingSource = new APIError("请先添加并启用视频源。");
}

const xmlParser = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: "@_",
  textNodeName: "#text",
  cdataPropName: "#text",
  trimValues: true,
  parseTagValue: false,
  parseAttributeValue: false
});

const categoryProbes = [
  [
    ["ac", "detail"],
    ["pg", "1"]
  ],
  [],
  [["ac", "list"]],
  [
    ["ac", "videolist"],
    ["pg", "1"]
  ]
] as const;

const testProbes = [
  [
    ["ac", "detail"],
    ["pg", "1"]
  ],
  [
    ["ac", "videolist"],
    ["pg", "1"]
  ],
  [],
  [["ac", "list"]]
] as const;

export async function fetchList(
  source: VideoSource,
  typeId?: number,
  page = 1,
  keyword?: string,
  year?: string,
  area?: string
): Promise<VodListResponse> {
  const queryItems: Array<[string, string]> = [["pg", String(page)]];
  if (typeId !== undefined) {
    queryItems.push(["t", String(typeId)]);
  }
  const trimmedKeyword = nilIfBlank(keyword);
  if (trimmedKeyword) {
    queryItems.push(["wd", trimmedKeyword]);
  }
  appendFilterItems(queryItems, year, area);
  return request(source, makeURL(source.apiURL, queryItems));
}

export async function fetchDetailedList(
  source: VideoSource,
  typeId?: number,
  page = 1,
  keyword?: string,
  year?: string,
  area?: string
): Promise<VodListResponse> {
  const queryItems: Array<[string, string]> = [
    ["ac", "detail"],
    ["pg", String(page)]
  ];
  if (typeId !== undefined) {
    queryItems.push(["t", String(typeId)]);
  }
  const trimmedKeyword = nilIfBlank(keyword);
  if (trimmedKeyword) {
    queryItems.push(["wd", trimmedKeyword]);
  }
  appendFilterItems(queryItems, year, area);
  return request(source, makeURL(source.apiURL, queryItems));
}

export async function search(source: VideoSource, keyword: string, page = 1): Promise<VodListResponse> {
  const searchURL = source.searchURL ?? source.apiURL;
  const action = source.searchURL ? "videolist" : "detail";
  const targetURL = makeURL(searchURL, [
    ["ac", action],
    ["wd", keyword],
    ["pg", String(page)]
  ]);
  const text = await requestText(targetURL);
  if (isUnsupportedSearchResponse(text)) {
    return { code: 1, page, pagecount: 1, total: 0, list: [] };
  }
  return decode(text, source.format);
}

export async function fetchCategories(source: VideoSource): Promise<VodCategory[]> {
  let sawReachableResponse = false;

  for (const items of categoryProbes) {
    try {
      const response = await request(source, makeURL(source.apiURL, [...items] as Array<[string, string]>));
      sawReachableResponse = true;
      if (response.class?.length) {
        return response.class;
      }
    } catch {
      // Try the next probe.
    }
  }

  if (sawReachableResponse) {
    return [];
  }
  throw APIError.badResponse;
}

export async function fetchDetail(source: VideoSource, id: number): Promise<VodItem> {
  const response = await request(source, makeURL(source.apiURL, [
    ["ac", "detail"],
    ["ids", String(id)]
  ]));
  const item = response.list[0];
  if (!item) {
    throw APIError.emptyDetail;
  }
  return item;
}

export async function testSource(source: VideoSource): Promise<SourceTestResult> {
  let listOnlyResult: SourceTestResult | undefined;

  for (const items of testProbes) {
    try {
      const response = await request(source, makeURL(source.apiURL, [...items] as Array<[string, string]>));
      const categoryCount = response.class?.length ?? 0;
      if (categoryCount > 0) {
        return { categoryCount, itemCount: response.list.length };
      }
      if (response.list.length > 0 && !listOnlyResult) {
        listOnlyResult = { categoryCount: 0, itemCount: response.list.length };
      }
    } catch {
      // Try the next probe.
    }
  }

  if (listOnlyResult) {
    return listOnlyResult;
  }
  throw APIError.badResponse;
}

export async function loadPreviewPage(
  source: VideoSource,
  selectedCategory: VodCategory | undefined,
  categories: VodCategory[],
  page: number
): Promise<LibraryPage> {
  const availableCategories = categories.length ? categories : await fetchCategories(source);
  const aggregateCategories = categoriesToLoad(selectedCategory, availableCategories);

  if (aggregateCategories.length > 1) {
    return loadAggregatePage(source, aggregateCategories.slice(1), page, true);
  }

  const detailed = await fetchDetailedList(source, selectedCategory?.type_id, page);
  if (detailed.list.length > 0) {
    return pageFromResponse(detailed, page, detailed.class?.length ? detailed.class : availableCategories);
  }

  const fallback = await fetchList(source, selectedCategory?.type_id, page);
  if (fallback.list.length > 0) {
    return pageFromResponse(fallback, page, fallback.class?.length ? fallback.class : availableCategories);
  }

  if (aggregateCategories.length > 1) {
    return loadAggregatePage(source, aggregateCategories.slice(1), page, true);
  }

  return pageFromResponse(fallback, page);
}

export async function loadLibraryPage(
  source: VideoSource,
  selectedCategory: VodCategory | undefined,
  categories: VodCategory[],
  keyword: string,
  page: number,
  year?: string,
  area?: string
): Promise<LibraryPage> {
  const trimmedKeyword = keyword.trim();
  const normalizedYear = nilIfBlank(year);
  const normalizedArea = nilIfBlank(area);

  if (trimmedKeyword) {
    return pageFromResponse(await search(source, trimmedKeyword, page), page);
  }

  const availableCategories = categories.length ? categories : await fetchCategories(source);
  const aggregateCategories = categoriesToLoad(selectedCategory, availableCategories);
  if (aggregateCategories.length > 1 && !normalizedYear && !normalizedArea) {
    return loadAggregatePage(source, aggregateCategories.slice(1), page, false);
  }

  const detailed = await fetchDetailedList(source, selectedCategory?.type_id, page, undefined, normalizedYear, normalizedArea);
  if (detailed.list.length > 0) {
    return pageFromResponse(detailed, page, detailed.class?.length ? detailed.class : availableCategories);
  }

  const fallback = await fetchList(source, selectedCategory?.type_id, page, undefined, normalizedYear, normalizedArea);
  if (fallback.list.length > 0) {
    return pageFromResponse(fallback, page);
  }

  if (aggregateCategories.length > 1 && !normalizedYear && !normalizedArea) {
    return loadAggregatePage(source, aggregateCategories.slice(1), page, false);
  }
  return pageFromResponse(fallback, page);
}

export function pageFromResponse(response: VodListResponse, fallbackPage: number, remoteCategories?: VodCategory[]): LibraryPage {
  return {
    items: response.list,
    page: response.page ?? fallbackPage,
    pageCount: response.pagecount ?? 1,
    total: response.total ?? response.list.length,
    remoteCategories: remoteCategories ?? response.class
  };
}

export function proxyURL(url: string): string {
  return `/api/proxy?url=${encodeURIComponent(url)}`;
}

export async function resolvePlaybackURL(url: string): Promise<string> {
  const response = await fetch(`/api/resolve?url=${encodeURIComponent(url)}`);
  if (!response.ok) {
    return url;
  }
  const payload = await response.json() as { url?: string };
  return payload.url ?? url;
}

async function loadAggregatePage(
  source: VideoSource,
  categories: VodCategory[],
  page: number,
  preview: boolean
): Promise<LibraryPage> {
  const responses = (await Promise.all(categories.map(async (category) => {
    try {
      const detailed = await fetchDetailedList(source, category.type_id, page);
      if (detailed.list.length > 0) {
        return detailed;
      }
      return fetchList(source, category.type_id, page);
    } catch {
      return undefined;
    }
  }))).filter(Boolean) as VodListResponse[];

  if (responses.length === 0) {
    throw APIError.badResponse;
  }

  const seen = new Set<number>();
  const items = responses
    .flatMap((response) => response.list)
    .filter((item) => {
      if (seen.has(item.vod_id)) {
        return false;
      }
      seen.add(item.vod_id);
      return true;
    })
    .sort((lhs, rhs) => (rhs.vod_time ?? "").localeCompare(lhs.vod_time ?? ""));

  return {
    items: items.slice(0, preview ? 60 : 60),
    page,
    pageCount: Math.max(1, ...responses.map((response) => response.pagecount ?? 1)),
    total: responses.reduce((sum, response) => sum + (response.total ?? response.list.length), 0)
  };
}

function categoriesToLoad(category: VodCategory | undefined, categories: VodCategory[]): VodCategory[] {
  if (!category) {
    return [];
  }

  const children = categories
    .filter((item) => item.type_pid === category.type_id)
    .sort((lhs, rhs) => lhs.type_id - rhs.type_id);

  return children.length ? [category, ...children] : [category];
}

async function request(source: VideoSource, url: string): Promise<VodListResponse> {
  return decode(await requestText(url), source.format);
}

async function requestText(url: string): Promise<string> {
  const response = await fetch(proxyURL(url));
  if (!response.ok) {
    throw APIError.badResponse;
  }
  return response.text();
}

export function decode(text: string, preferredFormat: VideoSourceFormat): VodListResponse {
  if (preferredFormat === "json") {
    return normalizeResponse(JSON.parse(text));
  }
  if (preferredFormat === "xml") {
    return parseXML(text);
  }
  return looksLikeXML(text) ? parseXML(text) : normalizeResponse(JSON.parse(text));
}

function looksLikeXML(text: string): boolean {
  return text.trimStart().startsWith("<");
}

function looksLikeJSON(text: string): boolean {
  const trimmed = text.trimStart();
  return trimmed.startsWith("{") || trimmed.startsWith("[");
}

function isUnsupportedSearchResponse(text: string): boolean {
  if (looksLikeXML(text) || looksLikeJSON(text)) {
    return false;
  }
  const trimmed = text.trim();
  const lowercased = trimmed.toLowerCase();
  return Boolean(trimmed) && (
    trimmed.includes("不支持搜索") ||
    trimmed.includes("暂不支持") ||
    lowercased.includes("search not supported") ||
    lowercased.includes("unsupported search")
  );
}

function makeURL(rawURL: string, items: Array<[string, string]>): string {
  const url = new URL(rawURL);
  for (const [name, value] of items) {
    url.searchParams.append(name, value);
  }
  return url.toString();
}

function appendFilterItems(items: Array<[string, string]>, year?: string, area?: string) {
  const trimmedYear = nilIfBlank(year);
  if (trimmedYear) {
    items.push(["year", trimmedYear]);
  }
  const trimmedArea = nilIfBlank(area);
  if (trimmedArea) {
    items.push(["area", trimmedArea]);
  }
}

function normalizeResponse(raw: unknown): VodListResponse {
  const source = asRecord(raw);
  const list = toArray(source.list).map(normalizeVodItem);
  const categories = toArray(source.class).map(normalizeCategory).filter((category) => category.type_id > 0);
  return {
    code: flexibleInt(source.code) ?? 0,
    msg: stringValue(source.msg),
    page: flexibleInt(source.page),
    pagecount: flexibleInt(source.pagecount),
    total: flexibleInt(source.total),
    list,
    class: categories.length ? categories : undefined
  };
}

function parseXML(text: string): VodListResponse {
  const parsed = xmlParser.parse(text) as unknown;
  const root = asRecord(parsed);
  const rss = asRecord(root.rss ?? root);
  const listNode = asRecord(rss.list ?? root.list ?? {});
  const videos = toArray(listNode.video ?? rss.video ?? root.video).map(normalizeXMLVideo);
  const rssClass = asRecord(rss.class);
  const listClass = asRecord(listNode.class);
  const rootClass = asRecord(root.class);
  const categories = vodCategories(
    toArray(rssClass.ty ?? listClass.ty ?? rootClass.ty ?? root.ty).map(normalizeXMLCategory)
  );

  return {
    code: 1,
    page: flexibleInt(listNode["@_page"] ?? listNode.page),
    pagecount: flexibleInt(listNode["@_pagecount"] ?? listNode.pagecount),
    total: flexibleInt(listNode["@_recordcount"] ?? listNode["@_total"] ?? listNode.total),
    list: videos,
    class: categories.length ? categories : undefined
  };
}

function normalizeVodItem(raw: unknown): VodItem {
  const source = asRecord(raw);
  return {
    vod_id: flexibleInt(source.vod_id) ?? 0,
    vod_name: stringValue(source.vod_name) ?? "未命名",
    type_id: flexibleInt(source.type_id),
    type_name: stringValue(source.type_name),
    vod_pic: stringValue(source.vod_pic),
    vod_pic_thumb: stringValue(source.vod_pic_thumb),
    vod_pic_slide: stringValue(source.vod_pic_slide),
    vod_pic_screenshot: stringValue(source.vod_pic_screenshot),
    vod_remarks: stringValue(source.vod_remarks),
    vod_area: stringValue(source.vod_area),
    vod_lang: stringValue(source.vod_lang),
    vod_year: stringValue(source.vod_year),
    vod_score: stringValue(source.vod_score),
    vod_douban_score: stringValue(source.vod_douban_score),
    vod_time: stringValue(source.vod_time),
    vod_class: stringValue(source.vod_class),
    vod_actor: stringValue(source.vod_actor),
    vod_director: stringValue(source.vod_director),
    vod_content: stringValue(source.vod_content),
    vod_blurb: stringValue(source.vod_blurb),
    vod_play_from: stringValue(source.vod_play_from),
    vod_play_url: stringValue(source.vod_play_url),
    vod_down_url: stringValue(source.vod_down_url)
  };
}

function normalizeXMLVideo(raw: unknown): VodItem {
  const source = asRecord(raw);
  const playNodes = toArray(asRecord(source.dl).dd ?? source.dd);
  const playNames: string[] = [];
  const playURLs: string[] = [];

  for (const node of playNodes) {
    const record = asRecord(node);
    const text = stringValue(record["#text"] ?? node);
    if (!text) {
      continue;
    }
    playNames.push(stringValue(record["@_flag"]) ?? `播放源 ${playNames.length + 1}`);
    playURLs.push(text);
  }

  return {
    vod_id: flexibleInt(source.id) ?? 0,
    vod_name: stringValue(source.name) ?? "未命名",
    type_id: flexibleInt(source.tid),
    type_name: stringValue(source.type),
    vod_pic: stringValue(source.pic),
    vod_remarks: stringValue(source.note ?? source.vod_note ?? source.state),
    vod_area: stringValue(source.area),
    vod_lang: stringValue(source.lang),
    vod_year: stringValue(source.year),
    vod_time: stringValue(source.last),
    vod_actor: stringValue(source.actor ?? source.vod_actor),
    vod_director: stringValue(source.director ?? source.vod_director),
    vod_content: stringValue(source.des ?? source.vod_des),
    vod_play_from: playNames.join("$$$") || undefined,
    vod_play_url: playURLs.join("$$$") || undefined
  };
}

function normalizeCategory(raw: unknown): VodCategory {
  const source = asRecord(raw);
  return {
    type_id: flexibleInt(source.type_id) ?? 0,
    type_pid: flexibleInt(source.type_pid) ?? 0,
    type_name: stringValue(source.type_name) ?? "未分类"
  };
}

interface XMLCategory {
  id: number;
  parentID?: number;
  name: string;
}

function normalizeXMLCategory(raw: unknown): XMLCategory {
  const source = asRecord(raw);
  return {
    id: flexibleInt(source["@_id"] ?? source["@_type_id"] ?? source.id) ?? 0,
    parentID: flexibleInt(source["@_pid"] ?? source["@_parentid"] ?? source["@_type_pid"]),
    name: stringValue(source["#text"] ?? raw) ?? "未分类"
  };
}

function vodCategories(xmlCategories: XMLCategory[]): VodCategory[] {
  const rootIDs = rootCategoryIDs(xmlCategories);
  const seen = new Set<number>();
  return xmlCategories.flatMap((category) => {
    if (category.id <= 0 || seen.has(category.id)) {
      return [];
    }
    seen.add(category.id);
    return [{
      type_id: category.id,
      type_pid: parentID(category, rootIDs),
      type_name: category.name
    }];
  });
}

interface RootCategoryIDs {
  movie?: number;
  drama?: number;
  variety?: number;
  anime?: number;
  sports?: number;
  shortDrama?: number;
}

function rootCategoryIDs(categories: XMLCategory[]): RootCategoryIDs {
  const ids = new Set(categories.map((category) => category.id));
  return {
    movie: rootID(categories, isMovieRootName) ?? (ids.has(1) ? 1 : undefined),
    drama: rootID(categories, isDramaRootName) ?? (ids.has(2) ? 2 : undefined),
    variety: rootID(categories, isVarietyRootName) ?? (ids.has(3) ? 3 : undefined),
    anime: rootID(categories, isAnimeRootName) ?? (ids.has(4) ? 4 : undefined),
    sports: rootID(categories, isSportsRootName) ?? (ids.has(36) ? 36 : undefined),
    shortDrama: rootID(categories, isShortDramaRootName)
  };
}

function rootID(categories: XMLCategory[], predicate: (name: string) => boolean): number | undefined {
  return categories.find((category) => predicate(normalizedCategoryName(category.name)))?.id;
}

function parentID(category: XMLCategory, rootIDs: RootCategoryIDs): number {
  const normalizedName = normalizedCategoryName(category.name);

  if (category.parentID !== undefined && category.parentID !== category.id) {
    return Math.max(category.parentID, 0);
  }
  if (
    isMovieRootName(normalizedName) ||
    isDramaRootName(normalizedName) ||
    isVarietyRootName(normalizedName) ||
    isAnimeRootName(normalizedName) ||
    isSportsRootName(normalizedName) ||
    isShortDramaRootName(normalizedName)
  ) {
    return 0;
  }
  if (isShortDramaChildName(normalizedName)) return rootIDs.shortDrama ?? 0;
  if (isSportsChildName(normalizedName)) return rootIDs.sports ?? 0;
  if (isVarietyChildName(normalizedName)) return rootIDs.variety ?? 0;
  if (isAnimeChildName(normalizedName)) return rootIDs.anime ?? 0;
  if (isDramaChildName(normalizedName)) return rootIDs.drama ?? 0;
  if (isMovieChildName(normalizedName)) return rootIDs.movie ?? 0;

  const fallback = fallbackParentIDs[category.id];
  return fallback ? mappedParentID(fallback, rootIDs) : 0;
}

function mappedParentID(parentID: number, rootIDs: RootCategoryIDs): number {
  if (parentID === 1) return rootIDs.movie ?? 0;
  if (parentID === 2) return rootIDs.drama ?? 0;
  if (parentID === 3) return rootIDs.variety ?? 0;
  if (parentID === 4) return rootIDs.anime ?? 0;
  if (parentID === 36) return rootIDs.sports ?? 0;
  return parentID;
}

function normalizedCategoryName(name: string): string {
  return name.replaceAll(" ", "").replaceAll("　", "").toLowerCase();
}

function isMovieRootName(name: string) {
  return ["电影", "电影片"].includes(name);
}
function isDramaRootName(name: string) {
  return ["电视剧", "连续剧", "剧集"].includes(name);
}
function isVarietyRootName(name: string) {
  return ["综艺", "综艺片"].includes(name);
}
function isAnimeRootName(name: string) {
  return ["动漫", "动漫片"].includes(name);
}
function isSportsRootName(name: string) {
  return name === "体育" || name === "体育赛事";
}
function isShortDramaRootName(name: string) {
  return ["短剧", "短剧片", "爽文短剧"].includes(name);
}
function isMovieChildName(name: string) {
  return name === "动画片" ||
    name.includes("电影") ||
    name.includes("片") ||
    name.includes("纪录") ||
    name.includes("记录") ||
    name.includes("伦理") ||
    name.includes("解说") ||
    name.includes("三级") ||
    name.includes("4k");
}
function isDramaChildName(name: string) {
  return name.includes("剧");
}
function isVarietyChildName(name: string) {
  return name.includes("综艺") || name.includes("演唱会");
}
function isAnimeChildName(name: string) {
  return name.includes("动漫");
}
function isSportsChildName(name: string) {
  return ["足球", "篮球", "网球", "斯诺克", "体育"].some((part) => name.includes(part));
}
function isShortDramaChildName(name: string) {
  return ["短剧", "爽剧", "恋爱", "仙侠", "穿越", "悬疑", "都市"].some((part) => name.includes(part));
}

const fallbackParentIDs: Record<number, number> = {
  1: 0,
  2: 0,
  3: 0,
  4: 0,
  36: 0,
  6: 1,
  7: 1,
  8: 1,
  9: 1,
  10: 1,
  11: 1,
  12: 1,
  20: 1,
  34: 1,
  35: 1,
  13: 2,
  14: 2,
  15: 2,
  16: 2,
  21: 2,
  22: 2,
  23: 2,
  24: 2,
  25: 3,
  26: 3,
  27: 3,
  28: 3,
  29: 4,
  30: 4,
  31: 4,
  32: 4,
  33: 4,
  37: 36,
  38: 36,
  39: 36,
  40: 36
};

function asRecord(value: unknown): Record<string, unknown> {
  return typeof value === "object" && value !== null ? value as Record<string, unknown> : {};
}

function toArray(value: unknown): unknown[] {
  if (value === undefined || value === null) {
    return [];
  }
  return Array.isArray(value) ? value : [value];
}

function flexibleInt(value: unknown): number | undefined {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (typeof value === "string") {
    const parsed = Number.parseInt(value.trim(), 10);
    return Number.isFinite(parsed) ? parsed : undefined;
  }
  return undefined;
}

function stringValue(value: unknown): string | undefined {
  if (typeof value === "string") {
    return nilIfBlank(value);
  }
  if (typeof value === "number") {
    return String(value);
  }
  if (Array.isArray(value)) {
    return nilIfBlank(value.flatMap((item) => stringValue(item) ?? []).join(""));
  }
  const source = asRecord(value);
  if ("#text" in source) {
    return stringValue(source["#text"]);
  }
  return undefined;
}
