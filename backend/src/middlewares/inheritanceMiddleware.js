import { supabaseAdmin } from '../config/supabaseClient.js'
import { calculateAge, isRuleSatisfied } from '../utils/inheritanceEvaluator.js'

// Inheritance middleware:
// Every memory access that may be protected passes through here.
// It checks inheritance_rules and blocks access if conditions are not yet met.

export function enforceInheritanceRules () {
  return async function (req, res, next) {
    try {
      const userId = req.auth?.user?.id
      const memoryId = req.params.memoryId || req.body.memoryId || req.query.memoryId

      if (!userId || !memoryId) {
        return res.status(400).json({ message: 'Missing user or memory context' })
      }

      // Load memory, inheritance rules, and associated family & beneficiary nodes
      const { data: memory, error: memoryError } = await supabaseAdmin
        .from('memories')
        .select('id, family_id')
        .eq('id', memoryId)
        .single()

      if (memoryError || !memory) {
        return res.status(404).json({ message: 'Memory not found' })
      }

      const { data: rules, error: rulesError } = await supabaseAdmin
        .from('inheritance_rules')
        .select(`
          id,
          condition_type,
          unlock_date,
          unlock_age,
          beneficiary_node_id,
          family_id,
          memory_id
        `)
        .eq('memory_id', memoryId)

      if (rulesError) {
        console.error('Error loading inheritance rules', rulesError)
        return res.status(500).json({ message: 'Failed to load inheritance rules' })
      }

      if (!rules || rules.length === 0) {
        // No inheritance restriction; proceed
        return next()
      }

      // Find which family tree nodes correspond to this user in this family
      const { data: userNodes, error: nodesError } = await supabaseAdmin
        .from('family_tree_nodes')
        .select('id, birth_date, family_id, user_id')
        .eq('user_id', userId)
        .eq('family_id', memory.family_id)

      if (nodesError) {
        console.error('Error resolving user nodes', nodesError)
        return res.status(500).json({ message: 'Failed to resolve user inheritance context' })
      }

      const userNodeIds = (userNodes || []).map(n => n.id)

      // If the user is not represented in the tree, block access to inheritance-protected content
      if (userNodeIds.length === 0) {
        return res.status(403).json({ message: 'User is not linked in family tree; cannot access inheritance-protected memory' })
      }

      const now = new Date()

      for (const rule of rules) {
        if (!userNodeIds.includes(rule.beneficiary_node_id)) {
          continue
        }

        const beneficiaryNode = (userNodes || []).find(n => n.id === rule.beneficiary_node_id)
        if (!isRuleSatisfied(rule, beneficiaryNode?.birth_date, now)) {
          const payload = {
            message: 'Inheritance memory is locked',
            conditionType: rule.condition_type
          }
          if (rule.condition_type === 'UNLOCK_AT_DATE') {
            payload.unlockDate = rule.unlock_date
          } else if (rule.condition_type === 'UNLOCK_AT_AGE') {
            payload.requiredAge = rule.unlock_age
            payload.currentAge = calculateAge(beneficiaryNode?.birth_date, now)
          } else if (rule.condition_type === 'UNLOCK_ON_BIRTHDAY') {
            payload.hint = 'This memory unlocks on the beneficiary\'s birthday each year'
          }
          return res.status(403).json(payload)
        }
      }

      // All applicable rules satisfied
      next()
    } catch (err) {
      console.error('Inheritance middleware error', err)
      return res.status(500).json({ message: 'Failed to evaluate inheritance rules' })
    }
  }
}
