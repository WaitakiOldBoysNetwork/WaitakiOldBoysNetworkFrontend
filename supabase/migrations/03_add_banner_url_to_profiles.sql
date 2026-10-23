-- =============================================================================
-- Migration: Add banner_url to profiles table
-- Description: Adds banner_url and "Banner Photo" columns to support customizable
--              user profile headers and banners across the Waitaki Old Boys Network.
-- =============================================================================

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS banner_url text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS "Banner Photo" text;

-- Bidirectional trigger sync for banner_url and "Banner Photo"
CREATE OR REPLACE FUNCTION public.sync_profile_banner_columns()
RETURNS trigger AS $$
BEGIN
  IF NEW.banner_url IS NOT NULL THEN
    NEW."Banner Photo" := NEW.banner_url;
  ELSIF NEW."Banner Photo" IS NOT NULL THEN
    NEW.banner_url := NEW."Banner Photo";
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_profile_banner ON public.profiles;
CREATE TRIGGER trg_sync_profile_banner
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_profile_banner_columns();
