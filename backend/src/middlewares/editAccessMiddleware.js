// Blocks write operations for view-only members (JUNIOR = view-only invites).

export function requireEditAccess () {
  return function (req, res, next) {
    const role = req.auth?.familyRole
    if (role === 'JUNIOR') {
      return res.status(403).json({
        message: 'View-only access. You cannot edit family data or upload memories.'
      })
    }
    next()
  }
}
