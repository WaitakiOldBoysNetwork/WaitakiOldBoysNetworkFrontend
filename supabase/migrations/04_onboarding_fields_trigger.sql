-- =============================================================================
-- Migration: 04_onboarding_fields_trigger.sql
-- Description: Updates the handle_new_user trigger function to populate onboarding
--              attributes (house, city/location, headline/job, industry, company)
--              from auth.users raw_user_meta_data.
-- =============================================================================

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
  v_last_name := COALESCE(NEW.raw_user_meta_data->>'last_name', '');
  v_grad_year := (NEW.raw_user_meta_data->>'grad_year')::int;
  v_house := NEW.raw_user_meta_data->>'house';
  v_city := NEW.raw_user_meta_data->>'city';
  v_headline := NEW.raw_user_meta_data->>'headline';
  v_industry := NEW.raw_user_meta_data->>'industry';
  v_company := NEW.raw_user_meta_data->>'company';

  -- 1. Try to link an existing pre-imported record matching Email that has no user_id yet
  UPDATE public.profiles
  SET id = NEW.id,
      user_id = NEW.id,
      first_name = COALESCE(NULLIF(v_first_name, ''), public.profiles.first_name, ''),
      last_name = COALESCE(NULLIF(v_last_name, ''), public.profiles.last_name, ''),
      grad_year = COALESCE(v_grad_year, public.profiles.grad_year),
      house = COALESCE(NULLIF(v_house, ''), public.profiles.house),
      city = COALESCE(NULLIF(v_city, ''), public.profiles.city),
      headline = COALESCE(NULLIF(v_headline, ''), public.profiles.headline),
      industry = COALESCE(NULLIF(v_industry, ''), public.profiles.industry),
      company = COALESCE(NULLIF(v_company, ''), public.profiles.company)
  WHERE LOWER("Email") = LOWER(NEW.email) AND (user_id IS NULL OR id IS NULL);

  -- 2. If no existing imported record was matched, insert or upsert
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
      NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
      first_name = COALESCE(
        NULLIF(EXCLUDED.first_name, ''),
        NULLIF(public.profiles.first_name, ''),
        ''
      ),
      last_name = COALESCE(
        NULLIF(EXCLUDED.last_name, ''),
        NULLIF(public.profiles.last_name, ''),
        ''
      ),
      grad_year = COALESCE(EXCLUDED.grad_year, public.profiles.grad_year),
      house = COALESCE(EXCLUDED.house, public.profiles.house),
      city = COALESCE(EXCLUDED.city, public.profiles.city),
      headline = COALESCE(EXCLUDED.headline, public.profiles.headline),
      industry = COALESCE(EXCLUDED.industry, public.profiles.industry),
      company = COALESCE(EXCLUDED.company, public.profiles.company);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
