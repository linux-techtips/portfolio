import { genMarkdown } from './ssg' with { type: 'macro' }

import { raw } from 'hono/html'
import { Hono } from 'hono'

const about = await genMarkdown('public/about.md')
const posts = await genMarkdown('public/posts')

const app = new Hono()

const Index = ({ children }) => (
  <html lang="en">
    <head>
      <meta charset="UTF-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1.0" />
      <meta http-equiv="X-UA-Compatible" content="ie=edge" />
      <title>linux-techtips</title>
      <link rel="stylesheet" href="/public/styles/code-theme.css" />
      <link rel="stylesheet" href="/public/styles/reset.css" />
      <link rel="stylesheet" href="/public/styles/icons.css" />
      <link rel="stylesheet" href="/public/styles/index.css" />
    </head>
    <body>
      <script src="/public/scripts/htmx.min.js"></script>
      {children}
    </body>
  </html>
)

const Post = ({ meta, content }) => (
  <Index>
    <main id="main-content">
      <header>
        <h1>{meta.title}</h1>
        <span class="post-meta">
          <span class="post-date">{meta.date}</span>
          <span class="post-tags">
            {meta?.tags?.map(tag => <span class="post-tag"></span>)}
          </span>
        </span>
      </header>
      <section class="post-content">
        {raw(content)}
      </section>
    </main>
  </Index>
 )

const PostItem = ({ link, meta }) => (
  <article class="post-item">
    <header>
      <h2>{meta.title}</h2>
      <section class="post-item-meta">
        <span class="post-item-date">{meta.date}</span>
        <span class="post-item-tags">
          {meta?.tags?.map((tag) => <span class="post-item-tag">{tag}</span>)}
        </span>
      </section>
    </header>
    <p>{meta.description}</p>
    <footer>
      <a
        href={link}
        hx-get={link}
        hx-target="#main-content"
        hx-push-url="true"
        hx-swap="outerHTML"
      >Read More</a>
    </footer>
  </article>
)

for (const post of posts) {
  app.get(post.route, (c) => c.html(
    <main id="main-content">
      <Post {...post}/>
    </main>
  ))
}

app.get('/', (c) => c.html(
  <Index>
    <main id="main-content">
      <h1>Carter's Blog Posts</h1>
      <div id="blurb">
        <p>Read about me if you insist: <a
          href={about.link}
          hx-get={about.link}
          hx-target="#main-content"
          hx-push-url="true"
          hx-swap="outerHTML"
        >About Me</a></p>
      </div>
      <div id="posts">
        {posts.map((post) => PostItem(post))}
      </div>
    </main>
  </Index>
))

export default app
