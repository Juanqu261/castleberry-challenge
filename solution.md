# Supabase Local Development Fixes

## Problem
When initializing Supabase locally with `npx supabase start`, migrations were failing due to:
1. **Missing base tables**: Migrations referenced tables (articles, profiles, sources, editorial_configs) that were never created
2. **Migration ordering issues**: Early migrations (June 2025) tried to alter tables that weren't created until August 2025+
3. **Schema assumptions**: Migrations were generated from a cloud database where tables already existed, but timestamps didn't reflect actual dependencies
4. **PostgreSQL syntax errors**: Some migrations had incorrect syntax (GET DIAGNOSTICS, invalid RLS policies)

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
