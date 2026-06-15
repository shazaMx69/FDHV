// Role-based access control middleware
// Expects req.auth.user.id and a family_id param or body field.

import { supabaseAdmin } from '../config/supabaseClient.js'

export function requireFamilyRole (allowedRoles = []) {
  return async function (req, res, next) {
    try {
      const userId = req.auth?.user?.id
      const familyId = req.params.familyId || req.body.familyId || req.query.familyId

      if (!userId || !familyId) {
        return res.status(400).json({ message: 'Missing user or family context' })
      }

      const { data: membership, error } = await supabaseAdmin
        .from('family_members')
        .select('role')
        .eq('family_id', familyId)
        .eq('user_id', userId)
        .maybeSingle()

      if (error) {
        console.error('Role middleware membership error', error)
        return res.status(403).json({
          message: error.message || 'Could not verify family membership'
        })
      }

      if (!membership) {
        return res.status(403).json({
          message:
            'You are not a member of this family. Create a new family vault from Home or ask an admin to invite you.'
        })
      }

      if (allowedRoles.length > 0 && !allowedRoles.includes(membership.role)) {
        return res.status(403).json({
          message: `Your role (${membership.role}) cannot perform this action. Admin or Adult role is required.`
        })
      }

      req.auth.familyRole = membership.role
      next()
    } catch (err) {
      console.error('Role middleware error', err)
      return res.status(500).json({ message: 'Role validation failed' })
    }
  }
}
