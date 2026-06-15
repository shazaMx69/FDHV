-- Run in Supabase SQL Editor if family tree add fails (missing created_at).
ALTER TABLE family_tree_nodes
  ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();

ALTER TABLE family_relationships
  ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
