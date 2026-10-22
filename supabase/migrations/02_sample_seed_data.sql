-- =============================================================================
-- OPTIONAL SEED DATA: WAITAKI OLD BOYS' NETWORK
-- =============================================================================
-- Run this in the Supabase SQL Editor if you want to populate your database with
-- sample alumni profiles for testing the Directory and Feed screens immediately.
-- =============================================================================

INSERT INTO public.profiles (
  id,
  first_name,
  last_name,
  grad_year,
  city,
  headline,
  house,
  industry,
  company,
  bio,
  avatar_url,
  created_at
)
VALUES
  (
    'a0000000-0000-0000-0000-000000000001',
    'Hamish',
    'MacKenzie',
    2014,
    'Oamaru',
    'AgriTech Founder & Merino Farming Director',
    'Don',
    'Agriculture & Technology',
    'Waitaki Valley Wool Co',
    'Passionate about sustainable pastoral farming and robotics in agriculture. Proud WBHS Old Boy.',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&auto=format&fit=crop&q=80',
    NOW() - INTERVAL '30 days'
  ),
  (
    'a0000000-0000-0000-0000-000000000002',
    'David',
    'Sutherland',
    2018,
    'Wellington',
    'Senior Policy Advisor at Ministry of Foreign Affairs',
    'Forrester',
    'Government & Public Policy',
    'MFAT New Zealand',
    'WBHS 2018. Former Head Boy and 1st XV lock. Working in international trade & relations.',
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300&auto=format&fit=crop&q=80',
    NOW() - INTERVAL '20 days'
  ),
  (
    'a0000000-0000-0000-0000-000000000003',
    'Jack',
    'Kilmister',
    2020,
    'Christchurch',
    'Civil Engineer & Infrastructure Project Lead',
    'Lee',
    'Engineering & Construction',
    'Fulton Hogan',
    'Specializing in seismic design and bridge engineering across the South Island.',
    'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=300&auto=format&fit=crop&q=80',
    NOW() - INTERVAL '15 days'
  ),
  (
    'a0000000-0000-0000-0000-000000000004',
    'Thomas',
    'Reid',
    2008,
    'Auckland',
    'Commercial Partner & Tech Litigation Specialist',
    'Sutherland',
    'Legal Services',
    'Bell Gully',
    'Advising high-growth startups and venture capital firms. Always keen to mentor young Old Boys in law.',
    'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=300&auto=format&fit=crop&q=80',
    NOW() - INTERVAL '10 days'
  ),
  (
    'a0000000-0000-0000-0000-000000000005',
    'Angus',
    'Fraser',
    2022,
    'Dunedin',
    'Medical Student at University of Otago',
    'Don',
    'Healthcare & Medicine',
    'Otago Medical School',
    '3rd year med student. Keen rower and rugby supporter.',
    'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=300&auto=format&fit=crop&q=80',
    NOW() - INTERVAL '5 days'
  )
ON CONFLICT (id) DO NOTHING;
