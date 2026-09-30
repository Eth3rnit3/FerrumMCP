import { defineConfig } from 'vitepress'

const repo = 'https://github.com/Eth3rnit3/FerrumMCP'

// VitePress' default slugify turns `create_session` into `create-session`;
// keep underscores so tool anchors match the tool names (#create_session).
const slugify = (str: string) =>
  str
    .normalize('NFKD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/[\u0000-\u001f]/g, '')
    .replace(/[\s~`!@#$%^&*()\-+=[\]{}|\\;:"'“”‘’<>,.?/]+/g, '-')
    .replace(/-{2,}/g, '-')
    .replace(/^-+|-+$/g, '')
    .toLowerCase()

export default defineConfig({
  title: 'FerrumMCP',
  description: 'A Model Context Protocol server that gives AI assistants a real Chrome',
  base: '/FerrumMCP/',
  cleanUrls: true,
  lastUpdated: true,
  markdown: { anchor: { slugify } },

  themeConfig: {
    nav: [
      { text: 'Guide', link: '/guide/getting-started', activeMatch: '/guide/' },
      { text: 'API Reference', link: '/reference/', activeMatch: '/reference/' },
      { text: 'Deployment', link: '/deployment/docker', activeMatch: '/deployment/' },
      { text: 'Changelog', link: `${repo}/blob/main/CHANGELOG.md` }
    ],

    sidebar: [
      {
        text: 'Guide',
        items: [
          { text: 'Getting Started', link: '/guide/getting-started' },
          { text: 'Configuration', link: '/guide/configuration' },
          { text: 'Troubleshooting', link: '/guide/troubleshooting' }
        ]
      },
      {
        text: 'API Reference',
        items: [
          { text: 'Overview', link: '/reference/' },
          { text: 'Session Management', link: '/reference/sessions' },
          { text: 'Navigation', link: '/reference/navigation' },
          { text: 'Interaction', link: '/reference/interaction' },
          { text: 'Extraction', link: '/reference/extraction' },
          { text: 'Waiting', link: '/reference/waiting' },
          { text: 'Tabs & Viewport', link: '/reference/tabs' },
          { text: 'Advanced', link: '/reference/advanced' }
        ]
      },
      {
        text: 'Deployment',
        items: [
          { text: 'Docker', link: '/deployment/docker' },
          { text: 'BotBrowser in Docker', link: '/deployment/botbrowser-docker' },
          { text: 'Production', link: '/deployment/production' }
        ]
      }
    ],

    outline: [2, 3],
    search: { provider: 'local' },
    socialLinks: [{ icon: 'github', link: repo }],
    editLink: {
      pattern: `${repo}/edit/main/docs/:path`,
      text: 'Edit this page on GitHub'
    },
    footer: {
      message: 'Released under the MIT License.',
      copyright: 'Made by Eth3rnit3'
    }
  }
})
