# Supabase Storage: `memories` bucket

Create a **public** bucket named `memories` in Supabase Dashboard → Storage.

If uploads fail with permission errors, run in SQL Editor:

```sql
INSERT INTO storage.buckets (id, name, public)
VALUES ('memories', 'memories', true)
ON CONFLICT (id) DO UPDATE SET public = true;
```

The API uploads files using the service role, so client policies are optional for uploads.
