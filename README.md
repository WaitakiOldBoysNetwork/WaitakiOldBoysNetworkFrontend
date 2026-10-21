# Waitaki Old Boys' Network (Frontend)

A LinkedIn-style Old Boys networking application built with **Flutter** (Web & Cross-Platform) and backed by **Supabase** (PostgreSQL, Auth, Storage, and RLS).

---

## Features

- **Auth & Session Gate (`AuthGate`)**:
  - Email/Password login and registration.
  - Magic-link / OTP authentication.
  - Automatic session restoration with Supabase Auth streams.
  - Automatic account linking with pre-imported records matching Old Boys email.

- **Old Boys Feed (`FeedScreen`)**:
  - Chronological post stream with author avatar, graduation year badge (`'14`), headline, and relative timestamps.
  - Media photo attachments cached with `cached_network_image`.
  - Optimistic like toggle (`post_likes`) with real-time counters.
  - Comments modal sheet (`post_comments`) with live discussion and entry.
  - Cross-platform post composer with image picker (`image_picker`) uploading to Supabase Storage `media/posts/`.

- **Old Boys Directory (`DirectoryScreen`)**:
  - Displays registered Old Boys who have active accounts on the network.
  - Real-time search by name, profession, or company.
  - Graduation year filter chips (e.g. `2024`, `2020`, `2015`, `2010`, `2000`, etc.).
  - Networking actions: send connection request, view pending state, or connected badge.

- **My Network (`ConnectionsScreen`)**:
  - Incoming Invitations: accept or ignore connection requests.
  - Connected Old Boys: browse your active network.

- **My Profile (`ProfileScreen`)**:
  - WBHS Navy & Old Gold heritage banner.
  - Avatar management: pick and upload photos directly to Supabase `media/avatars/`.
  - Inline profile editor for name, headline, graduation year, and city.

---

## Getting Started & Running Locally

### Option 1: 1-Click Run in IDE
Open this project in your IDE (Antigravity IDE / VS Code) and press **F5** (or navigate to **Run and Debug** in the sidebar) and select:
- **Waitaki Old Boys (Chrome Web)**
- **Waitaki Old Boys (Windows Desktop)**
- **Waitaki Old Boys (Edge Web)**

### Option 2: Terminal
Open a terminal in the project directory (`Ctrl + ~`) and run:

```bash
# Run in Google Chrome
flutter run -d chrome

# Run as native Windows Desktop app
flutter run -d windows

# Run in Edge
flutter run -d edge
```

---

## Supabase Schema Reference

The app connects to your Supabase project defined in `lib/core/constants/supabase_config.dart`. Ensure the following tables and buckets are configured:

```sql
-- 1. Profiles Table
CREATE TABLE public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  first_name text,
  last_name text,
  headline text,
  grad_year int,
  city text,
  avatar_url text,
  created_at timestamptz DEFAULT now()
);

-- 2. Connections Table
CREATE TYPE connection_status AS ENUM ('pending', 'accepted', 'rejected');

CREATE TABLE public.connections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  recipient_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  status connection_status DEFAULT 'pending',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- 3. Posts Table
CREATE TABLE public.posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  content text NOT NULL,
  image_url text,
  created_at timestamptz DEFAULT now()
);

-- 4. Likes & Comments
CREATE TABLE public.post_likes (
  post_id uuid REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  PRIMARY KEY (post_id, user_id)
);

CREATE TABLE public.post_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  content text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- 5. Storage Bucket
-- Ensure a public bucket named 'media' exists with folders 'avatars/' and 'posts/'
```

---

## Production Web Build

To create an optimized production bundle for web hosting (e.g., Cloudflare Pages, Vercel, Firebase Hosting, Netlify, or GitHub Pages):

```bash
flutter build web --release
```

The output will be in `build/web/`.
