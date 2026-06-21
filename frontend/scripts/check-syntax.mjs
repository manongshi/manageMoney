import { mkdtempSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, join } from 'node:path'
import { spawnSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'

const root = dirname(dirname(fileURLToPath(import.meta.url)))
const files = []
const vueFiles = []

function collect(dir) {
  for (const item of readdirSync(dir)) {
    const full = join(dir, item)
    const stat = statSync(full)
    if (stat.isDirectory()) {
      if (['node_modules', 'unpackage', 'dist'].includes(item)) continue
      collect(full)
      continue
    }
    if (full.endsWith('.js') || full.endsWith('.mjs')) {
      files.push(full)
    }
    if (full.endsWith('.vue')) {
      vueFiles.push(full)
    }
  }
}

collect(root)

for (const file of files) {
  const result = spawnSync(process.execPath, ['--check', file], { stdio: 'inherit' })
  if (result.status !== 0) {
    process.exit(result.status)
  }
}

const tempDir = mkdtempSync(join(tmpdir(), 'ai-account-book-syntax-'))
try {
  for (const file of vueFiles) {
    const content = readFileSync(file, 'utf8')
    const scripts = [...content.matchAll(/<script(?:\s+setup)?[^>]*>([\s\S]*?)<\/script>/g)]
    for (const [index, match] of scripts.entries()) {
      const tempFile = join(tempDir, `${index}-${file.replace(/[^a-zA-Z0-9]/g, '_')}.mjs`)
      writeFileSync(tempFile, match[1])
      const result = spawnSync(process.execPath, ['--check', tempFile], { stdio: 'inherit' })
      if (result.status !== 0) {
        process.exit(result.status)
      }
    }
  }
} finally {
  rmSync(tempDir, { recursive: true, force: true })
}

console.log(`checked ${files.length} JavaScript files and ${vueFiles.length} Vue files`)
