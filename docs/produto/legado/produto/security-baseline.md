# Beauty System — Security Baseline

Status: security governance / active baseline
Owner: Alexandre + ChatGPT orchestration
Last updated: 2026-06-17

## 1. Decision

Security is part of the core architecture and must not be postponed to the end.

Approved direction:

- Supabase Auth remains the authentication provider for now;
- `user_roles` remains the tenant/role access model;
- RLS remains mandatory for tenant data protection;
- sensitive writes must use server-side validation and transactional RPCs when needed;
- production must have Vercel/Supabase hardening before real users.

## 2. Authentication

Current decision:

- keep Supabase Auth;
- do not migrate to Clerk/Auth0/WorkOS/Auth.js now;
- build a formal user invitation/account flow later instead of creating users manually in SQL.

Required future auth features:

- user profile/account screen;
- password change/reset flow;
- logout/session termination;
- collaborator/team management;
- role/module permissions;
- MFA for sensitive roles.

Sensitive roles for future MFA:

- owner;
- admin;
- finance;
- manager, if financial or user-management access is enabled.

## 3. Authorization

The authorization model is:

```txt
Supabase Auth user
→ user_roles
→ organization/tenant
→ role-based action checks
→ RLS on data
```

Rules:

- every operational table must be tenant-safe through `org_id` or a safe relationship to `org_id`;
- server actions must call org/role access helpers;
- client-side hiding is not authorization;
- RLS must enforce backend boundaries;
- no cross-org data exposure is acceptable.

## 4. Roles

Current enum includes:

- owner;
- admin;
- manager;
- professional;
- receptionist;
- finance;
- viewer.

Future role policy must define access per module:

| Module | Roles to define |
|---|---|
| Agenda | owner, admin, manager, receptionist, professional |
| Clientes | owner, admin, manager, receptionist, professional, viewer limited |
| Catálogo | owner, admin, manager |
| Anamnese | owner, admin, manager, professional |
| Comanda/Checkout | owner, admin, manager, finance, receptionist |
| Financeiro | owner, admin, finance, manager limited |
| Marketing | owner, admin, manager, marketing future |
| Configurações | owner, admin |

Do not implement role menus before defining backend enforcement.

## 5. Server-side rules

Required:

- Zod or equivalent validation for all non-trivial inputs;
- no direct trust in client values for price, org_id, status or role;
- idempotency key for critical writes;
- transaction/RPC for multi-step operations;
- structured error return, not false success;
- audit log for sensitive operations.

Sensitive operations include:

- checkout/finalization/payment;
- client balance adjustment/reversal;
- anamnese/ficha signature or evidence;
- client deletion/anonymization future;
- role/user changes;
- marketing opt-out/consent changes;
- provider send events future.

## 6. Supabase hardening checklist

Before production:

- verify RLS is enabled on all tenant tables;
- verify every policy uses tenant-safe logic;
- audit every `security definer` function;
- ensure no service_role key in browser bundle;
- disable public signup if not explicitly launching self-serve SaaS;
- configure redirect URLs for real domains only;
- configure password policy;
- configure custom SMTP before real customer email flows;
- separate dev/staging/production projects or environments;
- review storage bucket policies;
- set backup/PITR policy before paid production;
- verify migrations reproduce a clean database.

## 7. Vercel hardening checklist

Before production:

- separate env vars by environment;
- protect preview deployments if they contain real data;
- configure production domain and SSL;
- add security headers:
  - Content-Security-Policy;
  - Strict-Transport-Security;
  - Referrer-Policy;
  - Permissions-Policy;
  - frame restrictions;
- keep `poweredByHeader: false`;
- restrict source maps/log exposure;
- monitor 500s and auth errors;
- define deploy rollback process;
- define spend/usage monitoring.

## 8. Data protection

Required principles:

- do not use anamnese/clinical data for marketing segmentation;
- separate operational messages from marketing consent;
- keep image-use consent separate from treatment consent;
- do not expose sensitive medical/anamnese fields in logs;
- avoid storing unnecessary copies of client PII in audit payloads;
- design for GDPR/LGPD-compatible correction/deletion/anonymization later.

## 9. Storage security

Future storage buckets should be separated by purpose:

- catalog/service images;
- client/anamnese photos;
- signed documents/consents;
- internal uploads.

Rules:

- private by default for client/anamnese evidence;
- signed URLs or controlled server access;
- no public bucket for clinical/client photos;
- no direct marketing reuse without explicit image-use consent.

## 10. Immediate security work not to skip

Recommended next security tasks after core validation:

1. RLS/policy audit by table;
2. security headers/CSP baseline;
3. Supabase production config checklist;
4. formal user invitation/account flow;
5. MFA for sensitive roles;
6. storage policy review.

## 11. Acceptance rule

No feature is complete if:

- it works only because UI hides buttons;
- it trusts client-provided `org_id`, price, role or status;
- it returns success despite backend error;
- it exposes tenant data cross-org;
- it writes sensitive state without audit trail when audit is required.
