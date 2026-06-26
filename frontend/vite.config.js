import { defineConfig } from 'vite'
import uniPlugin from '@dcloudio/vite-plugin-uni'

const uni = typeof uniPlugin === 'function' ? uniPlugin : uniPlugin.default
const normalizePath = (path = '') => path.replace(/\\/g, '/')
const withUViewTheme = (source, filename = '') => {
  const normalized = normalizePath(filename)

  if (normalized.endsWith('/src/uni.scss')) {
    return source
  }

  return `@use "uview-plus/theme.scss" as *;\n${source}`
}

export default defineConfig({
  plugins: [uni()],
  css: {
    preprocessorOptions: {
      scss: {
        additionalData: withUViewTheme
      }
    }
  }
})
