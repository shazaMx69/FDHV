import dotenv from 'dotenv'
import path from 'path'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
const projectRootEnvPath = path.resolve(__dirname, '../../../.env')
const backendEnvPath = path.resolve(__dirname, '../../.env')

dotenv.config({ path: projectRootEnvPath })
dotenv.config({ path: backendEnvPath })
dotenv.config()

export const appConfig = {
  port: process.env.PORT || 4000,
  nodeEnv: process.env.NODE_ENV || 'development',
  jwtSecret: process.env.JWT_SECRET || 'change-this-secret-in-production',
  clientBaseUrl: process.env.CLIENT_BASE_URL || 'http://localhost:7357'
}

export const supabaseConfig = {
  url: process.env.SUPABASE_URL,
  anonKey: process.env.SUPABASE_ANON_KEY,
  serviceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY,
  postgresConnectionString: process.env.SUPABASE_POSTGRES_CONNECTION_STRING
}

export const emailConfig = {
  resendApiKey: process.env.RESEND_API_KEY,
  fromEmail: process.env.RESEND_FROM_EMAIL || 'Family Digital Heritage Vault <onboarding@resend.dev>'
}
