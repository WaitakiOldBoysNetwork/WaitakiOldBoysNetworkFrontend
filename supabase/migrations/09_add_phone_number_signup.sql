-- =============================================================================
-- Migration 09: Add Phone Number Support to Signup & Profile Handling
-- =============================================================================
-- Description:
--   Ensures that phone numbers submitted during signup (via auth user metadata)
--   are automatically propagated into public.profiles (both the normalized 'phone'
--   column and the Airtable-compatible 'Phone' column).
--
-- Features:
--   1. Ensures 'phone' and 'Phone' columns exist on public.profiles.
--   2. Updates handle_new_user() trigger to extract 'phone' from raw_user_meta_data.
--   3. Automatically updates or inserts phone number for newly registered Old Boys.
-- =============================================================================

-- 1. Ensure phone columns exist
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS "Phone" text;

-- 2. Update handle_new_user() Trigger to persist phone number
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
  v_phone text;
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
  v_phone      := NULLIF(TRIM(NEW.raw_user_meta_data->>'phone'), '');

  -- Generate placeholder avatar with user initials in Waitaki Navy (#0F2547) & Gold (#D4AF37)
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'generate_initials_avatar_url') THEN
    v_placeholder_avatar := public.generate_initials_avatar_url(v_first_name, v_last_name);
  ELSE
    v_placeholder_avatar := 'https://ui-avatars.com/api/?name=' ||
      UPPER(SUBSTRING(COALESCE(NULLIF(TRIM(v_first_name), ''), 'O') FROM 1 FOR 1) ||
            SUBSTRING(COALESCE(NULLIF(TRIM(v_last_name), ''), 'B') FROM 1 FOR 1)) ||
      '&background=0F2547&color=D4AF37&bold=true&size=256';
  END IF;

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
      phone      = COALESCE(v_phone, public.profiles.phone),
      "Phone"    = COALESCE(v_phone, public.profiles."Phone"),
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

  -- 2. If no existing record was found, insert a brand new profile
  IF NOT FOUND THEN
    INSERT INTO public.profiles (
      id, user_id, first_name, last_name, grad_year,
      house, city, headline, industry, company, phone, "Phone",
      avatar_url, email, "Email", updated_at
    ) VALUES (
      NEW.id, NEW.id, v_first_name, v_last_name, v_grad_year,
      v_house, v_city, v_headline, v_industry, v_company, v_phone, v_phone,
      v_placeholder_avatar, NEW.email, NEW.email, NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
      first_name = EXCLUDED.first_name,
      last_name  = EXCLUDED.last_name,
      grad_year  = COALESCE(EXCLUDED.grad_year, public.profiles.grad_year),
      phone      = COALESCE(EXCLUDED.phone, public.profiles.phone),
      "Phone"    = COALESCE(EXCLUDED."Phone", public.profiles."Phone"),
      avatar_url = COALESCE(NULLIF(public.profiles.avatar_url, ''), EXCLUDED.avatar_url),
      updated_at = NOW();
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
