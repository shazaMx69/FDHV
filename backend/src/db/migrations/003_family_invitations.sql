-- Run in Supabase SQL Editor

CREATE TABLE IF NOT EXISTS family_invitations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id uuid NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  email text NOT NULL,
  role family_role NOT NULL DEFAULT 'ADULT',
  access_level text NOT NULL DEFAULT 'edit' CHECK (access_level IN ('view', 'edit')),
  token text UNIQUE NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'expired')),
  invited_by uuid NOT NULL REFERENCES users(id),
  expires_at timestamptz NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_family_invitations_token ON family_invitations(token);
CREATE INDEX IF NOT EXISTS idx_family_invitations_email ON family_invitations(email);

-- Optional: birthday unlock for inheritance
ALTER TYPE inheritance_condition_type ADD VALUE IF NOT EXISTS 'UNLOCK_ON_BIRTHDAY';
