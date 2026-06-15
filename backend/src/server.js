import { createApp } from './app.js'
import { appConfig, supabaseConfig } from './config/env.js'
import { initSchema } from './db/initSchema.js'

async function bootstrap () {
  if (supabaseConfig.postgresConnectionString) {
    try {
      await initSchema()
    } catch (err) {
      console.error('Schema initialization failed; server will not start.', err)
      process.exit(1)
    }
  } else if (appConfig.nodeEnv === 'development') {
    console.warn(
      'SUPABASE_POSTGRES_CONNECTION_STRING not set; skipping automatic schema init.'
    )
  } else {
    console.error(
      'SUPABASE_POSTGRES_CONNECTION_STRING is required in production to initialize schema.'
    )
    process.exit(1)
  }

  const app = createApp()

  const host = '0.0.0.0'
  app.listen(appConfig.port, host, () => {
    console.log(
      `Family Digital Heritage Vault API listening on http://localhost:${appConfig.port}`
    )
  })
}

bootstrap()
