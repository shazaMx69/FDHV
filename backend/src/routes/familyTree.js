import express from 'express'
import multer from 'multer'
import { supabaseAdmin } from '../config/supabaseClient.js'
import { requireFamilyRole } from '../middlewares/roleMiddleware.js'
import { requireEditAccess } from '../middlewares/editAccessMiddleware.js'
import { resolveStorageMediaUrl, STORAGE_BUCKET } from '../utils/storageMedia.js'

const router = express.Router()
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }
})

async function serializeNode (row) {
  if (!row) return row
  const metadata = row.metadata ?? {}
  const photoPath = metadata.photoPath || metadata.photo_path
  const photoUrl = photoPath ? await resolveStorageMediaUrl(photoPath) : null
  return {
    ...row,
    metadata,
    created_at: row.created_at ?? new Date().toISOString(),
    photo_url: photoUrl
  }
}

function serializeRelationship (row) {
  if (!row) return row
  return {
    ...row,
    created_at: row.created_at ?? new Date().toISOString()
  }
}

// Upload member profile photo (after node is created)
router.post(
  '/:familyId/nodes/:nodeId/photo',
  upload.single('file'),
  requireFamilyRole(['ADMIN', 'ADULT']),
  requireEditAccess(),
  async (req, res) => {
    try {
      const { familyId, nodeId } = req.params
      const file = req.file

      if (!file) {
        return res.status(400).json({ message: 'file is required' })
      }

      const { data: existing, error: fetchError } = await supabaseAdmin
        .from('family_tree_nodes')
        .select('metadata')
        .eq('id', nodeId)
        .eq('family_id', familyId)
        .single()

      if (fetchError || !existing) {
        return res.status(404).json({ message: 'Family member not found' })
      }

      const ext = (file.originalname || '').split('.').pop()?.toLowerCase() || 'jpg'
      const safeExt = ['jpg', 'jpeg', 'png', 'webp', 'gif'].includes(ext) ? ext : 'jpg'
      const objectPath = `family-tree/${familyId}/${nodeId}_${Date.now()}.${safeExt}`

      const { error: uploadError } = await supabaseAdmin.storage
        .from(STORAGE_BUCKET)
        .upload(objectPath, file.buffer, {
          contentType: file.mimetype || 'image/jpeg',
          upsert: true
        })

      if (uploadError) {
        console.error('Member photo upload error', uploadError)
        return res.status(500).json({
          message: uploadError.message || 'Failed to upload photo'
        })
      }

      const metadata = {
        ...(existing.metadata ?? {}),
        photoPath: objectPath
      }

      const { data: updated, error: updateError } = await supabaseAdmin
        .from('family_tree_nodes')
        .update({ metadata })
        .eq('id', nodeId)
        .eq('family_id', familyId)
        .select('*')
        .single()

      if (updateError) {
        console.error('Update member metadata error', updateError)
        return res.status(500).json({ message: 'Failed to save photo reference' })
      }

      res.status(201).json(await serializeNode(updated))
    } catch (err) {
      console.error('Member photo upload error', err)
      res.status(500).json({ message: 'Failed to upload member photo' })
    }
  }
)

// Create or update a family tree node
router.post('/:familyId/nodes', requireFamilyRole(['ADMIN', 'ADULT']), requireEditAccess(), async (req, res) => {
  try {
    const { familyId } = req.params
    const { id, fullName, birthDate, deathDate, metadata, userId } = req.body

    if (!fullName) {
      return res.status(400).json({ message: 'fullName is required' })
    }

    const generation =
      metadata != null && Object.prototype.hasOwnProperty.call(metadata, 'generation')
        ? metadata.generation
        : 1
    const normalizedMetadata = {
      ...(metadata ?? {}),
      generation
    }

    if (id) {
      const { data, error } = await supabaseAdmin
        .from('family_tree_nodes')
        .update({
          full_name: fullName,
          birth_date: birthDate,
          death_date: deathDate,
          metadata: normalizedMetadata,
          user_id: userId
        })
        .eq('id', id)
        .eq('family_id', familyId)
        .select('*')
        .single()

      if (error) {
        console.error('Update node error', error)
        return res.status(500).json({ message: 'Failed to update node' })
      }

      return res.json(await serializeNode(data))
    } else {
      const { data, error } = await supabaseAdmin
        .from('family_tree_nodes')
        .insert({
          family_id: familyId,
          full_name: fullName,
          birth_date: birthDate,
          death_date: deathDate,
          metadata: normalizedMetadata,
          user_id: userId
        })
        .select('*')
        .single()

      if (error) {
        console.error('Create node error', error)
        return res.status(500).json({
          message: error.message || 'Failed to create node',
          code: error.code
        })
      }

      return res.status(201).json(await serializeNode(data))
    }
  } catch (err) {
    console.error('Node upsert error', err)
    res.status(500).json({ message: 'Failed to save node' })
  }
})

// Define relationships between nodes
router.post('/:familyId/relationships', requireFamilyRole(['ADMIN', 'ADULT']), requireEditAccess(), async (req, res) => {
  try {
    const { familyId } = req.params
    const { fromNodeId, toNodeId, type } = req.body

    if (!fromNodeId || !toNodeId || !type) {
      return res.status(400).json({ message: 'fromNodeId, toNodeId and type are required' })
    }

    if (!['PARENT', 'CHILD', 'SPOUSE'].includes(type)) {
      return res.status(400).json({ message: 'Invalid relationship type' })
    }

    const { data, error } = await supabaseAdmin
      .from('family_relationships')
      .insert({
        family_id: familyId,
        from_node_id: fromNodeId,
        to_node_id: toNodeId,
        type
      })
      .select('*')
      .single()

    if (error) {
      console.error('Create relationship error', error)
      return res.status(500).json({ message: 'Failed to create relationship' })
    }

    res.status(201).json(serializeRelationship(data))
  } catch (err) {
    console.error('Create relationship error', err)
    res.status(500).json({ message: 'Failed to create relationship' })
  }
})

// Delete a relationship
router.delete(
  '/:familyId/relationships/:relationshipId',
  requireFamilyRole(['ADMIN', 'ADULT']),
  requireEditAccess(),
  async (req, res) => {
    try {
      const { familyId, relationshipId } = req.params

      const { error } = await supabaseAdmin
        .from('family_relationships')
        .delete()
        .eq('id', relationshipId)
        .eq('family_id', familyId)

      if (error) {
        console.error('Delete relationship error', error)
        return res.status(500).json({
          message: error.message || 'Failed to delete relationship'
        })
      }

      res.status(204).send()
    } catch (err) {
      console.error('Delete relationship error', err)
      res.status(500).json({ message: 'Failed to delete relationship' })
    }
  }
)

// Get tree (nodes + relationships) for a family
router.get('/:familyId', requireFamilyRole(['ADMIN', 'ADULT', 'JUNIOR']), async (req, res) => {
  try {
    const { familyId } = req.params

    const [{ data: nodes, error: nodesError }, { data: relationships, error: relError }] =
      await Promise.all([
        supabaseAdmin
          .from('family_tree_nodes')
          .select('*')
          .eq('family_id', familyId),
        supabaseAdmin
          .from('family_relationships')
          .select('*')
          .eq('family_id', familyId)
      ])

    if (nodesError || relError) {
      console.error('Load tree error', nodesError || relError)
      return res.status(500).json({ message: 'Failed to load family tree' })
    }

    const serializedNodes = await Promise.all((nodes ?? []).map(serializeNode))

    res.json({
      nodes: serializedNodes,
      relationships: (relationships ?? []).map(serializeRelationship)
    })
  } catch (err) {
    console.error('Get tree error', err)
    res.status(500).json({ message: 'Failed to load family tree' })
  }
})

// Safe delete node
router.delete('/:familyId/nodes/:nodeId', requireFamilyRole(['ADMIN']), async (req, res) => {
  try {
    const { familyId, nodeId } = req.params

    const { data: relationships, error } = await supabaseAdmin
      .from('family_relationships')
      .select('id')
      .or(`from_node_id.eq.${nodeId},to_node_id.eq.${nodeId}`)
      .eq('family_id', familyId)

    if (error) {
      console.error('Check node relationships error', error)
      return res.status(500).json({ message: 'Failed to validate node deletion' })
    }

    if (relationships && relationships.length > 0) {
      return res.status(400).json({
        message: 'Cannot delete a node that is part of existing relationships. Remove relationships first.'
      })
    }

    const { error: deleteError } = await supabaseAdmin
      .from('family_tree_nodes')
      .delete()
      .eq('id', nodeId)
      .eq('family_id', familyId)

    if (deleteError) {
      console.error('Delete node error', deleteError)
      return res.status(500).json({ message: 'Failed to delete node' })
    }

    res.status(204).send()
  } catch (err) {
    console.error('Delete node error', err)
    res.status(500).json({ message: 'Failed to delete node' })
  }
})

export default router
