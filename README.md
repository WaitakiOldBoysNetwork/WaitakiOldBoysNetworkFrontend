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

## Supabase Backend & Database Setup

The complete, production-grade schema and migrations are located in [`supabase/migrations/01_complete_backend_setup.sql`](file:///c:/Users/JakeP/Documents/GitHub/WaitakiOldBoysNetworkFrontend/supabase/migrations/01_complete_backend_setup.sql).

### 1-Click Database Setup in Supabase Dashboard
1. Open your project at [Supabase Dashboard](https://supabase.com/dashboard).
2. Go to **SQL Editor** -> **New Query**.
3. Copy and paste the entire contents of [`supabase/migrations/01_complete_backend_setup.sql`](file:///c:/Users/JakeP/Documents/GitHub/WaitakiOldBoysNetworkFrontend/supabase/migrations/01_complete_backend_setup.sql) and click **Run**.
4. *(Optional)* To seed sample alumni profiles for testing the Directory and Feed screens, run [`supabase/migrations/02_sample_seed_data.sql`](file:///c:/Users/JakeP/Documents/GitHub/WaitakiOldBoysNetworkFrontend/supabase/migrations/02_sample_seed_data.sql).

This automatically configures:
- **`profiles`**: Full schema with dual-compatibility for modern and Airtable columns (`Year left School`, `Region`, `What are you up to`, `Name`, etc.)
- **`posts`**, **`post_likes`**, **`post_comments`**: Post feed, likes toggle, and comment threads
- **`connections`**: Network invitations, status tracking, and participant restrictions
- **Row Level Security (RLS)**: Security policies for all tables allowing directory discovery while locking mutations to owner accounts
- **Storage**: Public `media` bucket with `avatars/` and `posts/` folders & upload policies
- **Auth Triggers & Sync**: Automatic user creation on signup and column bi-directional synchronization
- **Realtime Replication**: Realtime subscriptions enabled for posts, likes, comments, and connections

---

## Production Web Build

To create an optimized production bundle for web hosting (e.g., Cloudflare Pages, Vercel, Firebase Hosting, Netlify, or GitHub Pages):

```bash
flutter build web --release
```

The output will be in `build/web/`.
