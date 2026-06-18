import { Resend } from 'resend'
import { emailConfig } from '../config/env.js'

let resend

function getResend () {
  if (resend) return resend
  if (!emailConfig.resendApiKey) return null
  resend = new Resend(emailConfig.resendApiKey)
  return resend
}

function roleLabel (role) {
  if (role === 'ADMIN') return 'Admin'
  if (role === 'JUNIOR') return 'Viewer'
  return 'Editor'
}

function roleBadgeColor (role) {
  if (role === 'ADMIN') return '#7C3AED'
  if (role === 'JUNIOR') return '#059669'
  return '#2563EB'
}

function buildInviteHtml ({ familyName, inviterName, inviteLink, role, expiryDays = 7 }) {
  const label = roleLabel(role)
  const badgeColor = roleBadgeColor(role)

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>You're invited to ${familyName}</title>
</head>
<body style="margin:0;padding:0;background-color:#F5F3FF;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#F5F3FF;padding:32px 16px;">
    <tr>
      <td align="center">

        <!-- Card -->
        <table role="presentation" width="100%" style="max-width:560px;background:#ffffff;border-radius:20px;overflow:hidden;box-shadow:0 4px 24px rgba(124,58,237,0.10);">

          <!-- Header -->
          <tr>
            <td style="background:linear-gradient(135deg,#7C3AED 0%,#5B21B6 100%);padding:40px 40px 32px;text-align:center;">
              <!-- Icon -->
              <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 auto 20px;">
                <tr>
                  <td style="background:rgba(255,255,255,0.18);width:72px;height:72px;border-radius:20px;text-align:center;vertical-align:middle;">
                    <span style="font-size:36px;line-height:72px;">🏛️</span>
                  </td>
                </tr>
              </table>
              <p style="margin:0 0 6px;font-size:13px;font-weight:600;letter-spacing:1.5px;text-transform:uppercase;color:rgba(255,255,255,0.75);">Family Digital Heritage Vault</p>
              <h1 style="margin:0;font-size:26px;font-weight:700;color:#ffffff;line-height:1.3;">You're invited!</h1>
            </td>
          </tr>

          <!-- Body -->
          <tr>
            <td style="padding:36px 40px 0;">
              <p style="margin:0 0 20px;font-size:16px;color:#374151;line-height:1.6;">
                <strong style="color:#111827;">${inviterName}</strong> has invited you to join the
                <strong style="color:#7C3AED;">${familyName}</strong> vault — a private space to preserve memories, build your family tree, and pass down your heritage.
              </p>

              <!-- Role badge -->
              <table role="presentation" cellpadding="0" cellspacing="0" style="margin-bottom:28px;">
                <tr>
                  <td style="padding:10px 16px;background:${badgeColor}1A;border:1.5px solid ${badgeColor}40;border-radius:10px;">
                    <span style="font-size:13px;font-weight:600;color:${badgeColor};">Your role: ${label}</span>
                    &nbsp;
                    <span style="font-size:12px;color:#6B7280;">
                      ${label === 'Admin' ? '— full access to manage members &amp; content'
                        : label === 'Editor' ? '— can upload memories and manage the tree'
                        : '— can view memories and browse the tree'}
                    </span>
                  </td>
                </tr>
              </table>

              <!-- CTA -->
              <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="margin-bottom:28px;">
                <tr>
                  <td align="center">
                    <a href="${inviteLink}"
                       style="display:inline-block;padding:15px 36px;background:linear-gradient(135deg,#7C3AED,#5B21B6);color:#ffffff;font-size:16px;font-weight:700;text-decoration:none;border-radius:12px;letter-spacing:0.3px;">
                      Accept Invitation →
                    </a>
                  </td>
                </tr>
              </table>

              <!-- Fallback link -->
              <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="margin-bottom:28px;">
                <tr>
                  <td style="background:#F9FAFB;border:1px solid #E5E7EB;border-radius:10px;padding:14px 16px;">
                    <p style="margin:0 0 6px;font-size:12px;font-weight:600;color:#6B7280;text-transform:uppercase;letter-spacing:0.8px;">Or copy this link</p>
                    <p style="margin:0;font-size:13px;color:#7C3AED;word-break:break-all;">${inviteLink}</p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Divider + footer -->
          <tr>
            <td style="padding:0 40px 32px;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td style="border-top:1px solid #F3F4F6;padding-top:20px;">
                    <p style="margin:0 0 4px;font-size:12px;color:#9CA3AF;">
                      ⏳ This invitation expires in <strong>${expiryDays} days</strong>.
                    </p>
                    <p style="margin:0;font-size:12px;color:#9CA3AF;">
                      If you didn't expect this email you can safely ignore it.
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Footer bar -->
          <tr>
            <td style="background:#F5F3FF;padding:16px 40px;text-align:center;border-top:1px solid #EDE9FE;">
              <p style="margin:0;font-size:12px;color:#8B5CF6;font-weight:500;">Family Digital Heritage Vault</p>
              <p style="margin:4px 0 0;font-size:11px;color:#A78BFA;">Preserve memories. Connect generations. Secure your legacy forever.</p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>`
}

export async function sendFamilyInviteEmail ({
  toEmail,
  familyName,
  inviterName,
  inviteLink,
  role = 'ADULT',
  expiryDays = 7
}) {
  const client = getResend()

  if (!client) {
    console.log('[email] RESEND_API_KEY not set — invite link for', toEmail, ':', inviteLink)
    return { sent: false, previewLink: inviteLink }
  }

  const html = buildInviteHtml({ familyName, inviterName, inviteLink, role, expiryDays })
  const label = roleLabel(role)

  const { data, error } = await client.emails.send({
    from: emailConfig.fromEmail,
    to: toEmail,
    subject: `${inviterName} invited you to join ${familyName}`,
    html,
    text: `${inviterName} invited you to join ${familyName} as ${label}.\n\nAccept here: ${inviteLink}\n\nThis link expires in ${expiryDays} days.`
  })

  if (error) {
    console.error('[email] Resend error', error)
    throw new Error(error.message || 'Failed to send invitation email')
  }

  return { sent: true, messageId: data?.id }
}
