import { createClient } from '@supabase/supabase-js'
import { supabaseConfig } from './env.js'

if (!supabaseConfig.url || !supabaseConfig.serviceRoleKey) {
  throw new Error('Supabase URL and service role key must be configured')
}

// Service-role client for backend operations and schema management
export const supabaseAdmin = createClient(
  supabaseConfig.url,
  supabaseConfig.serviceRoleKey,
  {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    }
  }
)

// Public client if needed (not typically required in backend)
export const supabasePublic = supabaseConfig.anonKey
  ? createClient(supabaseConfig.url, supabaseConfig.anonKey)
  : null
