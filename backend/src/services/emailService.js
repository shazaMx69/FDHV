import nodemailer from 'nodemailer'
import { appConfig } from '../config/env.js'

let transporter

function getTransporter () {
  if (transporter) return transporter

  const host = process.env.SMTP_HOST
  const port = Number(process.env.SMTP_PORT || 587)
  const user = process.env.SMTP_USER
  const pass = process.env.SMTP_PASS

  if (!host || !user || !pass) {
    return null
  }

  transporter = nodemailer.createTransport({
    host,
    port,
    secure: port === 465,
    auth: { user, pass }
  })

  return transporter
}

export async function sendFamilyInviteEmail ({
  toEmail,
  familyName,
  inviterName,
  inviteLink,
  accessLevel
}) {
  const from = process.env.SMTP_FROM || 'Family Heritage Vault <noreply@familyvault.local>'
  const accessLabel = accessLevel === 'view' ? 'View only' : 'Can edit'

  const html = `
    <div style="font-family:Arial,sans-serif;max-width:560px;margin:0 auto">
      <h2>You're invited to a family vault</h2>
      <p><strong>${inviterName}</strong> invited you to join <strong>${familyName}</strong> on Family Digital Heritage Vault.</p>
      <p>Access level: <strong>${accessLabel}</strong></p>
      <p><a href="${inviteLink}" style="display:inline-block;padding:12px 24px;background:#7C3AED;color:#fff;text-decoration:none;border-radius:8px">Accept invitation</a></p>
      <p style="color:#666;font-size:13px">If the button does not work, copy this link:<br>${inviteLink}</p>
      <p style="color:#666;font-size:12px">This link expires in 7 days.</p>
    </div>
  `

  const mail = {
    from,
    to: toEmail,
    subject: `Invitation to join ${familyName}`,
    html,
    text: `${inviterName} invited you to ${familyName}. Access: ${accessLabel}. Accept: ${inviteLink}`
  }

  const transport = getTransporter()
  if (!transport) {
    console.log('[email] SMTP not configured — invite link for', toEmail, ':', inviteLink)
    return { sent: false, previewLink: inviteLink }
  }

  await transport.sendMail(mail)
  return { sent: true }
}
