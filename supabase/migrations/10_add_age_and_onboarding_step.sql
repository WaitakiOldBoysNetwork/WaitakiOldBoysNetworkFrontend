-- Migration 10: Add Age and Onboarding Progress Tracking to Profiles
-- Allows multi-step onboarding wizard progress tracking and directory age filtering.

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS age int;

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS is_onboarded boolean DEFAULT false;

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS onboarding_step int DEFAULT 1;

-- Index age for fast directory lookups
CREATE INDEX IF NOT EXISTS idx_profiles_age ON public.profiles(age);
CREATE INDEX IF NOT EXISTS idx_profiles_is_onboarded ON public.profiles(is_onboarded);

COMMENT ON COLUMN public.profiles.age IS 'Alumnus age (13-100)';
COMMENT ON COLUMN public.profiles.is_onboarded IS 'True if onboarding completed';
COMMENT ON COLUMN public.profiles.onboarding_step IS 'Current incomplete onboarding wizard step (1, 2, or 3)';
