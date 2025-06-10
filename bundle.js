import { plugin } from 'bun'
import Prism from 'prismjs'

import loadLanguages from 'prismjs/components/'

class CodeBlockHighlighter {
  constructor() {
    this.code = ''
    this.lang = ''
  }

  element(elem) {
    this.lang = (elem.getAttribute('class') || '').match(/(?:language-|lang-)(\w+)/)[1]
    loadLanguages(this.lang)

    elem.setInnerContent('', { html: true })
    elem.onEndTag(tag => {
      tag.before(this.code, { html: true })
    })
  }

  text(content) {
    if (!content.text) return

    loadLanguages(['zig']);
    this.code = Prism.highlight(content.text, Prism.languages[this.lang], this.lang)
  }

  comments(comment) {
    comment.remove()
  }
}

const htmlRewriter = {
  name: 'Prism Rewriter',
  async setup({ onLoad }) {
    const rewriter = new HTMLRewriter()
      .on('code[class*=language-]', new CodeBlockHighlighter())

    onLoad({ filter: /\.html$/ }, async args => {
      const html = await Bun.file(args.path).text();
      return { contents: rewriter.transform(html), loader: 'html' }
    })
  },
}

const res = await Bun.build({
  entrypoints: ['./index.html', './writings/writing-engine-01.html'],
  outdir: './out',
  plugins: [htmlRewriter],
})
