export function calculateAge (birthDate, now = new Date()) {
  if (!birthDate) return null
  const birth = new Date(birthDate)
  let age = now.getFullYear() - birth.getFullYear()
  const m = now.getMonth() - birth.getMonth()
  if (m < 0 || (m === 0 && now.getDate() < birth.getDate())) {
    age--
  }
  return age
}

export function isBirthdayToday (birthDate, now = new Date()) {
  if (!birthDate) return false
  const birth = new Date(birthDate)
  return birth.getMonth() === now.getMonth() && birth.getDate() === now.getDate()
}

/**
 * Returns true if beneficiary can access memory under rule.
 */
export function isRuleSatisfied (rule, beneficiaryBirthDate, now = new Date()) {
  if (rule.condition_type === 'UNLOCK_AT_DATE') {
    if (!rule.unlock_date) return false
    return now >= new Date(rule.unlock_date)
  }

  if (rule.condition_type === 'UNLOCK_AT_AGE') {
    if (!rule.unlock_age) return false
    const age = calculateAge(beneficiaryBirthDate, now)
    return age != null && age >= rule.unlock_age
  }

  if (rule.condition_type === 'UNLOCK_ON_BIRTHDAY') {
    return isBirthdayToday(beneficiaryBirthDate, now)
  }

  return false
}

/**
 * For list views:
 * Returns { locked: boolean, hidden: boolean, ... }
 *
 * Logic:
 * 1. If no rules, anyone in the family can see it (unlocked, not hidden).
 * 2. If rules exist:
 *    - If user is NOT a beneficiary in any of the rules, it is HIDDEN from them.
 *    - If user IS a beneficiary:
 *      - If ALL rules for this user are satisfied, it is UNLOCKED (not hidden).
 *      - If ANY rule for this user is unsatisfied, it is LOCKED (not hidden).
 */
export function evaluateMemoryLockForUser ({
  rules,
  userNodeIds,
  nodesById,
  now = new Date()
}) {
  if (!rules?.length) {
    return { locked: false, hidden: false }
  }

  const userIsBeneficiary = rules.some((r) => userNodeIds.includes(r.beneficiary_node_id))

  if (!userIsBeneficiary) {
    // If there are inheritance rules but this user isn't one of the targets, hide it.
    // This satisfies the "only visible to selected person" requirement.
    return { locked: true, hidden: true }
  }

  const applicable = rules.filter((r) => userNodeIds.includes(r.beneficiary_node_id))

  for (const rule of applicable) {
    const node = nodesById[rule.beneficiary_node_id]
    if (!isRuleSatisfied(rule, node?.birth_date, now)) {
      return {
        locked: true,
        hidden: false,
        conditionType: rule.condition_type,
        unlockDate: rule.unlock_date,
        unlockAge: rule.unlock_age
      }
    }
  }

  return { locked: false, hidden: false }
}
