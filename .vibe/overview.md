# Penpal — Project Overview

High-level orientation for working in this repo. Deliberately skips anything
already obvious from code comments; focuses on architecture, intent, and the
non-obvious gotchas. For agent workflow rules see `AGENTS.md` in this folder.

## What this project is

**Penpal** — an AI conversational language-learning app. Today it is in a
"base state": the `supabase-community/flutter-chat` example, renamed. The chat
foundation (auth + realtime messaging + attachments) works; **the AI layer does
not exist yet** — that is the point of the project. (Note: the "Start Colibri"
task in `.vscode/tasks.json` is a personal coding assistant the owner runs
alongside, auto-started on folder open — it has nothing to do with this project;
do not read it as a hint about the AI backend.)

## Architecture at a glance

```
Flutter app (lib/)  ──►  Supabase (supabase/, local CLI project, Postgres 17)
   email/password auth     auth (GoTrue), email confirmations OFF locally
   realtime chat stream    public.profiles / public.messages, RLS, realtime publication
   file attachments        private storage bucket "attachments" (10 MiB/file)
```

- **Single global chat room.** There is no room/conversation concept anywhere —
  schema, RLS, and client all assume one shared stream readable by every
  signed-in user. This is the biggest structural assumption to keep in mind when
  adding pen-pal/1:1 conversation features.
- **No state-management library.** Pages use `setState` plus in-memory maps;
  `lib/utils/constants.dart` exposes a global `supabase` client that everything
  imports. No DI, no codegen, no dotenv.
- **Navigation is auth-driven and centralized.** `main.dart` subscribes to
  `supabase.auth.onAuthStateChange` and swaps the whole stack via a global
  navigator key: no session → Register, signed in → Chat, signed out → Register.
  Pages never navigate themselves after auth; `SplashPage` is just a placeholder
  until the initial session resolves. Pages expose `static route()` factories;
  there is no named-route map.

## App flow

`Splash → Register ⇄ Login → Chat`

- Register passes `username` in sign-up metadata; a DB trigger
  (`handle_new_user`) copies it into `profiles`. **Username metadata is
  mandatory** — without it the trigger fails and sign-up itself fails.
- Chat loads the latest 20 messages via a realtime `stream()`, paginates older
  messages with a keyset cursor that explicitly handles equal `created_at`
  timestamps, and fetches sender profiles in a separate batched query (streams
  don't support joins). Sending is a plain insert — **no optimistic UI**; your
  own message appears when the realtime echo arrives.
- Attachments: file picked → uploaded to `attachments/<uid>/<timestamp>.<ext>`
  → message row references the path. Images render inline via short-lived signed
  URLs (cached in-page with a 5-min early-refresh margin); other files render as
  a download row. `CoverResizeImage` (lib/utils) downscales images at decode
  time for the small thumbnails — the only unit-tested code in the repo.

## Backend (supabase/)

Two migrations define everything:

1. `..._create_chat_schema.sql` — `profiles` (id = auth.users id, unique
   username with a regex check), `messages` (profile_id defaults to
   `auth.uid()`), RLS on both: authenticated users can **read everything**,
   insert messages only as themselves; **no update/delete policies exist**.
   `messages` added to the `supabase_realtime` publication; trigger auto-creates
   profiles on sign-up.
2. `..._add_message_attachments.sql` — `attachment_path`/`attachment_name`
   columns on messages, a check constraint requiring text *or* attachment, a
   private `attachments` bucket (10 MiB), and policies tying storage paths to
   the uploader: the first path segment must equal `auth.uid()`.

`config.toml` is a stock local-dev config (all default ports, PG17, fake SMTP on
54324, Studio on 54323) with `project_id = "flutter-chat"`. Gotchas: `[db.seed]`
points at a `./seed.sql` that doesn't exist; migration filenames are
future-dated (2026…); no edge functions exist despite the edge runtime being on.

## How to run

```bash
supabase start                                    # local backend (Docker), then apply migrations
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...
flutter test                                      # only test/cover_resize_image_test.dart exists
```

Credentials come **only** from `--dart-define` (`String.fromEnvironment` in
`main.dart`) — there is no `.env` and no fallback; missing flags initialize
Supabase with empty strings and fail late at runtime. Neither the VS Code nor
the JetBrains run config supplies these flags. Note the modern
`publishableKey` parameter (supabase_flutter 2.18), not the legacy `anonKey`.

## Conventions worth knowing

- Dart package name is still **`flutter_chat`** — every import is
  `package:flutter_chat/...`, while the app title, desktop bundle IDs, and `.iml`
  files say `penpal`. A rename touches every import.
- Classes are declared `class const Foo(...)` (Dart 3.3+ syntax), used
  consistently.
- Models are hand-rolled immutable classes with `fromMap`; `Message.isMine` is
  derived at parse time from the current user, not stored.
- Errors surface as red snackbars via a `BuildContext` extension; auth pages
  distinguish `AuthException` messages from a generic fallback string.
- Table names are inline string literals; the bucket name is a private const in
  `chat_page.dart` — none of this is centralized in `constants.dart`.

## Gotchas / pitfalls

- **Name split-brain**: package/Android (`com.example.flutter_chat`)/iOS/web =
  `flutter_chat`; desktop platforms = `penpal`. There is a dead duplicate
  `MainActivity.kt` under `com/example/penpal/`.
- **Release Android builds currently have no INTERNET permission** — it is only
  in the debug/profile manifests, so release APKs can't reach Supabase.
- `pubspec.lock` is gitignored (unusual for an app); `.widget_preview/` is a
  committed but inert Flutter widget-preview scaffold (no `@Preview`s, wrong
  package name, hardcoded Windows path).
- The attachment path convention (`<uid>/...`) is load-bearing — enforced by
  both the storage and message-insert RLS policies.
- Attachments are readable by any authenticated user and can never be deleted
  (no delete policies on tables or storage).
- `supabase/config.toml` `project_id` and the README still reference the
  upstream example; migrations carry 2026 dates.
- Only direct deps: `supabase_flutter`, `file_picker`, `timeago`,
  `url_launcher`. No mocking packages, no integration tests — test coverage is
  essentially just the image utility.

## Map of the repo

| Path | What lives there |
|---|---|
| `lib/main.dart` | App entry, Supabase init, auth-driven navigation |
| `lib/pages/` | splash / register / login / chat (chat_page.dart is the core screen, ~580 lines) |
| `lib/models/` | `Profile`, `Message` (fromMap models) |
| `lib/utils/` | `constants.dart` (global supabase client, theme, snackbar ext), `cover_resize_image.dart` |
| `supabase/` | CLI project: `config.toml`, two migrations, no functions/seed |
| `test/` | Single widget test for `CoverResizeImage` |
| `android/ ios/ web/ linux/ macos/ windows/` | Stock Flutter platform scaffolding (see gotchas) |
| `.vibe/` | This overview + `AGENTS.md` (workflow rules; `tasks/` holds todo/lessons per AGENTS.md) |

<!-- overview-sync: last_seen=583f8500416c434f370abfa3633f9108f4cf50d6 fingerprint=bf35c586c88c20cffcc84a9c7ff92e661a6714ea607ca0a4ae24e9ebd0a8f08e at=2026-11-17T21:41:14Z -->
