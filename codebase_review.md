# Codebase Review & Gap Analysis

## Missing Parts (New Features)

1.  **Background Sync**
    *   **Current State:** `SyncService` exists but only runs when triggered manually or on app start.
    *   **Recommendation:** Implement `workmanager` or `background_fetch` to sync pending audits periodically even when the app is closed.

2.  **True Offline Support (Robustness)**
    *   **Current State:** `LocalAuditRepository` and `SyncService` are implemented.
    *   **Gap:** Conflict resolution strategy is missing (what if server data changed?).
    *   **Recommendation:** Implement "Last Write Wins" or a user-prompted merge strategy.

3.  **CI/CD Pipeline**
    *   **Current State:** No automated build/test pipeline.
    *   **Recommendation:** Set up GitHub Actions or Codemagic for automated testing and building.

## Weak Parts (Improvements)

1.  **Transaction Safety (Partial)**
    *   **Location:** `SupabaseAuditRepository.saveAudit`
    *   **Status:** **Improved**. Now uses `save_audit_transaction` RPC for the main audit data.
    *   **Remaining Issue:** Defect insertion (lines 127-146) happens *after* the RPC transaction. If this fails, defects are lost.
    *   **Recommendation:** Move defect insertion *inside* the `save_audit_transaction` RPC.

2.  **Hardcoded Values & Localization**
    *   **Location:** Everywhere (e.g., 'pass', 'fail', UI strings).
    *   **Issue:** Makes maintenance and future localization difficult.
    *   **Recommendation:** Adopt `flutter_localizations` and extract strings to ARB files.

3.  **PDF Network Image Loading**
    *   **Location:** `PdfService.generateAuditPdf`
    *   **Issue:** Uses `NetworkAssetBundle` which may fail if Supabase Storage requires authentication/headers (private buckets).
    *   **Recommendation:** Use authenticated HTTP client to fetch images if buckets are private.

4.  **Input Validation UX**
    *   **Location:** `AuditFormScreen`
    *   **Issue:** Validation is likely still "on submit" rather than real-time.
    *   **Recommendation:** Implement `Form` with `autovalidateMode: AutovalidateMode.onUserInteraction`.

## Security

1.  **RLS Policies:** Verify `scripts/supabase_schema.sql` ensures users can only access their own audits/hostels.

## Completed Improvements
- **Pagination:** Implemented in Repository and Provider.
- **Crash Reporting:** `CrashReportingService` integrated.
- **PDF Performance:** `PdfService` now uses Isolates and image resizing.
- **State Management:** `AuditProvider` refactored with `copyWith`.
