# CheckMeOut 🏋️‍♀️

A full-stack iOS app that gamifies fitness and community engagement — think Strava meets Reddit. Track workouts, post daily check-ins, compete on leaderboards, and cheer on friends as they build healthier habits.

Built with SwiftUI and powered by Supabase.

<p align="center">
  <img src="https://github.com/user-attachments/assets/62ebe107-e2da-4058-be59-30dd4955682a" width="300" alt="CheckMeOut screenshot 1" />
  <img src="https://github.com/user-attachments/assets/333ec49d-cd7c-4b5b-ae3d-daac06a14fe8" width="300" alt="CheckMeOut screenshot 2" />
</p>

## Features

- **Real-time workout logging** — Track runs, lifts, and other workouts through a clean SwiftUI interface.
- **Community feed** — Share daily check-ins, comment, and react to friends' progress.
- **Global & friend leaderboards** — Climb the ranks based on activity score and daily consistency.
- **Secure auth & storage** — Email/password, Google OAuth, and real-time sync via Supabase + PostgreSQL.
- **Gamified health journey** — Points, streaks, and badges designed to keep you (and your friends) moving.

## Tech Stack

| Layer            | Technology                                      |
| ---------------- | ----------------------------------------------- |
| Frontend         | SwiftUI                                         |
| Backend          | Supabase Edge Functions, Supabase RPC           |
| Database         | PostgreSQL                                      |
| Auth & Storage   | Supabase Auth, Supabase Storage, Google OAuth   |

## Getting Started

### 1. Clone the repo

```bash
git clone https://github.com/anshulkc/check-me-out.git
cd check-me-out
```

### 2. Open in Xcode

Open `CheckMeOut.xcodeproj` (or `CheckMeOut.xcworkspace` if using Swift Packages).

### 3. Configure Supabase

Add your Supabase URL and anon key to the project's configuration file. *(See `Config.example.swift` for the expected format.)*

### 4. Run

Build and run on the iOS Simulator or a physical device (⌘R).

## License

MIT
