-- API-042: extends AUTH-030's recent-auth purpose allowlist for the two
-- admin mutations instructions.md section 7 names explicitly - school
-- closure/suspension (which reuse the 'school_admin_privileged' purpose
-- AUTH-030 already reserved for exactly this) and account data export
-- (which needs its own purpose, since it is not a deletion).
alter table public.auth_reauth_grants drop constraint auth_reauth_grants_purpose_check;
alter table public.auth_reauth_grants add constraint auth_reauth_grants_purpose_check check (
  purpose in (
    'account_deletion',
    'account_deletion_cancel',
    'account_link',
    'all_device_sign_out',
    'device_revoke',
    'school_admin_privileged',
    'account_data_export'
  )
) not valid;
alter table public.auth_reauth_grants validate constraint auth_reauth_grants_purpose_check;
