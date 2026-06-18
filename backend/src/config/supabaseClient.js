import { createClient } from '@supabase/supabase-js'
import { supabaseConfig } from './env.js'

if (!supabaseConfig.url || !supabaseConfig.serviceRoleKey) {
  throw new Error('Supabase URL and service role key must be configured')
}

// Node.js < 22 has no native WebSocket — supply the 'ws' package as transport.
let websocketTransport
try {
  const { default: ws } = await import('ws')
  websocketTransport = ws
} catch {
  // Node.js 22+ has native WebSocket; 'ws' is optional.
}

const realtimeOptions = websocketTransport
  ? { realtime: { transport: websocketTransport } }
  : {}

// Service-role client for all backend operations
export const supabaseAdmin = createClient(
  supabaseConfig.url,
  supabaseConfig.serviceRoleKey,
  {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    },
    ...realtimeOptions
  }
)

// Public client if needed
export const supabasePublic = supabaseConfig.anonKey
  ? createClient(supabaseConfig.url, supabaseConfig.anonKey, realtimeOptions)
  : null
