import express from 'express'
import crypto from 'crypto'
import { supabaseAdmin } from '../config/supabaseClient.js'
import { sendFamilyInviteEmail } from '../services/emailService.js'
import { appConfig } from '../config/env.js'

const router = express.Router()

function mapAccessToRole (accessLevel, role) {
  if (accessLevel === 'view') return 'JUNIOR'
  if (role && ['ADMIN', 'ADULT', 'JUNIOR'].includes(role)) return role
  return 'ADULT'
}

// Accept invitation (user must be authenticated)
router.post('/accept', async (req, res) => {
  try {
    const { token } = req.body
    const userId = req.auth.user.id
    const userEmail = req.auth.user.email?.toLowerCase()

    if (!token) {
      return res.status(400).json({ message: 'Invitation token is required' })
    }

    const { data: invite, error } = await supabaseAdmin
      .from('family_invitations')
      .select('*, families (id, name)')
      .eq('token', token)
      .eq('status', 'pending')
      .single()

    if (error || !invite) {
      return res.status(404).json({ message: 'Invitation not found or already used' })
    }

    if (new Date(invite.expires_at) < new Date()) {
      await supabaseAdmin
        .from('family_invitations')
        .update({ status: 'expired' })
        .eq('id', invite.id)
      return res.status(410).json({ message: 'Invitation has expired' })
    }

    if (userEmail && invite.email.toLowerCase() !== userEmail) {
      return res.status(403).json({
        message: 'This invitation was sent to a different email address. Sign in with the invited email.'
      })
    }

    const { data: existing } = await supabaseAdmin
      .from('family_members')
      .select('id')
      .eq('family_id', invite.family_id)
      .eq('user_id', userId)
      .maybeSingle()

    if (!existing) {
      const { error: memberError } = await supabaseAdmin
        .from('family_members')
        .insert({
          family_id: invite.family_id,
          user_id: userId,
          role: invite.role,
          invited_email: invite.email
        })

      if (memberError) {
        console.error('Accept invite membership error', memberError)
        return res.status(500).json({ message: memberError.message || 'Failed to join family' })
      }
    }

    await supabaseAdmin
      .from('family_invitations')
      .update({ status: 'accepted' })
      .eq('id', invite.id)

    res.json({
      familyId: invite.family_id,
      familyName: invite.families?.name,
      role: invite.role,
      accessLevel: invite.access_level,
      message: 'You have joined the family vault'
    })
  } catch (err) {
    console.error('Accept invitation error', err)
    res.status(500).json({ message: 'Failed to accept invitation' })
  }
})

// Preview invitation (public info)
router.get('/:token', async (req, res) => {
  try {
    const { token } = req.params
    const { data: invite, error } = await supabaseAdmin
      .from('family_invitations')
      .select('email, role, access_level, status, expires_at, families (name)')
      .eq('token', token)
      .single()

    if (error || !invite) {
      return res.status(404).json({ message: 'Invitation not found' })
    }

    res.json({
      email: invite.email,
      familyName: invite.families?.name,
      role: invite.role,
      accessLevel: invite.access_level,
      status: invite.status,
      expiresAt: invite.expires_at
    })
  } catch (err) {
    console.error('Preview invitation error', err)
    res.status(500).json({ message: 'Failed to load invitation' })
  }
})

export { mapAccessToRole, router as invitationsRouter }

export async function createFamilyInvitation ({
  familyId,
  email,
  accessLevel,
  role,
  invitedByUserId,
  familyName,
  inviterName
}) {
  const token = crypto.randomBytes(32).toString('hex')
  const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString()
  const mappedRole = mapAccessToRole(accessLevel, role)

  const { data: invite, error } = await supabaseAdmin
    .from('family_invitations')
    .insert({
      family_id: familyId,
      email: email.toLowerCase().trim(),
      role: mappedRole,
      access_level: accessLevel === 'view' ? 'view' : 'edit',
      token,
      status: 'pending',
      invited_by: invitedByUserId,
      expires_at: expiresAt
    })
    .select('*')
    .single()

  if (error) {
    throw error
  }

  const inviteLink = `${appConfig.clientBaseUrl}/?invite=${token}`
  const emailResult = await sendFamilyInviteEmail({
    toEmail: email,
    familyName,
    inviterName,
    inviteLink,
    role: mappedRole
  })

  return { invite, inviteLink, emailResult }
}
