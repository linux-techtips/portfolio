import { toSSG } from 'hono/bun'
import app from './index'

if (import.meta.main) {
  toSSG(app, { dir: './public' })
}
