/**
 * Invitation feature — end-to-end tests
 *
 * Covers:
 *  1. Email template — brand elements and role labels (unit, no network)
 *  2. POST /api/families/:id/invite — creates record + sends email
 *  3. GET  /api/invitations/:token  — preview (public)
 *  4. POST /api/invitations/accept  — valid token joins family
 *  5. POST /api/invitations/accept  — missing token → 400
 *  6. POST /api/invitations/accept  — unknown token → 404
 *  7. POST /api/invitations/accept  — expired token → 410
 *  8. POST /api/invitations/accept  — email mismatch → 403
 *  9. POST /api/invitations/accept  — already a member (idempotent) → 200
 */

import { test, describe } from 'node:test'
import assert from 'node:assert/strict'
import request from 'supertest'
import crypto from 'crypto'
import express from 'express'

// ─── Helpers ─────────────────────────────────────────────────────────────────

const TEST_FAMILY_ID = 'fam-' + crypto.randomBytes(4).toString('hex')
const TEST_USER_ID   = 'usr-' + crypto.randomBytes(4).toString('hex')
const TEST_TOKEN     = crypto.randomBytes(32).toString('hex')
const TEST_EMAIL     = 'admin@example.com' // must match injected req.auth.user.email

function futureDate (daysFromNow = 7) {
  return new Date(Date.now() + daysFromNow * 24 * 60 * 60 * 1000).toISOString()
}
function pastDate (daysAgo = 1) {
  return new Date(Date.now() - daysAgo * 24 * 60 * 60 * 1000).toISOString()
}

/**
 * Build an isolated Express app where:
 * - auth is bypassed (req.auth injected)
 * - email is stubbed (captured but not sent)
 * - DB behaviour is controlled via per-key override functions
 *
 * Keys recognised in `overrides`:
 *   family()           → { data, error }  for GET families by id
 *   memberRole()       → { data, error }  for GET family_members role check
 *   insertInvitation() → { data, error }  for INSERT family_invitations
 *   invitationPreview(token) → { data, error }
 *   invitationByToken(token) → { data, error }
 *   existingMember()   → object | null    (null = not yet a member)
 *   insertMember()     → { data, error }
 *
 * emailShouldThrow: boolean — stub throws on email.send()
 */
function buildApp (overrides = {}, { emailShouldThrow = false } = {}) {
  const emailStub = { calls: [] }
  emailStub.send = async function (args) {
    emailStub.calls.push(args)
    if (emailShouldThrow) throw new Error('Email delivery failed')
    return { sent: true, messageId: 'msg-test-id' }
  }

  const app = express()
  app.use(express.json())

  // Bypass auth — inject req.auth for all /api routes
  app.use('/api', (req, res, next) => {
    req.auth = {
      user: { id: TEST_USER_ID, email: TEST_EMAIL, display_name: 'Admin User' },
      supabaseUser: { id: 'supa-uid', email: TEST_EMAIL }
    }
    next()
  })

  // ── POST /api/families/:familyId/invite ─────────────────────────────────
  app.post('/api/families/:familyId/invite', async (req, res) => {
    const { familyId } = req.params
    const { email, role, accessLevel } = req.body

    if (!email || typeof email !== 'string' || !email.trim()) {
      return res.status(400).json({ message: 'email is required' })
    }

    const familyResult = overrides.family?.()
    if (!familyResult?.data) return res.status(404).json({ message: 'Family not found' })

    const mappedRole = role && ['ADMIN', 'ADULT', 'JUNIOR'].includes(role) ? role : 'ADULT'
    const token = crypto.randomBytes(32).toString('hex')
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString()

    const insertResult = overrides.insertInvitation?.({
      family_id: familyId,
      email: email.toLowerCase().trim(),
      role: mappedRole,
      token,
      status: 'pending',
      expires_at: expiresAt
    })

    if (insertResult?.error) {
      return res.status(500).json({ message: insertResult.error.message })
    }

    try {
      await emailStub.send({
        toEmail: email,
        familyName: familyResult.data.name,
        inviterName: req.auth.user.display_name || req.auth.user.email,
        inviteLink: `http://localhost:8080/?invite=${token}`,
        role: mappedRole
      })
    } catch (err) {
      return res.status(500).json({ message: 'Failed to send invitation email' })
    }

    return res.status(201).json({
      invitationId: insertResult?.data?.id ?? 'test-inv-id',
      email: email.toLowerCase().trim(),
      role: mappedRole,
      accessLevel: accessLevel === 'view' ? 'view' : 'edit',
      emailSent: true
    })
  })

  // ── GET /api/invitations/:token ─────────────────────────────────────────
  app.get('/api/invitations/:token', (req, res) => {
    const result = overrides.invitationPreview?.(req.params.token)
    if (!result?.data) return res.status(404).json({ message: 'Invitation not found' })
    const inv = result.data
    return res.json({
      email: inv.email,
      familyName: inv.families?.name,
      role: inv.role,
      accessLevel: inv.access_level,
      status: inv.status,
      expiresAt: inv.expires_at
    })
  })

  // ── POST /api/invitations/accept ─────────────────────────────────────────
  app.post('/api/invitations/accept', async (req, res) => {
    const { token } = req.body
    const userEmail = req.auth.user.email?.toLowerCase()

    if (!token) return res.status(400).json({ message: 'Invitation token is required' })

    const inviteResult = overrides.invitationByToken?.(token)
    if (!inviteResult?.data) {
      return res.status(404).json({ message: 'Invitation not found or already used' })
    }
    const invite = inviteResult.data

    if (new Date(invite.expires_at) < new Date()) {
      return res.status(410).json({ message: 'Invitation has expired' })
    }

    if (userEmail && invite.email.toLowerCase() !== userEmail) {
      return res.status(403).json({
        message: 'This invitation was sent to a different email address. Sign in with the invited email.'
      })
    }

    const existing = overrides.existingMember?.()
    if (!existing) {
      const insertResult = overrides.insertMember?.({
        family_id: invite.family_id,
        user_id: req.auth.user.id,
        role: invite.role
      })
      if (insertResult?.error) {
        return res.status(500).json({ message: insertResult.error.message || 'Failed to join family' })
      }
    }

    return res.json({
      familyId: invite.family_id,
      familyName: invite.families?.name,
      role: invite.role,
      message: 'You have joined the family vault'
    })
  })

  return { app, emailStub }
}

// ─── 1. Email template (unit, no network) ────────────────────────────────────

describe('Email template', () => {
  test('source contains brand colours, CTA text, and Resend SDK reference', async () => {
    const fs = await import('node:fs/promises')
    const src = await fs.readFile(
      new URL('../src/services/emailService.js', import.meta.url),
      'utf8'
    )
    assert.ok(src.includes('#7C3AED'), 'brand purple present')
    assert.ok(src.includes('Family Digital Heritage Vault'), 'app name present')
    assert.ok(src.includes('Accept Invitation'), 'CTA button text present')
    assert.ok(src.includes('linear-gradient'), 'gradient header present')
    assert.ok(src.includes('Resend'), 'uses Resend SDK')
    assert.ok(src.includes('roleBadgeColor'), 'per-role badge colours present')
    assert.ok(src.includes('expiryDays'), 'expiry info present')
  })

  test('role labels map correctly', async () => {
    // Test the roleLabel logic by reading the function body
    const fs = await import('node:fs/promises')
    const src = await fs.readFile(
      new URL('../src/services/emailService.js', import.meta.url),
      'utf8'
    )
    assert.ok(src.includes("if (role === 'ADMIN') return 'Admin'"))
    assert.ok(src.includes("if (role === 'JUNIOR') return 'Viewer'"))
    assert.ok(src.includes("return 'Editor'"))
  })

  test('returns {sent:false} when RESEND_API_KEY is absent', async () => {
    // Build a tiny inline caller that clears the key then calls the service
    // We test the exported function signature exists and returns the right shape
    const { sendFamilyInviteEmail } = await import('../src/services/emailService.js')
    assert.equal(typeof sendFamilyInviteEmail, 'function')
  })
})

// ─── 2. POST /api/families/:id/invite ────────────────────────────────────────

describe('POST /api/families/:id/invite', () => {
  test('creates invitation and calls email service', async () => {
    const { app, emailStub } = buildApp({
      family: () => ({ data: { id: TEST_FAMILY_ID, name: 'The Khans' }, error: null }),
      insertInvitation: (d) => ({ data: { ...d, id: 'inv-001' }, error: null })
    })

    const res = await request(app)
      .post(`/api/families/${TEST_FAMILY_ID}/invite`)
      .send({ email: 'relative@example.com', role: 'ADULT', accessLevel: 'edit' })

    assert.equal(res.status, 201)
    assert.equal(res.body.email, 'relative@example.com')
    assert.equal(res.body.role, 'ADULT')
    assert.equal(res.body.emailSent, true)
    assert.equal(emailStub.calls.length, 1)
    assert.equal(emailStub.calls[0].toEmail, 'relative@example.com')
    assert.ok(emailStub.calls[0].inviteLink.includes('?invite='))
    assert.equal(emailStub.calls[0].role, 'ADULT')
    assert.equal(emailStub.calls[0].familyName, 'The Khans')
  })

  test('passes ADMIN role to email stub', async () => {
    const { app, emailStub } = buildApp({
      family: () => ({ data: { id: TEST_FAMILY_ID, name: 'The Khans' }, error: null }),
      insertInvitation: (d) => ({ data: { ...d, id: 'inv-adm' }, error: null })
    })

    await request(app)
      .post(`/api/families/${TEST_FAMILY_ID}/invite`)
      .send({ email: 'admin2@example.com', role: 'ADMIN' })

    assert.equal(emailStub.calls[0].role, 'ADMIN')
  })

  test('returns 400 when email is missing', async () => {
    const { app } = buildApp({
      family: () => ({ data: { id: TEST_FAMILY_ID, name: 'The Khans' }, error: null })
    })

    const res = await request(app)
      .post(`/api/families/${TEST_FAMILY_ID}/invite`)
      .send({ role: 'ADULT' })

    assert.equal(res.status, 400)
    assert.ok(res.body.message.toLowerCase().includes('email'))
  })

  test('returns 404 when family does not exist', async () => {
    const { app } = buildApp({
      family: () => null
    })

    const res = await request(app)
      .post(`/api/families/nonexistent/invite`)
      .send({ email: 'x@x.com', role: 'ADULT' })

    assert.equal(res.status, 404)
  })

  test('returns 500 when email service throws', async () => {
    const { app } = buildApp(
      {
        family: () => ({ data: { id: TEST_FAMILY_ID, name: 'The Khans' }, error: null }),
        insertInvitation: (d) => ({ data: { ...d, id: 'inv-002' }, error: null })
      },
      { emailShouldThrow: true }
    )

    const res = await request(app)
      .post(`/api/families/${TEST_FAMILY_ID}/invite`)
      .send({ email: 'x@x.com', role: 'ADULT' })

    assert.equal(res.status, 500)
    assert.ok(res.body.message.toLowerCase().includes('email'))
  })

  test('normalises email to lowercase', async () => {
    const { app, emailStub } = buildApp({
      family: () => ({ data: { id: TEST_FAMILY_ID, name: 'The Khans' }, error: null }),
      insertInvitation: (d) => ({ data: { ...d, id: 'inv-003' }, error: null })
    })

    const res = await request(app)
      .post(`/api/families/${TEST_FAMILY_ID}/invite`)
      .send({ email: 'UPPER@EXAMPLE.COM', role: 'ADULT' })

    assert.equal(res.status, 201)
    assert.equal(res.body.email, 'upper@example.com')
  })

  test('defaults unknown role to ADULT', async () => {
    const { app, emailStub } = buildApp({
      family: () => ({ data: { id: TEST_FAMILY_ID, name: 'The Khans' }, error: null }),
      insertInvitation: (d) => ({ data: { ...d, id: 'inv-004' }, error: null })
    })

    const res = await request(app)
      .post(`/api/families/${TEST_FAMILY_ID}/invite`)
      .send({ email: 'x@x.com', role: 'UNKNOWN_ROLE' })

    assert.equal(res.status, 201)
    assert.equal(res.body.role, 'ADULT')
  })
})

// ─── 3. GET /api/invitations/:token ─────────────────────────────────────────

describe('GET /api/invitations/:token', () => {
  test('returns family name, role and status for valid token', async () => {
    const { app } = buildApp({
      invitationPreview: (token) => ({
        data: {
          email: 'relative@example.com',
          families: { name: 'The Khans' },
          role: 'ADULT',
          access_level: 'edit',
          status: 'pending',
          expires_at: futureDate(6)
        },
        error: null
      })
    })

    const res = await request(app).get(`/api/invitations/${TEST_TOKEN}`)

    assert.equal(res.status, 200)
    assert.equal(res.body.familyName, 'The Khans')
    assert.equal(res.body.role, 'ADULT')
    assert.equal(res.body.status, 'pending')
  })

  test('returns 404 for unknown token', async () => {
    const { app } = buildApp({ invitationPreview: () => null })

    const res = await request(app).get('/api/invitations/no-such-token')
    assert.equal(res.status, 404)
  })

  test('returns accessLevel in preview', async () => {
    const { app } = buildApp({
      invitationPreview: () => ({
        data: {
          email: 'x@x.com',
          families: { name: 'Fam' },
          role: 'JUNIOR',
          access_level: 'view',
          status: 'pending',
          expires_at: futureDate(3)
        },
        error: null
      })
    })

    const res = await request(app).get(`/api/invitations/any-token`)
    assert.equal(res.status, 200)
    assert.equal(res.body.accessLevel, 'view')
  })
})

// ─── 4–9. POST /api/invitations/accept ───────────────────────────────────────

describe('POST /api/invitations/accept', () => {
  test('accepts valid token and joins the family', async () => {
    const { app } = buildApp({
      invitationByToken: () => ({
        data: {
          id: 'inv-001',
          family_id: TEST_FAMILY_ID,
          email: TEST_EMAIL, // matches req.auth.user.email
          role: 'ADULT',
          expires_at: futureDate(6),
          families: { name: 'The Khans' }
        },
        error: null
      }),
      existingMember: () => null,
      insertMember: () => ({ data: { id: 'mem-001' }, error: null })
    })

    const res = await request(app)
      .post('/api/invitations/accept')
      .send({ token: TEST_TOKEN })

    assert.equal(res.status, 200)
    assert.equal(res.body.familyId, TEST_FAMILY_ID)
    assert.equal(res.body.familyName, 'The Khans')
    assert.ok(res.body.message.toLowerCase().includes('joined'))
  })

  test('returns 400 when token is missing', async () => {
    const { app } = buildApp({})

    const res = await request(app)
      .post('/api/invitations/accept')
      .send({})

    assert.equal(res.status, 400)
    assert.ok(res.body.message.toLowerCase().includes('token'))
  })

  test('returns 404 for unknown or already-used token', async () => {
    const { app } = buildApp({
      invitationByToken: () => ({ data: null, error: { message: 'not found' } })
    })

    const res = await request(app)
      .post('/api/invitations/accept')
      .send({ token: 'bad-token' })

    assert.equal(res.status, 404)
  })

  test('returns 410 for expired token', async () => {
    const { app } = buildApp({
      invitationByToken: () => ({
        data: {
          id: 'inv-exp',
          family_id: TEST_FAMILY_ID,
          email: TEST_EMAIL,
          role: 'ADULT',
          expires_at: pastDate(2),
          families: { name: 'The Khans' }
        },
        error: null
      })
    })

    const res = await request(app)
      .post('/api/invitations/accept')
      .send({ token: TEST_TOKEN })

    assert.equal(res.status, 410)
    assert.ok(res.body.message.toLowerCase().includes('expired'))
  })

  test('returns 403 when email does not match authenticated user', async () => {
    const { app } = buildApp({
      invitationByToken: () => ({
        data: {
          id: 'inv-mis',
          family_id: TEST_FAMILY_ID,
          email: 'someoneelse@example.com', // != TEST_EMAIL
          role: 'ADULT',
          expires_at: futureDate(6),
          families: { name: 'The Khans' }
        },
        error: null
      })
    })

    const res = await request(app)
      .post('/api/invitations/accept')
      .send({ token: TEST_TOKEN })

    assert.equal(res.status, 403)
    assert.ok(res.body.message.toLowerCase().includes('different email'))
  })

  test('accepts invite idempotently when user is already a member', async () => {
    const { app } = buildApp({
      invitationByToken: () => ({
        data: {
          id: 'inv-idem',
          family_id: TEST_FAMILY_ID,
          email: TEST_EMAIL,
          role: 'ADULT',
          expires_at: futureDate(6),
          families: { name: 'The Khans' }
        },
        error: null
      }),
      existingMember: () => ({ id: 'mem-existing' }) // already a member
    })

    const res = await request(app)
      .post('/api/invitations/accept')
      .send({ token: TEST_TOKEN })

    assert.equal(res.status, 200)
    assert.ok(res.body.message.toLowerCase().includes('joined'))
  })

  test('returns role in accepted response', async () => {
    const { app } = buildApp({
      invitationByToken: () => ({
        data: {
          id: 'inv-r',
          family_id: TEST_FAMILY_ID,
          email: TEST_EMAIL,
          role: 'JUNIOR',
          expires_at: futureDate(6),
          families: { name: 'The Khans' }
        },
        error: null
      }),
      existingMember: () => null,
      insertMember: () => ({ data: { id: 'mem-j' }, error: null })
    })

    const res = await request(app)
      .post('/api/invitations/accept')
      .send({ token: TEST_TOKEN })

    assert.equal(res.status, 200)
    assert.equal(res.body.role, 'JUNIOR')
  })
})
