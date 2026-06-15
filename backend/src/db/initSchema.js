import pg from 'pg'
import { supabaseConfig } from '../config/env.js'

const { Client } = pg

const schemaSql = `
CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  supabase_uid uuid UNIQUE NOT NULL,
  email text UNIQUE NOT NULL,
  display_name text,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS families (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  created_by uuid NOT NULL REFERENCES users(id),
  created_at timestamptz DEFAULT now()
);

CREATE TYPE family_role AS ENUM ('ADMIN', 'ADULT', 'JUNIOR');

CREATE TABLE IF NOT EXISTS family_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id uuid NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role family_role NOT NULL DEFAULT 'ADULT',
  invited_email text,
  created_at timestamptz DEFAULT now(),
  UNIQUE (family_id, user_id)
);

CREATE TABLE IF NOT EXISTS family_tree_nodes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id uuid NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  user_id uuid REFERENCES users(id),
  full_name text NOT NULL,
  birth_date date,
  death_date date,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now()
);

CREATE TYPE relationship_type AS ENUM ('PARENT', 'CHILD', 'SPOUSE');

CREATE TABLE IF NOT EXISTS family_relationships (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id uuid NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  from_node_id uuid NOT NULL REFERENCES family_tree_nodes(id) ON DELETE CASCADE,
  to_node_id uuid NOT NULL REFERENCES family_tree_nodes(id) ON DELETE CASCADE,
  type relationship_type NOT NULL,
  created_at timestamptz DEFAULT now(),
  CONSTRAINT no_self_relationship CHECK (from_node_id <> to_node_id)
);

CREATE TABLE IF NOT EXISTS memories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id uuid NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  created_by uuid NOT NULL REFERENCES users(id),
  title text NOT NULL,
  description text,
  media_type text NOT NULL, -- photo, video, audio, text
  storage_path text,
  event text,
  event_date date,
  tags text[] DEFAULT '{}',
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS memory_people_tags (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  memory_id uuid NOT NULL REFERENCES memories(id) ON DELETE CASCADE,
  node_id uuid NOT NULL REFERENCES family_tree_nodes(id) ON DELETE CASCADE
);

CREATE TYPE inheritance_condition_type AS ENUM ('UNLOCK_AT_DATE', 'UNLOCK_AT_AGE');

CREATE TABLE IF NOT EXISTS inheritance_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  memory_id uuid NOT NULL REFERENCES memories(id) ON DELETE CASCADE,
  family_id uuid NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  beneficiary_node_id uuid NOT NULL REFERENCES family_tree_nodes(id) ON DELETE CASCADE,
  condition_type inheritance_condition_type NOT NULL,
  unlock_date date,
  unlock_age integer,
  created_by uuid NOT NULL REFERENCES users(id),
  created_at timestamptz DEFAULT now()
);
`

export async function initSchema () {
  if (!supabaseConfig.postgresConnectionString) {
    console.warn('SUPABASE_POSTGRES_CONNECTION_STRING not set; skipping automatic schema initialization.')
    return
  }

  const client = new Client({
    connectionString: supabaseConfig.postgresConnectionString
  })

  try {
    await client.connect()
    await client.query(schemaSql)
    console.log('Supabase schema ensured.')
  } catch (err) {
    console.error('Error initializing schema', err)
    throw err
  } finally {
    await client.end()
  }
}

if (process.argv[1] && process.argv[1].includes('initSchema.js')) {
  initSchema()
    .then(() => {
      console.log('Schema init script completed.')
      process.exit(0)
    })
    .catch(() => process.exit(1))
}
