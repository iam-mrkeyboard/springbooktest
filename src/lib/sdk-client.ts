import { SDKCoreJs } from 'studiocms:sdk';

/**
 * Get a single page by slug (no cache - instant updates)
 */
export async function getPage(slug: string) {
  try {
    const page = await SDKCoreJs.GET.page.bySlug(slug);
    return page;
  } catch (err) {
    console.error(`Failed to fetch page: ${slug}`, err);
    return null;
  }
}

/**
 * Get all pages in a folder by folder slug or ID (no cache - instant updates)
 */
export async function getFolderPages(folderSlug: string) {
  try {
    const pages = await SDKCoreJs.GET.folderPages(folderSlug);
    return pages;
  } catch (err) {
    console.error(`Failed to fetch folder pages: ${folderSlug}`, err);
    return [];
  }
}

/**
 * Get all pages (no cache - instant updates)
 */
export async function getAllPages() {
  try {
    const pages = await SDKCoreJs.GET.pages();
    return pages;
  } catch (err) {
    console.error('Failed to fetch all pages', err);
    return [];
  }
}

/**
 * Get folder tree structure (no cache - instant updates)
 */
export async function getFolderTree() {
  try {
    const tree = await SDKCoreJs.GET.folderTree();
    return tree;
  } catch (err) {
    console.error('Failed to fetch folder tree', err);
    return [];
  }
}

/**
 * Get site configuration (no cache - instant updates)
 */
export async function getSiteConfig() {
  try {
    const config = await SDKCoreJs.GET.siteConfig();
    return config;
  } catch (err) {
    console.error('Failed to fetch site config', err);
    return null;
  }
}
