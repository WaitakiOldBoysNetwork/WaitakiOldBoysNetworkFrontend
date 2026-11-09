-- =============================================================================
-- Migration 11: Add share_phone_on_profile to Profiles
-- =============================================================================
-- Description:
--   Adds the boolean column `share_phone_on_profile` (default false) to
--   `public.profiles` so users can control whether their phone number is
--   visible on their profile. Also updates `handle_new_user()` to persist
--   `age`, `is_onboarded`, and `share_phone_on_profile` from auth metadata
--   and match pre-imported profiles by email or phone.
-- =============================================================================

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS share_phone_on_profile boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.profiles.share_phone_on_profile IS 'True when the user has opted in to sharing their contact info (email and phone number) on their profile';

-- Update handle_new_user() trigger to persist share_phone_on_profile, age, and is_onboarded
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  v_first_name text;
  v_last_name text;
  v_grad_year int;
  v_age int;
  v_house text;
  v_city text;
  v_headline text;
  v_industry text;
  v_company text;
  v_phone text;
  v_share_phone boolean;
  v_is_onboarded boolean;
  v_placeholder_avatar text;
BEGIN
  v_first_name   := COALESCE(NEW.raw_user_meta_data->>'first_name', '');
  v_last_name    := COALESCE(NEW.raw_user_meta_data->>'last_name', '');
  v_grad_year    := (NEW.raw_user_meta_data->>'grad_year')::int;
  v_age          := (NEW.raw_user_meta_data->>'age')::int;
  v_house        := NEW.raw_user_meta_data->>'house';
  v_city         := NEW.raw_user_meta_data->>'city';
  v_headline     := NEW.raw_user_meta_data->>'headline';
  v_industry     := NEW.raw_user_meta_data->>'industry';
  v_company      := NEW.raw_user_meta_data->>'company';
  v_phone        := NULLIF(TRIM(NEW.raw_user_meta_data->>'phone'), '');
  v_share_phone  := COALESCE((NEW.raw_user_meta_data->>'share_phone_on_profile')::boolean, false);
  v_is_onboarded := COALESCE((NEW.raw_user_meta_data->>'is_onboarded')::boolean, false);

  -- Generate placeholder avatar with user initials in Waitaki Navy (#0F2547) & Gold (#D4AF37)
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'generate_initials_avatar_url') THEN
    v_placeholder_avatar := public.generate_initials_avatar_url(v_first_name, v_last_name);
  ELSE
    v_placeholder_avatar := 'https://ui-avatars.com/api/?name=' ||
      UPPER(SUBSTRING(COALESCE(NULLIF(TRIM(v_first_name), ''), 'O') FROM 1 FOR 1) ||
            SUBSTRING(COALESCE(NULLIF(TRIM(v_last_name), ''), 'B') FROM 1 FOR 1)) ||
      '&background=0F2547&color=D4AF37&bold=true&size=256';
  END IF;

  -- 1. Try to link an existing pre-imported record matching Email or Phone that has NO user_id yet
  UPDATE public.profiles
  SET id                     = NEW.id,
      user_id                = NEW.id,
      first_name             = COALESCE(NULLIF(v_first_name, ''), public.profiles.first_name, ''),
      last_name              = COALESCE(NULLIF(v_last_name, ''), public.profiles.last_name, ''),
      grad_year              = COALESCE(v_grad_year, public.profiles.grad_year),
      age                    = COALESCE(v_age, public.profiles.age),
      house                  = COALESCE(NULLIF(v_house, ''), public.profiles.house),
      city                   = COALESCE(NULLIF(v_city, ''), public.profiles.city),
      headline               = COALESCE(NULLIF(v_headline, ''), public.profiles.headline),
      industry               = COALESCE(NULLIF(v_industry, ''), public.profiles.industry),
      company                = COALESCE(NULLIF(v_company, ''), public.profiles.company),
      phone                  = COALESCE(v_phone, public.profiles.phone),
      "Phone"                = COALESCE(v_phone, public.profiles."Phone"),
      share_phone_on_profile = COALESCE(v_share_phone, public.profiles.share_phone_on_profile, false),
      is_onboarded           = COALESCE(v_is_onboarded, public.profiles.is_onboarded, false),
      avatar_url             = COALESCE(NULLIF(public.profiles.avatar_url, ''), v_placeholder_avatar),
      email                  = COALESCE(NEW.email, public.profiles.email),
      "Email"                = COALESCE(NEW.email, public.profiles."Email"),
      updated_at             = NOW()
  WHERE public.profiles.id = (
    SELECT p2.id
    FROM public.profiles p2
    WHERE p2.user_id IS NULL
      AND (
        (NEW.email IS NOT NULL AND NEW.email <> '' AND (LOWER(p2."Email") = LOWER(NEW.email) OR LOWER(p2.email) = LOWER(NEW.email)))
        OR
        (v_phone IS NOT NULL AND v_phone <> '' AND (p2."Phone" = v_phone OR p2.phone = v_phone))
      )
    ORDER BY p2.created_at ASC
    LIMIT 1
  );

  -- 2. If no existing record was found, insert a brand new profile
  IF NOT FOUND THEN
    INSERT INTO public.profiles (
      id, user_id, first_name, last_name, grad_year, age,
      house, city, headline, industry, company, phone, "Phone",
      share_phone_on_profile, is_onboarded,
      avatar_url, email, "Email", updated_at
    ) VALUES (
      NEW.id, NEW.id, v_first_name, v_last_name, v_grad_year, v_age,
      v_house, v_city, v_headline, v_industry, v_company, v_phone, v_phone,
      v_share_phone, v_is_onboarded,
      v_placeholder_avatar, NEW.email, NEW.email, NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
      first_name             = EXCLUDED.first_name,
      last_name              = EXCLUDED.last_name,
      grad_year              = COALESCE(EXCLUDED.grad_year, public.profiles.grad_year),
      age                    = COALESCE(EXCLUDED.age, public.profiles.age),
      phone                  = COALESCE(EXCLUDED.phone, public.profiles.phone),
      "Phone"                = COALESCE(EXCLUDED."Phone", public.profiles."Phone"),
      share_phone_on_profile = COALESCE(EXCLUDED.share_phone_on_profile, public.profiles.share_phone_on_profile, false),
      is_onboarded           = COALESCE(EXCLUDED.is_onboarded, public.profiles.is_onboarded, false),
      avatar_url             = COALESCE(NULLIF(public.profiles.avatar_url, ''), EXCLUDED.avatar_url),
      updated_at             = NOW();
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
