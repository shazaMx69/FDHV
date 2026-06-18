import { createApp } from './app.js'
import { appConfig, supabaseConfig } from './config/env.js'
import { initSchema } from './db/initSchema.js'

async function bootstrap () {
  if (supabaseConfig.postgresConnectionString) {
    try {
      await initSchema()
    } catch (err) {
      // Schema init failure is non-fatal on restarts — tables almost certainly
      // already exist. Log the error and continue; the API will work normally.
      // Only abort on first deploy where the connection string is wrong entirely.
      const isAuthFailure =
        err.code === 'XX000' ||
        (err.message || '').includes('authentication') ||
        (err.message || '').includes('ECIRCUITBREAKER') ||
        (err.message || '').includes('password')

      if (isAuthFailure) {
        console.error(
          '[server] Schema init skipped — DB auth failure (circuit breaker or wrong credentials).',
          'If this is the first deploy, check SUPABASE_POSTGRES_CONNECTION_STRING.',
          err.message
        )
        // Don't exit — the Supabase REST API (used by all routes) still works fine.
      } else {
        console.error('[server] Schema init error:', err.message)
      }
    }
  } else {
    console.warn('[server] SUPABASE_POSTGRES_CONNECTION_STRING not set — skipping schema init.')
  }

  const app = createApp()

  const host = '0.0.0.0'
  app.listen(appConfig.port, host, () => {
    console.log(`Family Digital Heritage Vault API listening on http://${host}:${appConfig.port}`)
  })
}

bootstrap()
