-- =============================================================================
-- Migration 07: WBHS Noticeboard & Hail.to Articles Integration
-- =============================================================================
-- Description:
--   Creates the public.school_notices table to store official school notices,
--   rector's term updates, and Hail.to publications for the WBHS Noticeboard.
--   Allows real-time updates and manual/automated webhook synchronization.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.school_notices (
  id text PRIMARY KEY,
  title text NOT NULL,
  snippet text NOT NULL,
  badge text NOT NULL DEFAULT 'Hail Article',
  url text NOT NULL,
  image_url text,
  published_at timestamptz NOT NULL DEFAULT NOW(),
  created_at timestamptz NOT NULL DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE public.school_notices ENABLE ROW LEVEL SECURITY;

-- 1. SELECT: Public read access for all students, alumni, and visitors
DROP POLICY IF EXISTS "School notices are viewable by everyone" ON public.school_notices;
CREATE POLICY "School notices are viewable by everyone"
  ON public.school_notices FOR SELECT
  USING (true);

-- 2. INSERT / UPDATE / DELETE: Authenticated admins or service_role only
DROP POLICY IF EXISTS "Only authenticated admins can modify school notices" ON public.school_notices;
CREATE POLICY "Only authenticated admins can modify school notices"
  ON public.school_notices FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- -----------------------------------------------------------------------------
-- Seed Initial WBHS Hail.to Publications & Articles
-- -----------------------------------------------------------------------------
INSERT INTO public.school_notices (id, title, snippet, badge, url, image_url, published_at)
VALUES
  (
    'hail-newsletter-13',
    'Newsletter #13 (2026)',
    'Latest WBHS term updates, academic excellence, winter sports fixtures, and rector’s report.',
    'Hail Newsletter',
    'https://hail.to/waitaki-boys-high-school/publication/gsYrDVH',
    'https://assets.hail-cdn.com/uploads/500-constrained-e8a27443-f8aa-4d8e-a719-c2127b8208a4',
    NOW() - INTERVAL '1 day'
  ),
  (
    'hail-fraser-farm',
    'WBHS Fraser Farm Updates',
    'Student agricultural practicals, farming skills, shearing, and local agribusiness partnerships.',
    'Hail Article',
    'https://hail.to/waitaki-boys-high-school/article/43KIcVB',
    'https://assets.hail-cdn.com/uploads/500-constrained-14ab2602-0fa6-4e9e-aa97-1a4e7690ec84',
    NOW() - INTERVAL '3 days'
  ),
  (
    'hail-leavers-dinner',
    'Senior Leavers'' Dinner & Notices',
    'End-of-year milestone celebrations, Hall of Memories traditions, and valedictory awards.',
    'Hail Notice',
    'https://hail.to/waitaki-boys-high-school/article/kBz9veK',
    'https://assets.hail-cdn.com/uploads/500-constrained-b194435d-f137-4549-bd61-d8bd17deadf7',
    NOW() - INTERVAL '5 days'
  )
ON CONFLICT (id) DO UPDATE
  SET title = EXCLUDED.title,
      snippet = EXCLUDED.snippet,
      badge = EXCLUDED.badge,
      url = EXCLUDED.url,
      image_url = EXCLUDED.image_url;
