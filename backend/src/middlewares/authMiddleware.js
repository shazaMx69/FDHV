import jwt from 'jsonwebtoken'
import { appConfig } from '../config/env.js'
import { supabaseAdmin } from '../config/supabaseClient.js'

// This middleware expects:
// - A Supabase access token in Authorization: Bearer <token>
// - Or an internal JWT issued by this API

export async function authMiddleware (req, res, next) {
  try {
    const authHeader = req.headers.authorization || ''
    const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null

    if (!token) {
      return res.status(401).json({ message: 'Missing Authorization token' })
    }

    let supabaseUser
    let internalPayload

    // Try to verify as Supabase access token
    const { data: { user: authUser }, error: supabaseError } = await supabaseAdmin.auth.getUser(token)

    if (authUser && !supabaseError) {
      supabaseUser = authUser
    } else {
      // Fallback: verify as internal JWT
      try {
        internalPayload = jwt.verify(token, appConfig.jwtSecret)
        supabaseUser = internalPayload.supabaseUser
      } catch {
        return res.status(401).json({ message: 'Invalid or expired token' })
      }
    }

    if (!supabaseUser || !supabaseUser.id) {
      return res.status(401).json({ message: 'Invalid token - no user found' })
    }

    // Ensure local user record exists in users table
    const { data: existingUser, error } = await supabaseAdmin
      .from('users')
      .select('*')
      .eq('supabase_uid', supabaseUser.id)
      .single()

    if (error && error.code !== 'PGRST116') {
      console.error('Error fetching user', error)
      return res.status(500).json({ message: 'Failed to resolve user' })
    }

    let user = existingUser

    if (!existingUser) {
      const { data: inserted, error: insertError } = await supabaseAdmin
        .from('users')
        .insert({
          supabase_uid: supabaseUser.id,
          email: supabaseUser.email,
          display_name: supabaseUser.user_metadata?.full_name || supabaseUser.email
        })
        .select('*')
        .single()

      if (insertError) {
        console.error('Error creating user', insertError)
        return res.status(500).json({ message: 'Failed to create user' })
      }

      user = inserted
    }

    req.auth = {
      supabaseUser,
      user
    }

    next()
  } catch (err) {
    console.error('Auth middleware error', err)
    return res.status(500).json({ message: 'Authentication failed' })
  }
}

// Issues a short-lived internal JWT after Supabase login if the client prefers
export function issueInternalJwt (supabaseUser, user) {
  const payload = {
    sub: user.id,
    supabaseUid: supabaseUser.id,
    supabaseUser: {
      id: supabaseUser.id,
      email: supabaseUser.email
    }
  }

  return jwt.sign(payload, appConfig.jwtSecret, { expiresIn: '12h' })
}
