-- =============================================================================
-- Trigger: handle_new_user
-- Purpose: Automatically creates or links a profiles row with the user's name,
--          Waitaki house, grad year, location, job, and industry from auth metadata.
--
-- IMPORTANT: Run this in the Supabase SQL Editor (Dashboard > SQL Editor).
-- This ensures that even if client-side operations are interrupted, the profile
-- row is populated with complete onboarding details automatically.
-- =============================================================================

-- Drop existing trigger/function if they exist (safe to re-run)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

-- Create the trigger function
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

-- Create the trigger on auth.users
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();
