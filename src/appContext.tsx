import { createContext, useContext } from "react";
import type { useDownloads } from "./hooks/useDownloads";
import type { useFavorites, useWatchProgress } from "./hooks/usePersistentStores";
import type { LibraryController } from "./hooks/useLibrary";

export interface AppContextValue {
  library: LibraryController;
  favorites: ReturnType<typeof useFavorites>;
  watchProgress: ReturnType<typeof useWatchProgress>;
  downloads: ReturnType<typeof useDownloads>;
}

export const AppContext = createContext<AppContextValue | undefined>(undefined);

export function useAppContext(): AppContextValue {
  const value = useContext(AppContext);
  if (!value) {
    throw new Error("AppContext is missing");
  }
  return value;
}
