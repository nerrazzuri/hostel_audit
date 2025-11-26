# hostel_audit_app

Modern hostel audit app with Supabase backend (auth, Postgres, storage) and PDF generation.

## Configuration (Phase 4 - Secrets)

The app reads Supabase config from `--dart-define` at build time (with runtime env fallback for local shells).

Recommended local usage (define file):

```bash
# 1) Copy template and fill in values (do NOT commit your real file)
cp env/dev.example.json env/dev.json

# 2) Run with define file
flutter run --dart-define-from-file=env/dev.json

# 3) Build with define file
flutter build apk --debug --dart-define-from-file=env/dev.json
```

Required defines:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

Optional:
- `ENABLE_FIREBASE` (defaults to `false`). If `true`, the app will initialize Firebase at startup.

Examples:

```bash
# Run debug on device/emulator
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY \
  --dart-define=ENABLE_FIREBASE=false

# Build debug APK
flutter build apk --debug \
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY \
  --dart-define=ENABLE_FIREBASE=false
```

Local shell fallback (not recommended for CI/production):

```bash
# Windows PowerShell
$env:SUPABASE_URL="https://YOUR-PROJECT.supabase.co"
$env:SUPABASE_ANON_KEY="YOUR_ANON_KEY"
flutter run
```

## Database migrations

- Phase 1: `scripts/migrations/20251125_phase1_db_hardening.sql`
- RPC: `scripts/save_audit_rpc.sql` (creates `save_audit_transaction_v2`)
- Phase 2 (RLS): `scripts/migrations/20251125_phase2_rls_policies.sql`

Run in this order and re-run safely (idempotent guards included).

## Tests

```bash
flutter test
```

The test environment skips Supabase initialization automatically.

## CI (Phase 8 - GitHub Actions)

A basic CI pipeline is included at `.github/workflows/flutter_ci.yml`:

- Formats, analyzes, and runs tests on each push/PR
- Optionally builds a debug APK if Supabase secrets are provided

Set repository/environment secrets:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

The build step runs:

```bash
flutter build apk --debug \
  --dart-define SUPABASE_URL=$SUPABASE_URL \
  --dart-define SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
  --dart-define ENABLE_FIREBASE=false
```

If secrets are not set, CI will skip the APK build and still run tests.
