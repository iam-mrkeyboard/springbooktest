import { defineConfig } from 'astro/config';
import node from '@astrojs/node';
import studioCMS from 'studiocms';

export default defineConfig({
  site: 'https://test.springbokexpeditions.com/',
  output: 'server',
  adapter: node({ mode: 'standalone' }),
  integrations: [
    studioCMS(),
  ],
});