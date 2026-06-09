import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type {
  CachedLibraryPage,
  ContentMode,
  LibraryCacheKey,
  LibraryPage,
  VideoSource,
  VideoSourceFormat,
  VodCategory,
  VodItem
} from "../types";
import {
  APIError,
  fetchCategories,
  fetchDetail,
  loadLibraryPage,
  loadPreviewPage,
  testSource
} from "../services/api";
import { nilIfBlank } from "../services/format";
import {
  cacheKeyString,
  loadLibraryCache,
  loadSources,
  saveLibraryCache,
  saveSources
} from "../services/storage";

const cacheLifetime = 60 * 60 * 1000;
const previewItemLimit = 10;

interface LoadOnlineListOptions {
  contentMode?: ContentMode;
  selectedCategory?: VodCategory;
  filterCategory?: VodCategory;
  searchText?: string;
  filterYear?: string;
  filterArea?: string;
}

export function useLibrary() {
  const sourceSnapshot = useMemo(() => loadSources(), []);
  const [categories, setCategories] = useState<VodCategory[]>([]);
  const [selectedCategory, setSelectedCategory] = useState<VodCategory | undefined>();
  const [movies, setMovies] = useState<VodItem[]>([]);
  const [selectedMovie, setSelectedMovie] = useState<VodItem | undefined>();
  const [detailMovie, setDetailMovie] = useState<VodItem | undefined>();
  const [searchText, setSearchText] = useState("");
  const [isLoadingList, setIsLoadingList] = useState(false);
  const [isRefreshingPreviewCache, setIsRefreshingPreviewCache] = useState(false);
  const [isLoadingDetail, setIsLoadingDetail] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | undefined>();
  const [page, setPage] = useState(1);
  const [pageCount, setPageCount] = useState(1);
  const [total, setTotal] = useState(0);
  const [filterCategory, setFilterCategory] = useState<VodCategory | undefined>();
  const [filterYear, setFilterYear] = useState("");
  const [filterArea, setFilterArea] = useState("");
  const [videoSources, setVideoSources] = useState<VideoSource[]>(sourceSnapshot.sources);
  const [activeVideoSourceID, setActiveVideoSourceID] = useState<string | undefined>(sourceSnapshot.activeSourceID);
  const [isSwitchingVideoSource, setIsSwitchingVideoSource] = useState(false);
  const [contentMode, setContentMode] = useState<ContentMode>("preview");

  const detailCache = useRef(new Map<number, VodItem>());
  const previewCache = useRef(new Map<string, CachedLibraryPage>());
  const onlinePageCache = useRef(new Map<string, LibraryPage>());
  const listRequestID = useRef(crypto.randomUUID());
  const detailRequestID = useRef(crypto.randomUUID());
  const sourceGeneration = useRef(crypto.randomUUID());
  const isRebuildingPreviewCache = useRef(false);
  const initialized = useRef(false);

  const activeVideoSource = useMemo(
    () => videoSources.find((source) => source.id === activeVideoSourceID),
    [activeVideoSourceID, videoSources]
  );

  const rootCategories = useMemo(() => categories
    .filter((category) => category.type_pid === 0 && isDisplayCategory(category))
    .sort((lhs, rhs) => lhs.type_id - rhs.type_id), [categories]);

  const childCategories = useMemo(() => {
    if (!selectedCategory) {
      return [];
    }
    const parentID = selectedCategory.type_pid === 0 ? selectedCategory.type_id : selectedCategory.type_pid;
    return categories
      .filter((category) => category.type_pid === parentID && isDisplayCategory(category))
      .sort((lhs, rhs) => lhs.type_id - rhs.type_id);
  }, [categories, selectedCategory]);

  const currentTitle = useMemo(() => {
    if (contentMode === "search" || searchText.trim()) {
      return "搜索结果";
    }
    return selectedCategory?.type_name ?? "最新更新";
  }, [contentMode, searchText, selectedCategory]);

  const filterCategories = useMemo(() => {
    if (!selectedCategory) {
      return rootCategories;
    }
    const parent = selectedCategory.type_pid === 0
      ? selectedCategory
      : categories.find((category) => category.type_id === selectedCategory.type_pid) ?? selectedCategory;
    return [parent, ...visibleChildren(parent, categories)];
  }, [categories, rootCategories, selectedCategory]);

  const resetLibraryStateForSourceChange = useCallback(() => {
    detailRequestID.current = crypto.randomUUID();
    listRequestID.current = crypto.randomUUID();
    setCategories([]);
    setSelectedCategory(undefined);
    setMovies([]);
    setSelectedMovie(undefined);
    setDetailMovie(undefined);
    setSearchText("");
    setIsLoadingList(false);
    setIsRefreshingPreviewCache(false);
    setIsLoadingDetail(false);
    setErrorMessage(undefined);
    setPage(1);
    setPageCount(1);
    setTotal(0);
    setFilterCategory(undefined);
    setFilterYear("");
    setFilterArea("");
    setContentMode("preview");
    detailCache.current = new Map();
    previewCache.current = new Map();
    onlinePageCache.current = new Map();
    isRebuildingPreviewCache.current = false;
  }, []);

  const persistVideoSources = useCallback((sources: VideoSource[], activeID?: string) => {
    saveSources(sources, activeID);
    const snapshot = loadSources();
    setVideoSources(snapshot.sources);
    setActiveVideoSourceID(snapshot.activeSourceID);
  }, []);

  const restoreLocalCache = useCallback((sourceID?: string) => {
    const snapshot = loadLibraryCache(sourceID);
    const loadedCategories = snapshot.categories as VodCategory[];
    if (loadedCategories.length) {
      setCategories(loadedCategories);
    }
    previewCache.current = new Map(snapshot.records
      .filter((record) => !record.key.keyword && record.key.page === 1)
      .map((record) => {
        const page: LibraryPage = {
          ...record.page.page,
          items: record.page.page.items.slice(0, previewItemLimit),
          remoteCategories: undefined
        };
        return [cacheKeyString(record.key), { page, loadedAt: record.page.loadedAt, isComplete: false }];
      }));
  }, []);

  const applyLibraryPage = useCallback(async (libraryPage: LibraryPage, reset: boolean) => {
    if (shouldUseRemoteCategories(libraryPage.remoteCategories, categories)) {
      setCategories(libraryPage.remoteCategories ?? []);
    }
    setPage(libraryPage.page);
    setPageCount(libraryPage.pageCount);
    setTotal(libraryPage.total);

    if (reset) {
      setMovies(libraryPage.items);
      setIsLoadingList(false);
      if (libraryPage.items[0]) {
        await selectMovieInternal(libraryPage.items[0], false);
      } else {
        setSelectedMovie(undefined);
        setDetailMovie(undefined);
      }
    } else {
      setMovies((current) => [...current, ...libraryPage.items]);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [categories]);

  const selectMovieInternal = useCallback(async (item: VodItem, preferProvidedItem = false) => {
    const cachedItem = preferProvidedItem ? item : item;
    setSelectedMovie(cachedItem);
    setDetailMovie(undefined);
    setIsLoadingDetail(true);
    setErrorMessage(undefined);
    const requestID = crypto.randomUUID();
    detailRequestID.current = requestID;

    if (!preferProvidedItem && detailCache.current.has(item.vod_id)) {
      setDetailMovie(detailCache.current.get(item.vod_id));
      setIsLoadingDetail(false);
      return;
    }

    try {
      const loaded = cachedItem.vod_play_url ? cachedItem : activeVideoSource ? await fetchDetail(activeVideoSource, item.vod_id) : cachedItem;
      if (detailRequestID.current !== requestID) {
        return;
      }
      detailCache.current.set(item.vod_id, loaded);
      setDetailMovie(loaded);
    } catch {
      if (detailRequestID.current === requestID) {
        setDetailMovie(cachedItem);
      }
    } finally {
      if (detailRequestID.current === requestID) {
        setIsLoadingDetail(false);
      }
    }
  }, [activeVideoSource]);

  const loadCategoriesIfNeeded = useCallback(async (force = false) => {
    if (!activeVideoSource || (!force && categories.length > 0)) {
      return;
    }
    try {
      const loaded = await fetchCategories(activeVideoSource);
      if (loaded.length) {
        setCategories(loaded);
      }
    } catch (error) {
      if (categories.length === 0) {
        setErrorMessage(error instanceof Error ? error.message : APIError.badResponse.message);
      }
    }
  }, [activeVideoSource, categories.length]);

  const persistPreviewCache = useCallback((sourceID?: string, nextCategories: VodCategory[] = categories) => {
    if (!sourceID) {
      return;
    }
    saveLibraryCache(sourceID, {
      categories: nextCategories,
      records: Array.from(previewCache.current.entries()).map(([keyString, page]) => ({
        key: parseCacheKeyString(keyString),
        page
      }))
    });
  }, [categories]);

  const rebuildPreviewCache = useCallback(async (applyVisiblePage: boolean) => {
    if (!activeVideoSource || isRebuildingPreviewCache.current) {
      return;
    }
    isRebuildingPreviewCache.current = true;
    setIsRefreshingPreviewCache(true);
    const generation = sourceGeneration.current;

    try {
      const loadedCategories = categories.length ? categories : await fetchCategories(activeVideoSource);
      if (generation !== sourceGeneration.current) {
        return;
      }
      if (loadedCategories.length) {
        setCategories(loadedCategories);
      }
      const targets = [undefined, ...displayCategories(loadedCategories).filter((category) => {
        return category.type_pid !== 0 || visibleChildren(category, loadedCategories).length === 0;
      })];

      for (const category of targets) {
        if (generation !== sourceGeneration.current) {
          return;
        }
        try {
          const loadedPage = await loadPreviewPage(activeVideoSource, category, loadedCategories, 1);
          const previewPage: LibraryPage = {
            ...loadedPage,
            items: loadedPage.items.slice(0, previewItemLimit)
          };
          const key = cacheKeyString(cacheKey(category, "", 1));
          previewCache.current.set(key, {
            page: previewPage,
            loadedAt: new Date().toISOString(),
            isComplete: false
          });
          buildRootPreviewPagesFromChildren(loadedCategories);

          if (applyVisiblePage && contentMode === "preview" && selectedCategory?.type_id === category?.type_id) {
            await applyLibraryPage(previewPage, true);
          }
        } catch {
          // Keep partial cache updates.
        }
      }
      buildRootPreviewPagesFromChildren(loadedCategories);
      persistPreviewCache(activeVideoSource.id, loadedCategories);
    } finally {
      if (generation === sourceGeneration.current) {
        isRebuildingPreviewCache.current = false;
        setIsRefreshingPreviewCache(false);
      }
    }
  }, [activeVideoSource, applyLibraryPage, categories, contentMode, persistPreviewCache, selectedCategory]);

  const loadInitialData = useCallback(async (force = false) => {
    if (!force && initialized.current) {
      return;
    }
    initialized.current = true;
    restoreLocalCache(activeVideoSourceID);
    if (!activeVideoSource) {
      resetLibraryStateForSourceChange();
      return;
    }

    await loadCategoriesIfNeeded(true);
    const cachedPage = previewCache.current.get(cacheKeyString(cacheKey(selectedCategory, "", 1)));
    if (cachedPage) {
      await applyLibraryPage(cachedPage.page, true);
    } else {
      setIsLoadingList(true);
      try {
        const loadedPage = await loadPreviewPage(activeVideoSource, selectedCategory, categories, 1);
        const previewPage = { ...loadedPage, items: loadedPage.items.slice(0, previewItemLimit) };
        previewCache.current.set(cacheKeyString(cacheKey(selectedCategory, "", 1)), {
          page: previewPage,
          loadedAt: new Date().toISOString(),
          isComplete: false
        });
        await applyLibraryPage(previewPage, true);
      } catch (error) {
        setErrorMessage(error instanceof Error ? error.message : APIError.badResponse.message);
      } finally {
        setIsLoadingList(false);
      }
    }

    const shouldRefresh = previewCache.current.size === 0 || Array.from(previewCache.current.values()).some((entry) => {
      return Date.now() - new Date(entry.loadedAt).getTime() >= cacheLifetime;
    });
    if (shouldRefresh) {
      void rebuildPreviewCache(false);
    }
  }, [
    activeVideoSource,
    activeVideoSourceID,
    applyLibraryPage,
    categories,
    loadCategoriesIfNeeded,
    rebuildPreviewCache,
    resetLibraryStateForSourceChange,
    restoreLocalCache,
    selectedCategory
  ]);

  useEffect(() => {
    void loadInitialData();
  }, [loadInitialData]);

  useEffect(() => {
    const interval = window.setInterval(() => {
      void rebuildPreviewCache(false);
    }, cacheLifetime);
    return () => window.clearInterval(interval);
  }, [rebuildPreviewCache]);

  const loadOnlineList = useCallback(async (reset: boolean, options: LoadOnlineListOptions = {}) => {
    if (!activeVideoSource) {
      setMovies([]);
      setErrorMessage(APIError.missingSource.message);
      return;
    }

    const modeSnapshot = options.contentMode ?? contentMode;
    const selectedCategorySnapshot = "selectedCategory" in options ? options.selectedCategory : selectedCategory;
    const filterCategorySnapshot = "filterCategory" in options ? options.filterCategory : filterCategory;
    const targetPage = reset ? 1 : page + 1;
    const categorySnapshot = modeSnapshot === "onlineCategory" ? filterCategorySnapshot : selectedCategorySnapshot;
    const keywordSnapshot = (options.searchText ?? searchText).trim();
    const yearSnapshot = modeSnapshot === "onlineCategory" ? options.filterYear ?? filterYear : "";
    const areaSnapshot = modeSnapshot === "onlineCategory" ? options.filterArea ?? filterArea : "";
    const requestID = crypto.randomUUID();
    listRequestID.current = requestID;
    setIsLoadingList(true);
    setErrorMessage(undefined);
    if (reset) {
      setMovies([]);
      setSelectedMovie(undefined);
      setDetailMovie(undefined);
    }

    try {
      const loadedPage = await loadLibraryPage(
        activeVideoSource,
        categorySnapshot,
        categories,
        keywordSnapshot,
        targetPage,
        yearSnapshot,
        areaSnapshot
      );
      if (listRequestID.current !== requestID) {
        return;
      }
      onlinePageCache.current.set(cacheKeyString(cacheKey(categorySnapshot, keywordSnapshot, targetPage)), loadedPage);
      await applyLibraryPage(loadedPage, reset);
    } catch (error) {
      if (listRequestID.current !== requestID) {
        return;
      }
      if (!reset && movies.length > 0) {
        setPageCount(page);
      } else {
        setErrorMessage(error instanceof Error ? error.message : APIError.badResponse.message);
      }
    } finally {
      if (listRequestID.current === requestID) {
        setIsLoadingList(false);
      }
    }
  }, [activeVideoSource, applyLibraryPage, categories, contentMode, filterArea, filterCategory, filterYear, movies.length, page, searchText, selectedCategory]);

  const refresh = useCallback(async () => {
    if (!activeVideoSource) {
      setErrorMessage(APIError.missingSource.message);
      return;
    }
    if (contentMode === "search" || searchText.trim()) {
      setContentMode("search");
      await loadOnlineList(true, { contentMode: "search", searchText });
      return;
    }
    if (contentMode === "onlineCategory") {
      await loadOnlineList(true, { contentMode: "onlineCategory", filterCategory, filterYear, filterArea });
      return;
    }
    await rebuildPreviewCache(true);
  }, [activeVideoSource, contentMode, loadOnlineList, rebuildPreviewCache, searchText]);

  const selectCategory = useCallback(async (category?: VodCategory) => {
    setSelectedCategory(category);
    setSearchText("");
    setFilterCategory(category);
    setFilterYear("");
    setFilterArea("");
    setContentMode("preview");
    setErrorMessage(undefined);
    listRequestID.current = crypto.randomUUID();

    if (!activeVideoSource) {
      setMovies([]);
      return;
    }

    const cachedPage = previewCache.current.get(cacheKeyString(cacheKey(category, "", 1)));
    if (cachedPage) {
      await applyLibraryPage(cachedPage.page, true);
      return;
    }

    setMovies([]);
    setIsLoadingList(true);
    try {
      const loaded = await loadPreviewPage(activeVideoSource, category, categories, 1);
      const previewPage = { ...loaded, items: loaded.items.slice(0, previewItemLimit) };
      previewCache.current.set(cacheKeyString(cacheKey(category, "", 1)), {
        page: previewPage,
        loadedAt: new Date().toISOString(),
        isComplete: false
      });
      await applyLibraryPage(previewPage, true);
      persistPreviewCache(activeVideoSource.id);
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : APIError.badResponse.message);
    } finally {
      setIsLoadingList(false);
    }
  }, [activeVideoSource, applyLibraryPage, categories, persistPreviewCache]);

  const openFilterSearch = useCallback(async (category?: VodCategory) => {
    setSelectedCategory(category);
    setFilterCategory(category);
    setFilterYear("");
    setFilterArea("");
    setSearchText("");
    setContentMode("onlineCategory");
    await loadOnlineList(true, {
      contentMode: "onlineCategory",
      selectedCategory: category,
      filterCategory: category,
      searchText: "",
      filterYear: "",
      filterArea: ""
    });
  }, [loadOnlineList]);

  const updateFilterCategory = useCallback(async (category?: VodCategory) => {
    setFilterCategory(category);
    setSelectedCategory(category);
    setContentMode("onlineCategory");
    await loadOnlineList(true, {
      contentMode: "onlineCategory",
      selectedCategory: category,
      filterCategory: category,
      searchText: "",
      filterYear,
      filterArea
    });
  }, [filterArea, filterYear, loadOnlineList]);

  const updateFilterYear = useCallback(async (year: string) => {
    setFilterYear(year);
    setContentMode("onlineCategory");
    await loadOnlineList(true, {
      contentMode: "onlineCategory",
      filterCategory,
      searchText: "",
      filterYear: year,
      filterArea
    });
  }, [filterArea, filterCategory, loadOnlineList]);

  const updateFilterArea = useCallback(async (area: string) => {
    setFilterArea(area);
    setContentMode("onlineCategory");
    await loadOnlineList(true, {
      contentMode: "onlineCategory",
      filterCategory,
      searchText: "",
      filterYear,
      filterArea: area
    });
  }, [filterCategory, filterYear, loadOnlineList]);

  const resetFilters = useCallback(async () => {
    setFilterYear("");
    setFilterArea("");
    setContentMode("onlineCategory");
    await loadOnlineList(true, {
      contentMode: "onlineCategory",
      filterCategory,
      searchText: "",
      filterYear: "",
      filterArea: ""
    });
  }, [filterCategory, loadOnlineList]);

  const search = useCallback(async (keyword = searchText) => {
    const trimmedKeyword = keyword.trim();
    setSelectedCategory(undefined);
    setFilterCategory(undefined);
    setFilterYear("");
    setFilterArea("");
    setSearchText(trimmedKeyword);
    setContentMode("search");
    await loadOnlineList(true, {
      contentMode: "search",
      selectedCategory: undefined,
      filterCategory: undefined,
      searchText: trimmedKeyword,
      filterYear: "",
      filterArea: ""
    });
  }, [loadOnlineList, searchText]);

  const loadNextPageIfNeeded = useCallback(async (item: VodItem) => {
    if (contentMode === "preview" || item.vod_id !== movies.at(-1)?.vod_id || page >= pageCount || isLoadingList) {
      return;
    }
    await loadOnlineList(false);
  }, [contentMode, isLoadingList, loadOnlineList, movies, page, pageCount]);

  const loadBrowsableGridPageIfNeeded = useCallback(async (item: VodItem) => {
    if (item.vod_id !== movies.at(-1)?.vod_id || page >= pageCount || isLoadingList) {
      return;
    }
    if (contentMode === "preview") {
      setContentMode("onlineCategory");
      setFilterCategory(selectedCategory);
      setFilterYear("");
      setFilterArea("");
    }
    await loadOnlineList(false);
  }, [contentMode, isLoadingList, loadOnlineList, movies, page, pageCount, selectedCategory]);

  const makeVideoSource = useCallback((name: string, homepageURLString: string, apiURLString: string, format: VideoSourceFormat): VideoSource => {
    const trimmedName = name.trim();
    if (!trimmedName) {
      throw new Error("请填写资源名称。");
    }
    const apiURL = validateHTTPURL(apiURLString, "采集接口 URL 格式不正确。");
    const homepageURL = nilIfBlank(homepageURLString)
      ? validateHTTPURL(homepageURLString, "网站地址格式不正确。")
      : undefined;
    return {
      id: crypto.randomUUID(),
      name: trimmedName,
      homepageURL,
      apiURL,
      format,
      isBuiltIn: false
    };
  }, []);

  const testVideoSource = useCallback(async (name: string, homepageURLString: string, apiURLString: string, format: VideoSourceFormat) => {
    return testSource(makeVideoSource(name || "临时资源", homepageURLString, apiURLString, format));
  }, [makeVideoSource]);

  const addVideoSource = useCallback(async (name: string, homepageURLString: string, apiURLString: string, format: VideoSourceFormat) => {
    const source = makeVideoSource(name, homepageURLString, apiURLString, format);
    const normalizedAPIURL = normalizedURLString(source.apiURL);
    if (videoSources.some((item) => normalizedURLString(item.apiURL) === normalizedAPIURL)) {
      throw new Error("这个采集接口已经存在。");
    }
    const result = await testSource(source);
    const nextSources = [...videoSources, source];
    setIsSwitchingVideoSource(true);
    persistVideoSources(nextSources, source.id);
    sourceGeneration.current = crypto.randomUUID();
    initialized.current = false;
    resetLibraryStateForSourceChange();
    setIsSwitchingVideoSource(false);
    return result;
  }, [makeVideoSource, persistVideoSources, resetLibraryStateForSourceChange, videoSources]);

  const selectVideoSource = useCallback(async (source: VideoSource): Promise<boolean> => {
    const storedSource = videoSources.find((item) => item.id === source.id);
    if (!storedSource) {
      setErrorMessage("无法启用该视频源：来源已不存在。");
      return false;
    }
    if (storedSource.id === activeVideoSourceID) {
      return true;
    }
    setIsSwitchingVideoSource(true);
    setErrorMessage(undefined);
    try {
      await testSource(storedSource);
    } catch (error) {
      setIsSwitchingVideoSource(false);
      setErrorMessage(`无法启用该视频源：${error instanceof Error ? error.message : "验证失败"}`);
      return false;
    }
    persistVideoSources(videoSources, storedSource.id);
    sourceGeneration.current = crypto.randomUUID();
    initialized.current = false;
    resetLibraryStateForSourceChange();
    setIsSwitchingVideoSource(false);
    return true;
  }, [activeVideoSourceID, persistVideoSources, resetLibraryStateForSourceChange, videoSources]);

  const deleteVideoSource = useCallback(async (source: VideoSource) => {
    if (source.isBuiltIn) {
      return;
    }
    const nextSources = videoSources.filter((item) => item.id !== source.id || item.isBuiltIn);
    const nextActiveID = source.id === activeVideoSourceID ? nextSources[0]?.id : activeVideoSourceID;
    persistVideoSources(nextSources, nextActiveID);
    if (source.id === activeVideoSourceID) {
      sourceGeneration.current = crypto.randomUUID();
      initialized.current = false;
      resetLibraryStateForSourceChange();
    }
  }, [activeVideoSourceID, persistVideoSources, resetLibraryStateForSourceChange, videoSources]);

  const selectMovie = useCallback(async (item: VodItem, preferProvidedItem = false) => {
    await selectMovieInternal(item, preferProvidedItem);
  }, [selectMovieInternal]);

  return {
    categories,
    selectedCategory,
    movies,
    selectedMovie,
    detailMovie,
    searchText,
    setSearchText,
    isLoadingList,
    isRefreshingPreviewCache,
    isLoadingDetail,
    errorMessage,
    setErrorMessage,
    page,
    pageCount,
    total,
    filterCategory,
    filterYear,
    filterArea,
    videoSources,
    activeVideoSourceID,
    activeVideoSource,
    isSwitchingVideoSource,
    contentMode,
    rootCategories,
    childCategories,
    currentTitle,
    filterCategories,
    filterYears: ["", "2026", "2025", "2024", "2023", "2022", "2021", "2020", "2019", "2018"],
    filterAreas: ["", "中国大陆", "香港", "台湾", "日本", "韩国", "美国", "英国", "泰国", "其他"],
    isShowingPreview: contentMode === "preview",
    isShowingSearchResults: contentMode === "search" || Boolean(searchText.trim()),
    canRequestMoreForCurrentSelection: !searchText.trim(),
    isShowingFilterSearch: contentMode === "onlineCategory",
    hasActiveVideoSource: Boolean(activeVideoSource),
    addVideoSource,
    selectVideoSource,
    deleteVideoSource,
    testVideoSource,
    refresh,
    selectCategory,
    openFilterSearch,
    updateFilterCategory,
    updateFilterYear,
    updateFilterArea,
    resetFilters,
    search,
    loadNextPageIfNeeded,
    loadBrowsableGridPageIfNeeded,
    selectMovie
  };

  function buildRootPreviewPagesFromChildren(nextCategories: VodCategory[]) {
    for (const rootCategory of nextCategories.filter((category) => category.type_pid === 0 && isDisplayCategory(category))) {
      const children = visibleChildren(rootCategory, nextCategories);
      if (!children.length) {
        continue;
      }
      const childPages = children
        .map((child) => previewCache.current.get(cacheKeyString(cacheKey(child, "", 1))))
        .filter(Boolean) as CachedLibraryPage[];
      if (!childPages.length) {
        continue;
      }
      const seen = new Set<number>();
      const items = childPages
        .flatMap((entry) => entry.page.items)
        .filter((item) => {
          if (seen.has(item.vod_id)) {
            return false;
          }
          seen.add(item.vod_id);
          return true;
        })
        .sort((lhs, rhs) => (rhs.vod_time ?? "").localeCompare(lhs.vod_time ?? ""));
      previewCache.current.set(cacheKeyString(cacheKey(rootCategory, "", 1)), {
        page: {
          items: items.slice(0, previewItemLimit),
          page: 1,
          pageCount: Math.max(1, ...childPages.map((entry) => entry.page.pageCount)),
          total: childPages.reduce((sum, entry) => sum + entry.page.total, 0),
          remoteCategories: nextCategories
        },
        loadedAt: childPages.map((entry) => entry.loadedAt).sort()[0] ?? new Date().toISOString(),
        isComplete: false
      });
    }
  }
}

export type LibraryController = ReturnType<typeof useLibrary>;

function cacheKey(category: VodCategory | undefined, keyword: string, page: number): LibraryCacheKey {
  return {
    categoryID: category?.type_id,
    keyword: keyword.trim(),
    page
  };
}

function parseCacheKeyString(keyString: string): LibraryCacheKey {
  const [categoryID, keyword, page] = keyString.split("::");
  return {
    categoryID: categoryID === "home" ? undefined : Number(categoryID),
    keyword: keyword ?? "",
    page: Number(page ?? 1)
  };
}

function validateHTTPURL(value: string, message: string): string {
  try {
    const url = new URL(value.trim());
    if (!["http:", "https:"].includes(url.protocol) || !url.hostname) {
      throw new Error(message);
    }
    return url.toString();
  } catch {
    throw new Error(message);
  }
}

function normalizedURLString(value: string): string {
  return value.trim().replace(/\/+$/g, "").toLowerCase();
}

function isDisplayCategory(category: VodCategory): boolean {
  return category.type_name !== "演员" && category.type_name !== "新闻资讯";
}

function visibleChildren(category: VodCategory, categories: VodCategory[]): VodCategory[] {
  return categories
    .filter((item) => item.type_pid === category.type_id && isDisplayCategory(item))
    .sort((lhs, rhs) => lhs.type_id - rhs.type_id);
}

function displayCategories(categories: VodCategory[]): VodCategory[] {
  const rootIDs = new Set(categories.filter((category) => category.type_pid === 0 && isDisplayCategory(category)).map((category) => category.type_id));
  return categories
    .filter((category) => isDisplayCategory(category) && (category.type_pid === 0 || rootIDs.has(category.type_pid)))
    .sort((lhs, rhs) => lhs.type_pid === rhs.type_pid ? lhs.type_id - rhs.type_id : lhs.type_pid - rhs.type_pid);
}

function shouldUseRemoteCategories(remoteCategories: VodCategory[] | undefined, currentCategories: VodCategory[]): boolean {
  if (!remoteCategories?.length) {
    return false;
  }
  return currentCategories.length === 0 || remoteCategories.some((category) => category.type_pid === 0);
}
