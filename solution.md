# Supabase Local Development Fixes

## Missing base tables
Migrations referenced tables (articles, profiles, sources, editorial_configs) that were never created

## Solution

### 1. Created Initial Schema Migration
**File**: `supabase/migrations/20250601000000_initial_schema_base_tables.sql`

Created a foundational migration that runs first (timestamp: 20250601000000) to establish all base tables needed throughout the system:

**Core Tables**:
- `public.articles` - Article content and metadata
- `public.sources` - Article sources with extraction rules
- `public.profiles` - User profile data (extends auth.users)
- `public.editorial_configs` - Editorial filtering configuration

**Supporting Tables**:
- `public.user_goals` - Weekly post goals per user
- `public.user_streaks` - User activity streaks
- `public.profile_monthly_points` - Monthly leaderboard points
- `public.posts` - Generated LinkedIn posts
- `public."specialized-extraction"` - PII-protected extraction data

**Utility Functions**:
- `handle_updated_at()` - Trigger function for updated_at timestamps
- `touch_updated_at()` - Alias for handle_updated_at()

---

## Bug Fix: Demo User Login Returning 500

### Error
`POST /auth/v1/token?grant_type=password` → `500 Internal Server Error`

Clicking any demo user button on the login screen failed with a server error, even though the frontend code (`src/pages/Login.tsx`) and the Supabase client were correct.

### Root Cause
Two issues combined to break the auth flow:

**1. `supabase/seed.sql` — removed `ON CONFLICT` from `auth.identities` insert**

```sql
-- Before (broken — constraint name varies across GoTrue versions)
on conflict (provider, provider_id) do nothing;

-- After (fixed — no ON CONFLICT needed)
-- supabase db reset wipes the auth schema before seeding,
-- so duplicate identities can never exist.
```

**2. `supabase/seed.sql` — `auth.users` token columns stored as NULL**

GoTrue auth logs revealed the exact failure:
```
sql: Scan error on column index 3, name "confirmation_token":
converting NULL to string is unsupported
```

GoTrue's Go model scans `confirmation_token` (and several sibling fields) into a non-nullable `string`. The seed INSERT didn't include those columns, so PostgreSQL stored them as NULL. Go's `database/sql` package cannot scan NULL into a plain `string` — it requires a pointer or `sql.NullString`. Result: GoTrue returned 500 on every password login.

Fixed by explicitly setting all six token columns to `''` in the INSERT and the ON CONFLICT UPDATE:
- `confirmation_token`
- `recovery_token`
- `email_change`
- `email_change_token_new`
- `email_change_token_current`
- `reauthentication_token`

---

# Bug Fix: Dashboard — Redeem Points targeting wrong user

**File**: `src/pages/Dashboard.tsx`

### Bug 1 — Wrong target user
```ts
// Before (broken)
const targetProfileId = leaderboard[0]?.id || profile.id;
```
Used the top leaderboard user's ID as the UPDATE target. RLS silently blocked it for non-#1 users while the UI showed a false success toast.

```ts
// After (fixed)
.eq("id", profile.id)
```

### Bug 2 — No bounds check
No validation prevented redeeming more points than available, allowing negative point balances. Added an early return with an error toast if `redeemAmount < 1` or `redeemAmount > profile.current_month_points`.

---

# Bug Fix: Generated Posts — edit dialog doesn't persist & wrong image field

**File**: `src/pages/GeneratedPosts.tsx`

### Bug 1 — `saveEdit` never wrote to DB
`saveEdit()` closed the dialog and showed a success toast but contained no Supabase call. Added `UPDATE posts SET content = draft` before closing.

### Bug 2 — Scheduled preview image never rendered
`post.articles?.image_url` — wrong field name. The select query and type both use `imageurl`. Fixed to `post.articles?.imageurl`.

---

## Bug Fix: Topics tab — embed error & broken article titles

**File**: `src/pages/TopicSelection.tsx`

### Bug 1 — `sources:sourceid(name)` fails with duplicate FK
PostgREST column hint `:sourceid` finds both FK constraints (`fk_articles_sources` and `articles_sourceid_fkey`) and errors out. Changed to `sources!articles_sourceid_fkey(name)` (explicit FK name hint) which resolves unambiguously regardless of DB state.

### Bug 2 — `brokenExtractTitle` hides real article titles
A function literally named `brokenExtractTitle` ignored `article.title` and returned `"Article N"` for every entry. Removed the function; render now uses `article.title` directly.
