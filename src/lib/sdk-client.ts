import { SDKCoreJs } from 'studiocms:sdk';

// Simple in-memory cache with TTL
const cache = new Map<string, { data: any; ts: number }>();
const TTL = 5 * 60 * 1000; // 5 minutes

function getCached<T>(key: string): T | null {
  const cached = cache.get(key);
  if (cached && Date.now() - cached.ts < TTL) {
    return cached.data as T;
  }
  return null;
}

function setCache(key: string, data: any): void {
  cache.set(key, { data, ts: Date.now() });
}

/**
 * Get a single page by slug
 */
export async function getPage(slug: string) {
  const cacheKey = `page:${slug}`;
  const cached = getCached(cacheKey);
  if (cached) return cached;

  try {
    const page = await SDKCoreJs.GET.page.bySlug(slug);
    setCache(cacheKey, page);
    return page;
  } catch (err) {
    console.error(`Failed to fetch page: ${slug}`, err);
    return null;
  }
}

/**
 * Get all pages in a folder by folder slug or ID
 */
export async function getFolderPages(folderSlug: string) {
  const cacheKey = `folder:${folderSlug}`;
  const cached = getCached(cacheKey);
  if (cached) return cached;

  try {
    const pages = await SDKCoreJs.GET.folderPages(folderSlug);
    setCache(cacheKey, pages);
    return pages;
  } catch (err) {
    console.error(`Failed to fetch folder pages: ${folderSlug}`, err);
    return [];
  }
}

/**
 * Get all pages
 */
export async function getAllPages() {
  const cacheKey = 'pages:all';
  const cached = getCached(cacheKey);
  if (cached) return cached;

  try {
    const pages = await SDKCoreJs.GET.pages();
    setCache(cacheKey, pages);
    return pages;
  } catch (err) {
    console.error('Failed to fetch all pages', err);
    return [];
  }
}

/**
 * Get folder tree structure
 */
export async function getFolderTree() {
  const cacheKey = 'folderTree';
  const cached = getCached(cacheKey);
  if (cached) return cached;

  try {
    const tree = await SDKCoreJs.GET.folderTree();
    setCache(cacheKey, tree);
    return tree;
  } catch (err) {
    console.error('Failed to fetch folder tree', err);
    return [];
  }
}

/**
 * Get site configuration
 */
export async function getSiteConfig() {
  const cacheKey = 'siteConfig';
  const cached = getCached(cacheKey);
  if (cached) return cached;

  try {
    const config = await SDKCoreJs.GET.siteConfig();
    setCache(cacheKey, config);
    return config;
  } catch (err) {
    console.error('Failed to fetch site config', err);
    return null;
  }
}

/**
 * Clear all cached data
 */
export function clearCache(): void {
  cache.clear();
}
