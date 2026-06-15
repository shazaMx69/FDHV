import express from 'express'
import { supabaseAdmin } from '../config/supabaseClient.js'
import { requireFamilyRole } from '../middlewares/roleMiddleware.js'
import { createFamilyInvitation } from './invitations.js'

const router = express.Router()

// List families the current user belongs to
router.get('/', async (req, res) => {
  try {
    const userId = req.auth.user.id

    const { data: memberships, error } = await supabaseAdmin
      .from('family_members')
      .select('role, families (id, name, created_at)')
      .eq('user_id', userId)

    if (error) {
      console.error('List families error', error)
      return res.status(500).json({ message: error.message || 'Failed to list families' })
    }

    const families = (memberships || []).map((row) => ({
      id: row.families?.id,
      name: row.families?.name,
      created_at: row.families?.created_at,
      role: row.role
    }))

    res.json(families)
  } catch (err) {
    console.error('List families error', err)
    res.status(500).json({ message: 'Failed to list families' })
  }
})

// Create a new family vault; caller becomes ADMIN
router.post('/', async (req, res) => {
  try {
    const { name } = req.body
    const userId = req.auth.user.id

    if (!name || typeof name !== 'string' || !name.trim()) {
      return res.status(400).json({ message: 'Family name is required' })
    }

    const { data: family, error: familyError } = await supabaseAdmin
      .from('families')
      .insert({
        name: name.trim(),
        created_by: userId
      })
      .select('*')
      .single()

    if (familyError) {
      console.error('Create family error', familyError)
      return res.status(500).json({ message: familyError.message || 'Failed to create family' })
    }

    const { error: memberError } = await supabaseAdmin
      .from('family_members')
      .insert({
        family_id: family.id,
        user_id: userId,
        role: 'ADMIN'
      })

    if (memberError) {
      console.error('Create family membership error', memberError)
      return res.status(500).json({ message: memberError.message || 'Failed to assign admin role' })
    }

    res.status(201).json({
      ...family,
      role: 'ADMIN'
    })
  } catch (err) {
    console.error('Create family error', err)
    res.status(500).json({ message: 'Failed to create family' })
  }
})

// Invite a relative by email (ADMIN only)
router.post(
  '/:familyId/invite',
  requireFamilyRole(['ADMIN']),
  async (req, res) => {
    try {
      const { familyId } = req.params
      const { email, accessLevel, role } = req.body

      if (!email || typeof email !== 'string' || !email.trim()) {
        return res.status(400).json({ message: 'email is required' })
      }

      const { data: family, error: familyError } = await supabaseAdmin
        .from('families')
        .select('name')
        .eq('id', familyId)
        .single()

      if (familyError || !family) {
        return res.status(404).json({ message: 'Family not found' })
      }

      const { invite, inviteLink, emailResult } = await createFamilyInvitation({
        familyId,
        email,
        accessLevel: accessLevel || 'edit',
        role,
        invitedByUserId: req.auth.user.id,
        familyName: family.name,
        inviterName: req.auth.user.display_name || req.auth.user.email
      })

      res.status(201).json({
        invitationId: invite.id,
        email: invite.email,
        role: invite.role,
        accessLevel: invite.access_level,
        inviteLink,
        emailSent: emailResult?.sent ?? false
      })
    } catch (err) {
      console.error('Invite member error', err)
      res.status(500).json({ message: err.message || 'Failed to send invitation' })
    }
  }
)

export default router
