import { supabaseAdmin } from '../config/supabaseClient.js'

export const STORAGE_BUCKET = 'memories'
export const SIGNED_URL_TTL_SEC = 60 * 60

export function extractStorageObjectPath (storagePath) {
  if (!storagePath || typeof storagePath !== 'string') return null
  const trimmed = storagePath.trim()
  if (!trimmed.startsWith('http')) return trimmed

  const publicMatch = trimmed.match(/\/object\/public\/memories\/(.+?)(?:\?|$)/)
  if (publicMatch) return decodeURIComponent(publicMatch[1])

  const signedMatch = trimmed.match(/\/object\/sign\/memories\/(.+?)(?:\?|$)/)
  if (signedMatch) return decodeURIComponent(signedMatch[1])

  return trimmed
}

export async function resolveStorageMediaUrl (storagePath) {
  const objectPath = extractStorageObjectPath(storagePath)
  if (!objectPath) return null

  const { data, error } = await supabaseAdmin.storage
    .from(STORAGE_BUCKET)
    .createSignedUrl(objectPath, SIGNED_URL_TTL_SEC)

  if (!error && data?.signedUrl) {
    return data.signedUrl
  }

  console.error('Signed URL error', error)
  const { data: pub } = supabaseAdmin.storage
    .from(STORAGE_BUCKET)
    .getPublicUrl(objectPath)
  return pub.publicUrl
}
