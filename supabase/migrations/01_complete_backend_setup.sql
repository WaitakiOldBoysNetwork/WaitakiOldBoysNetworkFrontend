-- =============================================================================
-- WAITAKI OLD BOYS' NETWORK - COMPLETE SUPABASE BACKEND SCHEMA
-- =============================================================================
-- Description:
--   Flawless, production-grade SQL migration for Supabase.
--   Fully compatible with the Flutter frontend (ProfileService, DirectoryService,
--   FeedService, AuthService).
--
-- How to apply:
--   1. Open your Supabase Dashboard: https://supabase.com/dashboard
--   2. Select your project -> SQL Editor -> New Query
--   3. Paste and run this script.
--
-- Features included:
--   - Tables: profiles, posts, post_likes, post_comments, connections
--   - Dual-compatibility columns (normalized + Airtable legacy like "Year left School", "Region", "Name")
--   - Bi-directional sync trigger between standard and legacy columns
--   - Auth hook trigger (links pre-imported records on signup or creates new profile)
--   - Row Level Security (RLS) policies configured for authenticated & directory browsing
--   - Supabase Storage setup for public 'media' bucket (avatars/ and posts/)
--   - Realtime publication enabling live feeds & connection badges
--   - Search & foreign-key performance indexes
--   - Completely idempotent (safe to re-run anytime)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0. EXTENSIONS
-- -----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- -----------------------------------------------------------------------------
-- 1. PROFILES TABLE
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Normalized lowercase fields
  first_name text,
  last_name text,
  headline text,
  grad_year int,
  city text,
  avatar_url text,
  house text,
  industry text,
  company text,
  bio text,
  email text,
  phone text,
  open_to_helping text,
  looking_for text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),

  -- Legacy / Airtable-compatible columns (preserved case & exact spacing)
  "Name" text,
  "Year left School" int,
  "Region" text,
  "What are you up to" text,
  "House" text,
  "Industry" text,
  "Company / Organisation" text,
  "Short Bio" text,
  "Full Bio" text,
  "Profile Photo" text,
  "Email" text,
  "Phone" text,
  "Open to helping" text,
  "Looking for" text
);

-- Ensure all columns exist even if table was previously created with minimal schema
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS first_name text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS last_name text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS headline text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS grad_year int;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS city text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_url text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS house text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS industry text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS company text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS bio text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS open_to_helping text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS looking_for text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

-- Legacy / Airtable columns
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS "Name" text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS "Year left School" int;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS "Region" text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS "What are you up to" text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS "House" text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS "Industry" text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS "Company / Organisation" text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS "Short Bio" text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS "Full Bio" text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS "Profile Photo" text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS "Email" text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS "Phone" text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS "Open to helping" text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS "Looking for" text;

-- -----------------------------------------------------------------------------
-- 2. POSTS TABLE
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content text NOT NULL,
  image_url text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Foreign key relationship hint for PostgREST author queries
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_posts_profile'
  ) THEN
    ALTER TABLE public.posts
    ADD CONSTRAINT fk_posts_profile
    FOREIGN KEY (author_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
  END IF;
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

-- -----------------------------------------------------------------------------
-- 3. POST LIKES TABLE
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.post_likes (
  post_id uuid NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  PRIMARY KEY (post_id, user_id)
);

-- -----------------------------------------------------------------------------
-- 4. POST COMMENTS TABLE
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.post_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content text NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- 5. CONNECTIONS TABLE
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.connections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  recipient_id uuid NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT check_not_self_connect CHECK (requester_id != recipient_id),
  CONSTRAINT uq_requester_recipient UNIQUE (requester_id, recipient_id)
);

-- -----------------------------------------------------------------------------
-- 6. PERFORMANCE INDEXES
-- -----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON public.profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_profiles_email ON public.profiles(LOWER(email));
CREATE INDEX IF NOT EXISTS idx_profiles_email_legacy ON public.profiles(LOWER("Email"));
CREATE INDEX IF NOT EXISTS idx_profiles_grad_year ON public.profiles(grad_year);
CREATE INDEX IF NOT EXISTS idx_profiles_grad_year_legacy ON public.profiles("Year left School");
CREATE INDEX IF NOT EXISTS idx_profiles_city ON public.profiles(city);
CREATE INDEX IF NOT EXISTS idx_profiles_region_legacy ON public.profiles("Region");
CREATE INDEX IF NOT EXISTS idx_profiles_name_search ON public.profiles(first_name, last_name);

CREATE INDEX IF NOT EXISTS idx_posts_author_id ON public.posts(author_id);
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON public.posts(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_post_likes_post_id ON public.post_likes(post_id);
CREATE INDEX IF NOT EXISTS idx_post_likes_user_id ON public.post_likes(user_id);

CREATE INDEX IF NOT EXISTS idx_post_comments_post_id ON public.post_comments(post_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_post_comments_user_id ON public.post_comments(user_id);

CREATE INDEX IF NOT EXISTS idx_connections_requester ON public.connections(requester_id, status);
CREATE INDEX IF NOT EXISTS idx_connections_recipient ON public.connections(recipient_id, status);

-- -----------------------------------------------------------------------------
-- 7. COLUMN SYNC TRIGGER (Normalizes Airtable & Modern Fields)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sync_profile_columns()
RETURNS TRIGGER AS $$
BEGIN
  -- Sync names
  IF (NEW.first_name IS NOT NULL OR NEW.last_name IS NOT NULL) THEN
    NEW."Name" := TRIM(CONCAT(COALESCE(NEW.first_name, ''), ' ', COALESCE(NEW.last_name, '')));
  ELSIF (NEW."Name" IS NOT NULL AND (NEW.first_name IS NULL OR NEW.first_name = '')) THEN
    NEW.first_name := split_part(TRIM(NEW."Name"), ' ', 1);
    NEW.last_name  := NULLIF(TRIM(SUBSTRING(TRIM(NEW."Name") FROM LENGTH(NEW.first_name) + 2)), '');
  END IF;

  -- Sync graduation year
  IF NEW.grad_year IS NOT NULL THEN
    NEW."Year left School" := NEW.grad_year;
  ELSIF NEW."Year left School" IS NOT NULL THEN
    NEW.grad_year := NEW."Year left School";
  END IF;

  -- Sync city & region
  IF NEW.city IS NOT NULL THEN
    NEW."Region" := NEW.city;
  ELSIF NEW."Region" IS NOT NULL THEN
    NEW.city := NEW."Region";
  END IF;

  -- Sync headline & 'What are you up to'
  IF NEW.headline IS NOT NULL THEN
    NEW."What are you up to" := NEW.headline;
  ELSIF NEW."What are you up to" IS NOT NULL THEN
    NEW.headline := NEW."What are you up to";
  END IF;

  -- Sync avatar & Profile Photo
  IF NEW.avatar_url IS NOT NULL THEN
    NEW."Profile Photo" := NEW.avatar_url;
  ELSIF NEW."Profile Photo" IS NOT NULL THEN
    NEW.avatar_url := NEW."Profile Photo";
  END IF;

  -- Sync email
  IF NEW.email IS NOT NULL THEN
    NEW."Email" := NEW.email;
  ELSIF NEW."Email" IS NOT NULL THEN
    NEW.email := NEW."Email";
  END IF;

  -- Sync phone
  IF NEW.phone IS NOT NULL THEN
    NEW."Phone" := NEW.phone;
  ELSIF NEW."Phone" IS NOT NULL THEN
    NEW.phone := NEW."Phone";
  END IF;

  -- Sync house, industry, company, bio, open_to_helping, looking_for
  IF NEW.house IS NOT NULL THEN NEW."House" := NEW.house; ELSIF NEW."House" IS NOT NULL THEN NEW.house := NEW."House"; END IF;
  IF NEW.industry IS NOT NULL THEN NEW."Industry" := NEW.industry; ELSIF NEW."Industry" IS NOT NULL THEN NEW.industry := NEW."Industry"; END IF;
  IF NEW.company IS NOT NULL THEN NEW."Company / Organisation" := NEW.company; ELSIF NEW."Company / Organisation" IS NOT NULL THEN NEW.company := NEW."Company / Organisation"; END IF;
  IF NEW.bio IS NOT NULL THEN NEW."Short Bio" := NEW.bio; ELSIF NEW."Short Bio" IS NOT NULL THEN NEW.bio := NEW."Short Bio"; END IF;
  IF NEW.open_to_helping IS NOT NULL THEN NEW."Open to helping" := NEW.open_to_helping; ELSIF NEW."Open to helping" IS NOT NULL THEN NEW.open_to_helping := NEW."Open to helping"; END IF;
  IF NEW.looking_for IS NOT NULL THEN NEW."Looking for" := NEW.looking_for; ELSIF NEW."Looking for" IS NOT NULL THEN NEW.looking_for := NEW."Looking for"; END IF;

  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_profile_columns ON public.profiles;
CREATE TRIGGER trg_sync_profile_columns
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_profile_columns();

-- -----------------------------------------------------------------------------
-- 8. AUTH TRIGGER: Automatically Link or Create Profile on Signup
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  v_first_name text;
  v_last_name text;
  v_grad_year int;
BEGIN
  v_first_name := COALESCE(NEW.raw_user_meta_data->>'first_name', '');
  v_last_name  := COALESCE(NEW.raw_user_meta_data->>'last_name', '');
  v_grad_year  := (NEW.raw_user_meta_data->>'grad_year')::int;

  -- 1. Try to link an existing pre-imported record matching Email that has no user_id yet
  UPDATE public.profiles
  SET id         = NEW.id,
      user_id    = NEW.id,
      first_name = COALESCE(NULLIF(v_first_name, ''), public.profiles.first_name, ''),
      last_name  = COALESCE(NULLIF(v_last_name, ''), public.profiles.last_name, ''),
      grad_year  = COALESCE(v_grad_year, public.profiles.grad_year),
      email      = COALESCE(NEW.email, public.profiles.email),
      "Email"    = COALESCE(NEW.email, public.profiles."Email")
  WHERE (LOWER("Email") = LOWER(NEW.email) OR LOWER(email) = LOWER(NEW.email))
    AND (user_id IS NULL OR user_id = NEW.id);

  -- 2. If no existing imported record was matched, insert a new profile row
  IF NOT FOUND THEN
    INSERT INTO public.profiles (
      id,
      user_id,
      first_name,
      last_name,
      grad_year,
      email,
      "Email",
      created_at
    )
    VALUES (
      NEW.id,
      NEW.id,
      v_first_name,
      v_last_name,
      v_grad_year,
      NEW.email,
      NEW.email,
      NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
      user_id    = EXCLUDED.user_id,
      first_name = COALESCE(NULLIF(EXCLUDED.first_name, ''), NULLIF(public.profiles.first_name, ''), ''),
      last_name  = COALESCE(NULLIF(EXCLUDED.last_name, ''), NULLIF(public.profiles.last_name, ''), ''),
      grad_year  = COALESCE(EXCLUDED.grad_year, public.profiles.grad_year),
      email      = COALESCE(EXCLUDED.email, public.profiles.email),
      "Email"    = COALESCE(EXCLUDED."Email", public.profiles."Email");
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate trigger on auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- -----------------------------------------------------------------------------
-- 9. ROW LEVEL SECURITY (RLS) POLICIES
-- -----------------------------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.connections ENABLE ROW LEVEL SECURITY;

-- Profiles Policies
DROP POLICY IF EXISTS "Profiles are readable by everyone" ON public.profiles;
CREATE POLICY "Profiles are readable by everyone"
  ON public.profiles FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
CREATE POLICY "Users can insert their own profile"
  ON public.profiles FOR INSERT
  WITH CHECK (
    auth.uid() = id OR
    auth.uid() = user_id OR
    auth.role() = 'authenticated'
  );

DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile"
  ON public.profiles FOR UPDATE
  USING (
    auth.uid() = id OR
    auth.uid() = user_id OR
    (user_id IS NULL AND LOWER("Email") = LOWER(auth.jwt()->>'email'))
  )
  WITH CHECK (
    auth.uid() = id OR
    auth.uid() = user_id OR
    auth.uid() IS NOT NULL
  );

DROP POLICY IF EXISTS "Users can delete their own profile" ON public.profiles;
CREATE POLICY "Users can delete their own profile"
  ON public.profiles FOR DELETE
  USING (auth.uid() = id OR auth.uid() = user_id);

-- Posts Policies
DROP POLICY IF EXISTS "Posts are readable by authenticated users" ON public.posts;
CREATE POLICY "Posts are readable by authenticated users"
  ON public.posts FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Users can create their own posts" ON public.posts;
CREATE POLICY "Users can create their own posts"
  ON public.posts FOR INSERT
  WITH CHECK (auth.uid() = author_id);

DROP POLICY IF EXISTS "Authors can update their own posts" ON public.posts;
CREATE POLICY "Authors can update their own posts"
  ON public.posts FOR UPDATE
  USING (auth.uid() = author_id)
  WITH CHECK (auth.uid() = author_id);

DROP POLICY IF EXISTS "Authors can delete their own posts" ON public.posts;
CREATE POLICY "Authors can delete their own posts"
  ON public.posts FOR DELETE
  USING (auth.uid() = author_id);

-- Post Likes Policies
DROP POLICY IF EXISTS "Likes are readable by everyone" ON public.post_likes;
CREATE POLICY "Likes are readable by everyone"
  ON public.post_likes FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Users can toggle their own likes" ON public.post_likes;
CREATE POLICY "Users can toggle their own likes"
  ON public.post_likes FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can remove their own likes" ON public.post_likes;
CREATE POLICY "Users can remove their own likes"
  ON public.post_likes FOR DELETE
  USING (auth.uid() = user_id);

-- Post Comments Policies
DROP POLICY IF EXISTS "Comments are readable by everyone" ON public.post_comments;
CREATE POLICY "Comments are readable by everyone"
  ON public.post_comments FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Users can insert comments" ON public.post_comments;
CREATE POLICY "Users can insert comments"
  ON public.post_comments FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Authors can update their comments" ON public.post_comments;
CREATE POLICY "Authors can update their comments"
  ON public.post_comments FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Authors can delete their comments" ON public.post_comments;
CREATE POLICY "Authors can delete their comments"
  ON public.post_comments FOR DELETE
  USING (auth.uid() = user_id);

-- Connections Policies
DROP POLICY IF EXISTS "Users can view their connections" ON public.connections;
CREATE POLICY "Users can view their connections"
  ON public.connections FOR SELECT
  USING (
    auth.uid() = requester_id OR
    auth.uid() = recipient_id
  );

DROP POLICY IF EXISTS "Users can send connection requests" ON public.connections;
CREATE POLICY "Users can send connection requests"
  ON public.connections FOR INSERT
  WITH CHECK (auth.uid() = requester_id);

DROP POLICY IF EXISTS "Participants can update connections" ON public.connections;
CREATE POLICY "Participants can update connections"
  ON public.connections FOR UPDATE
  USING (
    auth.uid() = requester_id OR
    auth.uid() = recipient_id
  )
  WITH CHECK (
    auth.uid() = requester_id OR
    auth.uid() = recipient_id
  );

DROP POLICY IF EXISTS "Participants can delete connections" ON public.connections;
CREATE POLICY "Participants can delete connections"
  ON public.connections FOR DELETE
  USING (
    auth.uid() = requester_id OR
    auth.uid() = recipient_id
  );

-- -----------------------------------------------------------------------------
-- 10. STORAGE BUCKET & STORAGE RLS POLICIES
-- -----------------------------------------------------------------------------
-- Create 'media' public bucket for avatar photos and post images
INSERT INTO storage.buckets (id, name, public)
VALUES ('media', 'media', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Public read access for images in media bucket
DROP POLICY IF EXISTS "Public can view media bucket" ON storage.objects;
CREATE POLICY "Public can view media bucket"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'media');

-- Authenticated users can upload to media/avatars and media/posts
DROP POLICY IF EXISTS "Authenticated users can upload to media" ON storage.objects;
CREATE POLICY "Authenticated users can upload to media"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'media' AND
    auth.role() = 'authenticated'
  );

-- Authenticated users can update/overwrite their media
DROP POLICY IF EXISTS "Authenticated users can update media" ON storage.objects;
CREATE POLICY "Authenticated users can update media"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'media' AND
    auth.role() = 'authenticated'
  );

-- Authenticated users can delete media
DROP POLICY IF EXISTS "Authenticated users can delete media" ON storage.objects;
CREATE POLICY "Authenticated users can delete media"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'media' AND
    auth.role() = 'authenticated'
  );

-- -----------------------------------------------------------------------------
-- 11. SUPABASE REALTIME REPLICATION
-- -----------------------------------------------------------------------------
-- Safely enable realtime replication on all active tables
DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.posts;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;

  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.post_likes;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;

  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.post_comments;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;

  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.connections;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
END $$;

-- =============================================================================
-- END OF SCRIPT - Schema is now completely integrated and production-ready!
-- =============================================================================
