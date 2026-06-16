import express from 'express'
import multer from 'multer'
import { supabaseAdmin } from '../config/supabaseClient.js'
import { requireFamilyRole } from '../middlewares/roleMiddleware.js'
import { requireEditAccess } from '../middlewares/editAccessMiddleware.js'
import { enforceInheritanceRules } from '../middlewares/inheritanceMiddleware.js'
import { evaluateMemoryLockForUser } from '../utils/inheritanceEvaluator.js'

const router = express.Router()
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 50 * 1024 * 1024 }
})

function normalizeMediaType (mediaType) {
  const upper = String(mediaType || '').toUpperCase()
  if (upper === 'IMAGE' || upper === 'PHOTO') return 'photo'
  if (upper === 'VIDEO') return 'video'
  if (upper === 'AUDIO') return 'audio'
  if (upper === 'DOCUMENT' || upper === 'TEXT') return 'text'
  return 'photo'
}

const MEMORY_BUCKET = 'memories'
const SIGNED_URL_TTL_SEC = 60 * 60

/** Ensures familyId is available for role checks on single-memory routes. */
async function attachFamilyIdFromMemory (req, res, next) {
  try {
    if (req.query.familyId || req.params.familyId || req.body.familyId) {
      return next()
    }

    const memoryId = req.params.memoryId
    if (!memoryId) {
      return res.status(400).json({ message: 'memoryId is required' })
    }

    const { data: memory, error } = await supabaseAdmin
      .from('memories')
      .select('family_id')
      .eq('id', memoryId)
      .single()

    if (error || !memory) {
      return res.status(404).json({ message: 'Memory not found' })
    }

    req.query.familyId = memory.family_id
    next()
  } catch (err) {
    console.error('attachFamilyIdFromMemory error', err)
    res.status(500).json({ message: 'Failed to resolve memory family' })
  }
}

/** Object path inside the `memories` bucket (not the public HTTP URL). */
function extractStorageObjectPath (storagePath) {
  if (!storagePath || typeof storagePath !== 'string') return null
  const trimmed = storagePath.trim()
  if (!trimmed.startsWith('http')) return trimmed

  const publicMatch = trimmed.match(/\/object\/public\/memories\/(.+?)(?:\?|$)/)
  if (publicMatch) return decodeURIComponent(publicMatch[1])

  const signedMatch = trimmed.match(/\/object\/sign\/memories\/(.+?)(?:\?|$)/)
  if (signedMatch) return decodeURIComponent(signedMatch[1])

  return trimmed
}

async function resolveMemoryMediaUrl (storagePath) {
  const objectPath = extractStorageObjectPath(storagePath)
  if (!objectPath) return null

  const { data, error } = await supabaseAdmin.storage
    .from(MEMORY_BUCKET)
    .createSignedUrl(objectPath, SIGNED_URL_TTL_SEC)

  if (!error && data?.signedUrl) {
    return data.signedUrl
  }

  console.error('Signed URL error', error)
  const { data: pub } = supabaseAdmin.storage
    .from(MEMORY_BUCKET)
    .getPublicUrl(objectPath)
  return pub.publicUrl
}

async function serializeMemory (row, { locked = false } = {}) {
  if (!row) return row
  const mediaUrl = !locked && row.storage_path
    ? await resolveMemoryMediaUrl(row.storage_path)
    : null
  return {
    ...row,
    created_at: row.created_at ?? new Date().toISOString(),
    media_url: mediaUrl,
    locked
  }
}

async function enrichMemoriesWithInheritance (memories, userId, familyId, userRole) {
  if (!memories?.length) return memories

  const memoryIds = memories.map((m) => m.id)

  const [{ data: rules }, { data: userNodes }] = await Promise.all([
    supabaseAdmin
      .from('inheritance_rules')
      .select('memory_id, condition_type, unlock_date, unlock_age, beneficiary_node_id')
      .eq('family_id', familyId)
      .in('memory_id', memoryIds),
    supabaseAdmin
      .from('family_tree_nodes')
      .select('id, birth_date')
      .eq('family_id', familyId)
      .eq('user_id', userId)
  ])

  const userNodeIds = (userNodes || []).map((n) => n.id)
  const nodesById = Object.fromEntries((userNodes || []).map((n) => [n.id, n]))
  const rulesByMemory = {}
  for (const rule of rules || []) {
    if (!rulesByMemory[rule.memory_id]) rulesByMemory[rule.memory_id] = []
    rulesByMemory[rule.memory_id].push(rule)
  }

  const enriched = await Promise.all(
    memories.map(async (memory) => {
      const memoryRules = rulesByMemory[memory.id] || []
      const lock = evaluateMemoryLockForUser({
        rules: memoryRules,
        userNodeIds,
        nodesById
      })

      // Admins and the creator can always see the memory metadata, even if locked/hidden for others
      const canSeeMetadata = userRole === 'ADMIN' || memory.created_by === userId || !lock.hidden

      if (!canSeeMetadata) return null

      const serialized = await serializeMemory(memory, { locked: lock.locked })
      if (lock.locked) {
        serialized.inheritance_info = {
          condition_type: lock.conditionType,
          unlock_date: lock.unlockDate,
          unlock_age: lock.unlockAge
        }
      }
      return serialized
    })
  )

  return enriched.filter(m => m !== null)
}

// Upload media file to Supabase Storage (service role — works on web & mobile)
router.post(
  '/upload-media',
  upload.single('file'),
  requireFamilyRole(['ADMIN', 'ADULT']),
  requireEditAccess(),
  async (req, res) => {
    try {
      const familyId = req.body.familyId || req.params.familyId
      const file = req.file

      if (!familyId) {
        return res.status(400).json({ message: 'familyId is required' })
      }
      if (!file) {
        return res.status(400).json({ message: 'file is required' })
      }

      const safeName = (file.originalname || 'upload.bin').replace(/[^a-zA-Z0-9._-]/g, '_')
      const storagePath = `memories/${familyId}/${Date.now()}_${safeName}`

      const { error: uploadError } = await supabaseAdmin.storage
        .from('memories')
        .upload(storagePath, file.buffer, {
          contentType: file.mimetype || 'application/octet-stream',
          upsert: false
        })

      if (uploadError) {
        console.error('Storage upload error', uploadError)
        return res.status(500).json({
          message: uploadError.message || 'Failed to upload file to storage'
        })
      }

      const { data: publicData } = supabaseAdmin.storage
        .from('memories')
        .getPublicUrl(storagePath)

      res.status(201).json({
        storagePath,
        publicUrl: publicData.publicUrl
      })
    } catch (err) {
      console.error('Upload media error', err)
      res.status(500).json({ message: 'Failed to upload media' })
    }
  }
)

// Create memory metadata after media is uploaded
router.post('/', requireFamilyRole(['ADMIN', 'ADULT']), requireEditAccess(), async (req, res) => {
  try {
    const {
      familyId,
      title,
      description,
      mediaType,
      storagePath,
      event,
      eventDate,
      tags,
      peopleNodeIds
    } = req.body

    if (!familyId || !title || !mediaType) {
      return res.status(400).json({ message: 'familyId, title and mediaType are required' })
    }

    const { data: memory, error } = await supabaseAdmin
      .from('memories')
      .insert({
        family_id: familyId,
        created_by: req.auth.user.id,
        title,
        description,
        media_type: normalizeMediaType(mediaType),
        storage_path: storagePath,
        event,
        event_date: eventDate,
        tags
      })
      .select('*')
      .single()

    if (error) {
      console.error('Create memory error', error)
      return res.status(500).json({ message: 'Failed to create memory' })
    }

    if (Array.isArray(peopleNodeIds) && peopleNodeIds.length > 0) {
      const rows = peopleNodeIds.map(nodeId => ({
        memory_id: memory.id,
        node_id: nodeId
      }))

      const { error: tagError } = await supabaseAdmin
        .from('memory_people_tags')
        .insert(rows)

      if (tagError) {
        console.error('Memory people tag error', tagError)
      }
    }

    res.status(201).json(await serializeMemory(memory))
  } catch (err) {
    console.error('Create memory error', err)
    res.status(500).json({ message: 'Failed to create memory' })
  }
})

// List memories for a family (respecting role & inheritance engine)
router.get('/', requireFamilyRole(['ADMIN', 'ADULT', 'JUNIOR']), async (req, res) => {
  try {
    const { familyId } = req.query
    if (!familyId) {
      return res.status(400).json({ message: 'familyId is required' })
    }

    const { data, error } = await supabaseAdmin
      .from('memories')
      .select('*')
      .eq('family_id', familyId)
      .order('created_at', { ascending: false })

    if (error) {
      console.error('List memories error', error)
      return res.status(500).json({ message: 'Failed to list memories' })
    }

    const userId = req.auth.user.id
    const memories = await enrichMemoriesWithInheritance(
      data ?? [],
      userId,
      familyId,
      req.auth.familyRole
    )
    res.json(memories)
  } catch (err) {
    console.error('List memories error', err)
    res.status(500).json({ message: 'Failed to list memories' })
  }
})

// Get a single memory with inheritance check
router.get(
  '/:memoryId',
  attachFamilyIdFromMemory,
  requireFamilyRole(['ADMIN', 'ADULT', 'JUNIOR']),
  enforceInheritanceRules(),
  async (req, res) => {
  try {
    const { memoryId } = req.params

    const { data: memory, error } = await supabaseAdmin
      .from('memories')
      .select('*')
      .eq('id', memoryId)
      .single()

    if (error || !memory) {
      return res.status(404).json({ message: 'Memory not found' })
    }

    res.json(await serializeMemory(memory))
  } catch (err) {
    console.error('Get memory error', err)
    res.status(500).json({ message: 'Failed to load memory' })
  }
})

// Set inheritance rule for a memory (admin only)
router.post('/:memoryId/inheritance-rules', requireFamilyRole(['ADMIN']), async (req, res) => {
  try {
    const { memoryId } = req.params
    const { familyId, beneficiaryNodeId, conditionType, unlockDate, unlockAge } = req.body

    if (!familyId || !beneficiaryNodeId || !conditionType) {
      return res.status(400).json({ message: 'familyId, beneficiaryNodeId and conditionType are required' })
    }

    if (!['UNLOCK_AT_DATE', 'UNLOCK_AT_AGE', 'UNLOCK_ON_BIRTHDAY'].includes(conditionType)) {
      return res.status(400).json({ message: 'Invalid conditionType' })
    }

    if (conditionType === 'UNLOCK_AT_DATE' && !unlockDate) {
      return res.status(400).json({ message: 'unlockDate required for UNLOCK_AT_DATE' })
    }

    if (conditionType === 'UNLOCK_AT_AGE' && !unlockAge) {
      return res.status(400).json({ message: 'unlockAge required for UNLOCK_AT_AGE' })
    }

    if (conditionType === 'UNLOCK_ON_BIRTHDAY') {
      const { data: beneficiary } = await supabaseAdmin
        .from('family_tree_nodes')
        .select('birth_date')
        .eq('id', beneficiaryNodeId)
        .single()
      if (!beneficiary?.birth_date) {
        return res.status(400).json({
          message: 'Beneficiary must have a birth date for birthday unlock rules'
        })
      }
    }

    const { data: rule, error } = await supabaseAdmin
      .from('inheritance_rules')
      .insert({
        memory_id: memoryId,
        family_id: familyId,
        beneficiary_node_id: beneficiaryNodeId,
        condition_type: conditionType,
        unlock_date: unlockDate,
        unlock_age: unlockAge,
        created_by: req.auth.user.id
      })
      .select('*')
      .single()

    if (error) {
      console.error('Create inheritance rule error', error)
      return res.status(500).json({ message: 'Failed to create inheritance rule' })
    }

    res.status(201).json(rule)
  } catch (err) {
    console.error('Create inheritance rule error', err)
    res.status(500).json({ message: 'Failed to create inheritance rule' })
  }
})

export default router

