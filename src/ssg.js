import zigLanguageSupport from './highlight-zig.js'
import hljs from 'highlight.js/lib/common'
import frontmatter from 'frontmatter'
import { marked } from 'marked'

import * as fs from 'fs/promises'
import * as path from 'path'

hljs.registerLanguage('zig', zigLanguageSupport)

const walk = async function*(dir, recurse = true) {
  for (const file of await fs.readdir(dir, { withFileTypes: true })) {
    if (file.isDirectory() && recurse) {
      yield* walk(path.join(dir, file.name), recurse);
    } else if (!file.isDirectory()) {
      yield path.join(dir, file.name);
    }
  }
}

const defaultOptions = {
  recurse: true,
  verbose: false,
  fragments: {
    code: ({ text, lang: language }) => {
      return `<div class="code-block"><pre><code>${hljs.highlight(text, { language }).value}</code></pre></code-block>`
    },

    codespan: ({ text }) => {
      return `<code>${hljs.highlightAuto(text).value}</code>`
    },

    link: ({ text, href }) => {
      return `<a href=${href} target="_blank">${text}</a>`
    }
  }
}

export const genMarkdown = async function(pathname, options = defaultOptions) {
  const stat = await fs.stat(pathname)

  return (stat.isFile())
    ? genMarkdownFile(pathname, options)
    : genMarkdownDir(pathname, options)
}

export const genMarkdownDir = async function(dirname, options = defaultOptions) {
  console.assert((await fs.stat(dirname)).isDirectory(), `Provided path is not a directory: ${dirname}`)

  let results = []

  for await (const filename of walk(dirname, options.recurse)) {
    if (path.extname(filename) != '.md') continue

    results.push(genMarkdownFile(filename, options))
  }

  return results
}

export const genMarkdownFile = async function(filename, { fragments, verbose } = defaultOptions) {
  console.assert((await fs.stat(filename)).isFile(), `Provided path is not a file: ${filename}`)
  console.assert(path.extname(filename) == '.md', `Provided path does not have a markdown extension: ${filename}`)

  const route = filename.slice(filename.indexOf("/", 1)).replace('.md', '.html')
  const link = route.replace('.html', '')

  const file = Bun.file(filename)
  const { data: meta, content: markdown } = frontmatter(await file.text())

  marked.use({ renderer: fragments })
  const content = marked.parse(markdown)

  if (verbose) console.debug(`generated markdown asset ${route}`)

  return { route, link, content, meta }
}
