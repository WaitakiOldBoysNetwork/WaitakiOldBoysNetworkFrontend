-- =============================================================================
-- Migration 08: Placeholder Avatar Image with User Initials for Every New User
-- =============================================================================
-- Description:
--   Ensures that every new user receives an automatic placeholder profile photo
--   generated with their uppercase initials on a WBHS Navy (#0F2547) background
--   with Waitaki Heritage Gold (#D4AF37) text.
--
-- Features:
--   1. Automatically assigns placeholder avatar URL on new user sign-up in handle_new_user().
--   2. Ensures pre-imported records claimed without an existing photo receive the placeholder.
--   3. Backfills all existing profile records in public.profiles lacking an avatar_url.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.generate_initials_avatar_url(
  p_first_name text,
  p_last_name text
)
RETURNS text AS $$
DECLARE
  v_initials text;
BEGIN
  v_initials := UPPER(TRIM(
    COALESCE(SUBSTRING(NULLIF(TRIM(p_first_name), '') FROM 1 FOR 1), '') ||
    COALESCE(SUBSTRING(NULLIF(TRIM(p_last_name), '') FROM 1 FOR 1), '')
  ));

  IF v_initials IS NULL OR v_initials = '' THEN
    v_initials := 'OB';
  END IF;

  RETURN 'https://ui-avatars.com/api/?name=' || v_initials || '&background=0F2547&color=D4AF37&bold=true&size=256';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- -----------------------------------------------------------------------------
-- Update handle_new_user() Trigger to Generate Placeholder Avatar for New Users
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
  v_placeholder_avatar text;
BEGIN
  v_first_name := COALESCE(NEW.raw_user_meta_data->>'first_name', '');
  v_last_name  := COALESCE(NEW.raw_user_meta_data->>'last_name', '');
  v_grad_year  := (NEW.raw_user_meta_data->>'grad_year')::int;
  v_house      := NEW.raw_user_meta_data->>'house';
  v_city       := NEW.raw_user_meta_data->>'city';
  v_headline   := NEW.raw_user_meta_data->>'headline';
  v_industry   := NEW.raw_user_meta_data->>'industry';
  v_company    := NEW.raw_user_meta_data->>'company';

  v_placeholder_avatar := public.generate_initials_avatar_url(v_first_name, v_last_name);

  -- 1. Try to link an existing pre-imported record matching Email that has NO user_id yet
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
      avatar_url = COALESCE(NULLIF(public.profiles.avatar_url, ''), v_placeholder_avatar),
      email      = COALESCE(NEW.email, public.profiles.email),
      "Email"    = COALESCE(NEW.email, public.profiles."Email"),
      updated_at = NOW()
  WHERE public.profiles.id = (
    SELECT p2.id
    FROM public.profiles p2
    WHERE p2.user_id IS NULL
      AND (
        (NEW.email IS NOT NULL AND NEW.email <> '' AND LOWER(p2."Email") = LOWER(NEW.email))
        OR
        (NEW.email IS NOT NULL AND NEW.email <> '' AND LOWER(p2.email) = LOWER(NEW.email))
      )
    ORDER BY p2.created_at ASC
    LIMIT 1
  );

  -- 2. If no existing record was found, insert a brand new profile with the initials placeholder avatar
  IF NOT FOUND THEN
    INSERT INTO public.profiles (
      id, user_id, first_name, last_name, grad_year,
      house, city, headline, industry, company, avatar_url, updated_at
    ) VALUES (
      NEW.id, NEW.id, v_first_name, v_last_name, v_grad_year,
      v_house, v_city, v_headline, v_industry, v_company, v_placeholder_avatar, NOW()
    )
    ON CONFLICT (id) DO UPDATE
      SET user_id    = EXCLUDED.user_id,
          first_name = COALESCE(NULLIF(EXCLUDED.first_name, ''), public.profiles.first_name),
          last_name  = COALESCE(NULLIF(EXCLUDED.last_name, ''), public.profiles.last_name),
          avatar_url = COALESCE(NULLIF(public.profiles.avatar_url, ''), EXCLUDED.avatar_url),
          updated_at = NOW();
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- Backfill Existing Profiles with Initials Placeholder Images
-- -----------------------------------------------------------------------------
UPDATE public.profiles
SET avatar_url = public.generate_initials_avatar_url(first_name, last_name)
WHERE avatar_url IS NULL OR TRIM(avatar_url) = '';
