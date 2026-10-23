-- =============================================================================
-- Migration 06: Enforce Strict Profile Isolation and Row Level Security (RLS)
-- =============================================================================
-- Description:
--   Fixes profile leakage and account cross-talk by locking down public.profiles
--   so authenticated users can ONLY ever insert, update, or delete rows matching
--   their own authenticated user ID (auth.uid()).
--
-- Vulnerabilities Remediated:
--   1. Replaces permissive "WITH CHECK (auth.uid() IS NOT NULL)" which allowed
--      any logged-in user to modify arbitrary profile rows.
--   2. Enforces (auth.uid() = id OR auth.uid() = user_id) on all mutating operations.
--   3. Guarantees the handle_new_user() trigger only links pre-imported records
--      where user_id IS NULL, preventing account-stealing between users who share
--      an email (e.g., family/alumni members with the same contact address).
-- =============================================================================

-- Ensure RLS is active
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 1. SELECT: Public read for alumni directory
DROP POLICY IF EXISTS "Profiles are readable by everyone" ON public.profiles;
CREATE POLICY "Profiles are readable by everyone"
  ON public.profiles FOR SELECT
  USING (true);

-- 2. INSERT: Users may only insert their own profile matching auth.uid()
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
CREATE POLICY "Users can insert their own profile"
  ON public.profiles FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL AND (
      auth.uid() = id OR
      auth.uid() = user_id
    )
  );

-- 3. UPDATE: Users may ONLY update rows where auth.uid() matches id or user_id
-- (No loose email-based updates permitted from client side; auth.uid() required)
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile"
  ON public.profiles FOR UPDATE
  USING (
    auth.uid() IS NOT NULL AND (
      auth.uid() = id OR
      auth.uid() = user_id
    )
  )
  WITH CHECK (
    auth.uid() IS NOT NULL AND (
      auth.uid() = id OR
      auth.uid() = user_id
    )
  );

-- 4. DELETE: Users may only delete their own profile
DROP POLICY IF EXISTS "Users can delete their own profile" ON public.profiles;
CREATE POLICY "Users can delete their own profile"
  ON public.profiles FOR DELETE
  USING (
    auth.uid() IS NOT NULL AND (
      auth.uid() = id OR
      auth.uid() = user_id
    )
  );

-- -----------------------------------------------------------------------------
-- 5. Hardened handle_new_user() Trigger Function
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  v_first_name text;
  v_last_name text;
  v_grad_year int;
  v_house text;
  v_city text;
  v_headline text;
  v_industry text;
  v_company text;
BEGIN
  v_first_name := COALESCE(NEW.raw_user_meta_data->>'first_name', '');
  v_last_name  := COALESCE(NEW.raw_user_meta_data->>'last_name', '');
  v_grad_year  := (NEW.raw_user_meta_data->>'grad_year')::int;
  v_house      := NEW.raw_user_meta_data->>'house';
  v_city       := NEW.raw_user_meta_data->>'city';
  v_headline   := NEW.raw_user_meta_data->>'headline';
  v_industry   := NEW.raw_user_meta_data->>'industry';
  v_company    := NEW.raw_user_meta_data->>'company';

  -- 1. Try to link an existing pre-imported record matching Email that has NO user_id yet
  -- (Strictly check user_id IS NULL to prevent hijacking an already registered account)
  UPDATE public.profiles
  SET id         = NEW.id,
      user_id    = NEW.id,
      first_name = COALESCE(NULLIF(v_first_name, ''), public.profiles.first_name, ''),
      last_name  = COALESCE(NULLIF(v_last_name, ''), public.profiles.last_name, ''),
      grad_year  = COALESCE(v_grad_year, public.profiles.grad_year),
      house      = COALESCE(NULLIF(v_house, ''), public.profiles.house),
      city       = COALESCE(NULLIF(v_city, ''), public.profiles.city),
      headline   = COALESCE(NULLIF(v_headline, ''), public.profiles.headline),
      industry   = COALESCE(NULLIF(v_industry, ''), public.profiles.industry),
      company    = COALESCE(NULLIF(v_company, ''), public.profiles.company),
      email      = COALESCE(NEW.email, public.profiles.email),
      "Email"    = COALESCE(NEW.email, public.profiles."Email")
  WHERE (LOWER("Email") = LOWER(NEW.email) OR LOWER(email) = LOWER(NEW.email))
    AND user_id IS NULL;

  -- 2. If no existing unclaimed record matched, insert a new profile row strictly for NEW.id
  IF NOT FOUND THEN
    INSERT INTO public.profiles (
      id,
      user_id,
      first_name,
      last_name,
      grad_year,
      house,
      city,
      headline,
      industry,
      company,
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
      v_house,
      v_city,
      v_headline,
      v_industry,
      v_company,
      NEW.email,
      NEW.email,
      NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
      user_id    = EXCLUDED.user_id,
      first_name = COALESCE(NULLIF(EXCLUDED.first_name, ''), NULLIF(public.profiles.first_name, ''), ''),
      last_name  = COALESCE(NULLIF(EXCLUDED.last_name, ''), NULLIF(public.profiles.last_name, ''), ''),
      grad_year  = COALESCE(EXCLUDED.grad_year, public.profiles.grad_year),
      house      = COALESCE(EXCLUDED.house, public.profiles.house),
      city       = COALESCE(EXCLUDED.city, public.profiles.city),
      headline   = COALESCE(EXCLUDED.headline, public.profiles.headline),
      industry   = COALESCE(EXCLUDED.industry, public.profiles.industry),
      company    = COALESCE(EXCLUDED.company, public.profiles.company),
      email      = COALESCE(EXCLUDED.email, public.profiles.email),
      "Email"    = COALESCE(EXCLUDED."Email", public.profiles."Email");
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
