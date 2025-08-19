# AI Calories Tracker

[![Flutter](https://img.shields.io/badge/Flutter-%E2%89%A5%203.0-blue)](https://flutter.dev)  [![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Desktop-green)]()  [![License](https://img.shields.io/badge/License-MIT-lightgrey)](./LICENSE)

A lightweight Flutter app that recognizes foods from photos (Clarifai), fetches nutrition facts (USDA FoodData Central), and helps you track daily calories and macros. Uses Supabase as backend for auth and storing meals.

---

## Demo

<p align="center">
  <img src="livedemoimages/showcase.gif" alt="AI_Calories_Tracker demo" style="max-width:100%; width:260px; height:560px; border-radius:8px;" />
</p>

<img src="./livedemoimages/1.png" width="180" style="margin-right: 10px;" />   <img src="./livedemoimages/2.png" width="180" style="margin-right: 100px;" />   <img src="./livedemoimages/3.png" width="180" style="margin-right: 100px;" />   <img src="./livedemoimages/4.png" width="180" style="margin-right: 100px;" />   <img src="./livedemoimages/5.png" width="180" style="margin-right: 100px;" />   <img src="./livedemoimages/6.png" width="180" style="margin-right: 100px;" />   <img src="./livedemoimages/7.png" width="180" style="margin-right: 100px;" />   <img src="./livedemoimages/8.png" width="180" style="margin-right: 100px;" />   <img src="./livedemoimages/9.png" width="180" style="margin-right: 100px;" /> <img src="./livedemoimages/10.png" width="180" style="margin-right: 100px;" /> <img src="./livedemoimages/11.png" width="180" style="margin-right: 100px;" /><img src="./livedemoimages/12.png" width="180" style="margin-right: 100px;" /><img src="./livedemoimages/13.png" width="180" style="margin-right: 100px;" /><img src="./livedemoimages/14.png" width="180" style="margin-right: 100px;" /><img src="./livedemoimages/15.png" width="180" style="margin-right: 100px;" /><img src="./livedemoimages/16.png" width="180" style="margin-right: 100px;" />

---

## Table of Contents

- 🔧 Quick Start
- 🧩 Features (updated)
- 🏗 Architecture & Important Files
- 🔐 Configuration (.env & CI)
- 🚀 Run: Dev vs Production
- 🧠 How recognition & nutrition flow works
- 🛠 Troubleshooting & Tips
- 🧪 Testing & CI
- ✨ Roadmap / TODOs
- 🤝 Contributing
- 📄 License & Credits

---

## 🔧 Quick Start (30s)

1. Clone:
```bash
git clone https://github.com/VrajVyas11/AI_Calories_Tracker.git
cd AI_Calories_Tracker
```

2. Install dependencies:
```bash
flutter pub get
```

3. Create local `.env` (project root — DO NOT COMMIT). Example keys the app looks for:
```
CLARIFAI_API_ENDPOINT=
CLARIFAI_API_KEY=
USDA_API_KEY=
SUPABASE_URL=
SUPABASE_ANONKEY=
```

4. (Optional dev) Add `.env` to `pubspec.yaml` assets (use only for local development):
```yaml
flutter:
  assets:
    - .env
```

5. Clean & Run:
```bash
flutter clean
flutter run
```

> Note: For production builds, use `--dart-define` to pass secrets (see below).

---

## 🧩 Features (updated)

- Food recognition via Clarifai (image -> labels + confidence).
- Nutrition lookup via USDA FoodData Central (per-100g data).
- Proportion estimation per detected item (confidence × calorie density).
- Adjust serving (grams) and add to daily meal log.
- Persist meals to Supabase (per-user) and local state update.
- Offline fallbacks: simple recognition heuristics and estimated nutrition map.
- Non-blocking notifications (SnackBar) for sign-in and operations.
- Global scaffold messenger to avoid context issues when showing SnackBars.
- New: Account settings UI allowing users to:
  - Change full display name (in-app, triggers onUserUpdated)
  - Update nutrition goals (daily calories, protein, carbs, fat) — updates persisted via SupabaseService.updateGoals
  - Change password UI (validation + placeholder action; backend wiring required)
  - Export data and Delete account dialogs (UI placeholders)
- New: Activity screen with:
  - Recent Meals (meal cards with image, names, timestamp, and nutrient chips)
  - Statistics (daily summaries, totals, averages, daily breakdown)
  - Time-range selector (7 / 30 days)
  - Pull-to-refresh and resilient loading / error handling
- Improved: User profile sheet (bottom sheet)
  - Robust, scrollable layout to fix overflow issues
  - Avatar, joined date, quick navigation to Account Settings & Activity
  - Quick stats display of goals (calories, protein, carbs, fat)
  - Sign-out flow and Help dialog

---

## 🏗 Architecture & Key Files

- lib/
  - main.dart — app entrypoint, ScaffoldMessenger key
  - services/
    - supabase_service.dart — Supabase REST/auth/profile/meals/goals interactions
    - food_recognition_service.dart — Clarifai + USDA + fallback logic (now removed)
  - models/
    - meal_entry.dart — meal model (imageUrl, foodNames, timestamp, calories, protein, carbs, fat)
    - user_profile.dart — user profile model (id, email, fullName, calorieGoal, proteinGoal, carbsGoal, fatGoal, createdAt, updatedAt, onboardingCompleted)
    - calories_tracker_model.dart — Provider state (if used)
  - screens/
  - main_page_screens
      - analytics_page.dart - show analytics of user and graphs
      - dash_board_page.dart - show dashboard and info 
    - auth_screen.dart — sign in / sign up flows
    - scan_food_screen.dart — image picker, analyze, edit and add meal
    - main_screen.dart — app tabs (Scan / Dashboard / History)
    - onboarding_screen.dart - first thing user fils up after login
    - splash_screen.dart - splash screen shown between auth transition
    - account_settings_screen.dart — full settings UI (name, goals, password, data actions)
    - activity_screen.dart — Recent Meals & Statistics with charts/lists
  - widgets/
    - user_profile_sheet.dart — profile bottom sheet (scrollable, navigation)
    - auth_wrapper.dart - a wrapper for auth and navigation after auth
- livedemoimages/ — demo images used in README/demo

---

## 🔐 Configuration: .env & CI

Local development (convenience):
- Create `.env` with the keys above and add to `.gitignore`.

Production (secure):
- Use `--dart-define` and CI secret store. Example:
```bash
flutter build apk --release \
  --dart-define=CLARIFAI_API_KEY=${CLARIFAI_API_KEY} \
  --dart-define=USDA_API_KEY=${USDA_API_KEY} \
  --dart-define=SUPABASE_URL=${SUPABASE_URL} \
  --dart-define=SUPABASE_ANONKEY=${SUPABASE_ANONKEY}
```

The app checks dotenv first, then uses compile-time defines if dotenv isn't present.

---

## 🚀 Run — Dev vs Production

Development:
- Use `.env` (only locally).
- Full restart needed after env changes.
- Run with `flutter run -d <device>`.

Production:
- Do not bundle `.env`.
- Inject keys at build time with CI secrets + `--dart-define`.

---

## 🧠 Recognition & Nutrition Flow (brief)

1. User picks/takes a photo.
2. App encodes the image and sends to Clarifai endpoint.
3. Clarifai returns labels + confidence.
4. For each label, the app queries USDA for nutrients (fallback to local map if needed).
5. Proportion for each label computed as: score = confidence × calories_per_100g → proportion = score / sum(scores).
6. User selects serving grams (G); macros per item = (G × proportion / 100) × macros_per_100g.
7. When saving, the app ensures `user_profiles` exists, inserts into `meals` table in Supabase, then reloads today's meals.

---

## 🛠 Troubleshooting & Tips

- If `saveMeal` fails with `404`: ensure `meals` table exists in Supabase.
- If it fails with `409` (FK): ensure the `user_profiles` row exists or use the app's profile creation flow (app attempts to create it).
- If `.env` not read on device: bundle as asset for dev or use `--dart-define`.
- Check debug logs: SupabaseService prints useful debug lines (e.g., saveMeal status and body).
- If you see RenderFlex overflow in bottom sheet: ensure user_profile_sheet is the updated scrollable version.

---

## 🧪 Testing & CI

- Unit tests: nutrition parsing, proportion math.
- Widget tests: scan → analyze → add → persisted meal flows; settings update flows.
- CI suggestions:
  - `flutter analyze`
  - `flutter test`
  - Build with `--dart-define` using secrets.

---

## ✨ Roadmap / TODOs

Implemented:
- Profile sheet UI (scrollable; avatar, joined date)
- ActivityScreen: recent meals + statistics, time-range selectors
- AccountSettingsScreen: edit name, edit goals, change password UI, export & delete account dialogs
- Goals persistence: SupabaseService.updateGoals called from UI

Follow-ups to implement (priority):
- Wire change password to Supabase / email provider (secure flow + re-auth where needed)
- Implement export data (CSV export & sharing)
- Implement delete account backend flow (Supabase delete + clean local state)
- Add form input validation and more user-friendly error messages
- Add charts for trends (calories over time) in ActivityScreen
- Add tests for AccountSettingsScreen and ActivityScreen flows
- Improve accessibility (larger tappable areas, labels)

---

## SQL & Supabase Setup (quick)

Run in Supabase SQL editor (creates tables and example RLS policies):

```sql
create table if not exists public.user_profiles (
  id uuid primary key,
  email text not null,
  full_name text,
  calorie_goal numeric default 2000,
  protein_goal numeric default 150,
  carbs_goal numeric default 250,
  fat_goal numeric default 67,
  created_at timestamptz default now(),
  updated_at timestamptz
);

create table if not exists public.meals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.user_profiles(id) on delete cascade,
  date text not null,
  timestamp timestamptz default now(),
  food_names text[],
  calories numeric,
  protein numeric,
  carbs numeric,
  fat numeric,
  serving_size text,
  image_url text
);

create table if not exists public.nutrition_cache (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.user_profiles(id),
  food_name text,
  nutrition_data jsonb,
  cached_at timestamptz default now()
);

alter table public.meals enable row level security;
alter table public.user_profiles enable row level security;
alter table public.nutrition_cache enable row level security;

create policy "meals_user_policy" on public.meals
  for all
  using ( auth.uid()::uuid = user_id )
  with check ( auth.uid()::uuid = user_id );

create policy "profiles_user_policy" on public.user_profiles
  for all
  using ( auth.uid()::uuid = id )
  with check ( auth.uid()::uuid = id );

create policy "nutrition_cache_user_policy" on public.nutrition_cache
  for all
  using ( auth.uid()::uuid = user_id )
  with check ( auth.uid()::uuid = user_id );
```

---

## 🤝 Contributing

- Fork → create branch → make changes → open PR.
- Add tests for new features.
- Keep secrets out of commits.
- Use clear commit messages. Example of recent commit message used internally:
  - "feat(profile & settings): add AccountSettingsScreen, ActivityScreen, and improved UserProfileSheet; wire goals persistence"

---

## 📄 License & Credits

- MIT License — see LICENSE file.
- Uses Clarifai model and USDA FoodData Central per their terms.
- Supabase for auth and persistence.
