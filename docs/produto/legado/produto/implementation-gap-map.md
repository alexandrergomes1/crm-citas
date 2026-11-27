# Beauty System — Implementation Gap Map

Status: active product orchestration
Owner: Alexandre + ChatGPT orchestration
Last updated: 2026-06-22

This document maps capabilities that already have backend/contracts or partial UI, but are not yet complete product features.

Rule:

> Backend created is not a product feature until it is exposed, usable, tested and validated in the frontend flow.

## 1. Current product baseline

Core product remains:

1. Cliente;
2. Anamnese;
3. Catálogo;
4. Agenda/Agendamento;
5. Comanda/Checkout;
6. Financeiro.

Marketing/Fidelidade/Access/Tenant/SaaS admin remain future/paused unless explicitly reactivated.

## 2. Current highest-risk gaps

| Capability | Current state | Product/front gap | Priority | Next executor |
|---|---|---|---:|---|
| Design System visual pilots | Components exist; UX-DS-PILOT-01 exists only as branch preview commit `6aa6f1a`, not master | Need clean PR/merge decision after Financeiro + Anamnese visual validation | P0 | Claude |
| Anamnese visual | Uses DS components and mobile/tablet improvements exist; still under product validation | Viewer/header/body scroll, consistency with global pilot and final visual acceptance | P0 | Claude |
| Agenda notes/status | Notes/status merged to master via PRs #4/#5 | Validate in app: cliente profile, comanda context, appointment notes, legacy/fixed notes preservation | P1 | ChatGPT + Codex/Claude |
| Agenda V3 visual | Agenda has blocks/filters and current functional view | Filter UI must move to global FilterSheet; calendar must dominate; action patterns must be global | P1 | Claude |
| Migrations reproducibility | Many migrations exist and have been applied incrementally | Need reproducible-new-db audit before serious deploy/new environment | P1 | Codex |
| Core E2E | Several targeted tests/E2Es exist | Need golden path Cliente > Catálogo > Agenda > Anamnese > Checkout > Financeiro | P1 | Codex |

## 3. Backend/contract ready but product incomplete

| Capability | Current technical state | Front/product gap | Priority | Next executor |
|---|---|---|---:|---|
| Client/appointment notes timeline | `client_notes`, create/edit RPCs, audit log, RLS, profile timeline and comanda context exist | Validate exact behavior for fixed/legacy notes and later polish visual in Cliente/Agenda | High | ChatGPT + Claude later |
| Appointment actions/status matrix | Centralized status/actions exist; operational/financial distinction preserved with legacy compatibility | Apply to Agenda UI/action menu after Agenda V3 work | High | Claude later |
| Service bundles / combos | `service_bundles`, `service_bundle_items`, Catalog UI, Agenda selection, appointment item origin and Comanda total flow exist | Premium polish of bundle tab/selection/origin remains; memberships still separate | Medium | Claude later |
| Client balance ledger | Atomic RPC, ledger, transaction, audit log and client profile history UI exist | Visual polish and examples/reporting validation remain | Medium | Claude/Codex later |
| Balance reversal | RPC/action and client profile reversal action exist | Broader finance/reversal reporting UI still pending | Medium | Codex/Claude later |
| Finance reconciliation | Reports/DRE distinguish operational revenue from stored value/adjustments | Finance UI/reporting need human validation against examples | High | ChatGPT + Codex |
| Marketing foundation | Campaigns, segments, templates, queue, events, preferences, RLS and minimal `/marketing` UI exist | Work paused by product owner; no provider/send work now | Paused | None |
| WhatsApp/messaging provider | Provider research exists and says do not integrate real provider yet | WhatsApp/SMS/n8n remain future; no real send before consent/provider decision | Later | None now |
| Privacy/consent | Legal/privacy risk register exists; Anamnese legal roadmap exists | No consent template/version records, image-use separated in UI, country/language model yet | Medium | Later after Anamnese UI |
| Access/collaborators | Roles/organizations exist at base level | No complete collaborator management, permission UI or module-level access controls | Future core support | Later |
| Tenant/new environment | Tenant slug exists (`/ka-beauty`) | No create-new-tenant flow or plan/module enablement UI | Future SaaS | Later |

## 4. Visual/product gaps by module

### Agenda / Agendamento

Current state:

- views, zoom and calendar navigation exist;
- blocking/time-block work exists in `master` from AGENDA-BLOCKS-FILTERS-01;
- functional filters exist but their inline visual implementation is not final;
- appointment detail has been improved across prior commits;
- appointment status/actions matrix and notes timeline now exist in `master`;
- notes can be created/edited and accessed in customer/checkout context according to PR #4 and spec 28.

Gap:

- validate notes in real app: profile, comanda, appointment context and preservation of fixed/legacy notes;
- Agenda V3 should use compact toolbar and FilterSheet, not inline expanded filters;
- calendar should remain visually dominant;
- mobile 390px needs revalidation against Fresha references;
- after V3, appointment cards may show discreet note indicator if useful.

### Cliente

Current state:

- international document/phone fields;
- balance ledger and reversal base exists;
- client/appointment notes timeline exists;
- long notes collapse/expand and persisted notes can be edited;
- legacy `clients.notes` and `clients.fixed_notes` are preserved as read-only timeline context.

Gap:

- profile visual still needs V3 polish;
- confirm exact UX for notes/fixed notes and client tabs;
- GDPR/retention/anonymization remains future.

### Catálogo

Current state:

- services/products/packages/plans UI exists;
- service contracts hardened;
- bundles/combos have a functional Catalog tab;
- bundles can be created, edited, archived/restored and shown with internal services/price/status.

Gap:

- Catalog still needs premium polish;
- bundle UI and appointment/comanda origin presentation need refinement;
- memberships/plans need product/technical normalization.

### Anamnese

Current state:

- models, generated link, signed forms, professional evaluation and template builder exist;
- `7b33b22` applied core interaction patterns;
- `8d7bde7` adjusted mobile/tablet navigation and cards;
- `docs/specs/27-anamnese-legal-language-audit-roadmap.md` captures future legal/language/audit requirements.

Gap:

- visual result still needs final product acceptance;
- viewer/header/body scroll issue remains from user validation;
- legal terms, image consent, country/language/versioning are future;
- do not use current Anamnese visual as reference for other modules until the dual-pilot standard is accepted.

### Comanda / Checkout

Current state:

- context/operation separation improved;
- anamnese hidden by default through toggle;
- adjustments moved to clearer access;
- finance backend is stronger;
- bundle-origin items can reach Comanda with correct expanded item total;
- Checkout has Voltar and clearer ficha/adjustment triggers;
- notes of client/appointment are available through contextual panel in customer side of comanda.

Gap:

- final visual polish reserved;
- receipt/finalization mobile needs later validation;
- credit use/reversal visibility depends on finance/client UI decisions;
- full E2E total/partial/credit/reversal still pending.

### Financeiro

Current state:

- V3 shell/pilot visual exists and is the closest approved layout reference;
- financial calculations improved around credit/stored value;
- reports/DRE distinguish some operational revenue from stored value/adjustments;
- UX-DS-PILOT-01 preview further refines Financeiro mobile tabs/headers but is not merged.

Gap:

- reports need example-based business validation;
- operational visibility of reversals/ledger still needs decisions;
- Financeiro cannot be considered complete just because shell is visually cleaner;
- preview pilot changes need clean integration decision.

### Design System / Shell

Current state:

- tokens V3 exist;
- AppShell, sidebar/subnav and collapse patterns exist;
- `PageToolbar`, `SideSheet`, `OperationalList`, `ActionMenu`, `StatusBadge`, `FilterSheet` exist;
- docs define navigation and interaction standards;
- `SegmentedControl.scrollable` exists in preview branch but not master.

Gap:

- `OperationalList` and table/list styling need visual QA and refinement;
- active/focus/row divider behavior must not regress into harsh borders/default browser styles;
- broad replication should wait for visual acceptance in Financeiro + Anamnese comparison;
- preview branch must be rebased/cleaned if it is to enter `master`.

## 5. Immediate orchestration decisions

### Claude current track

Claude should not create more isolated screen layouts. The next visual work must be a clean branch/PR that consolidates Financeiro + Anamnese as two-screen pilot standard.

Acceptance focus:

- same visual language in Financeiro and Anamnese;
- desktop does not look like mobile enlarged;
- mobile does not become a broken table;
- viewer/header/body scroll fixed;
- SideSheet/FilterSheet/ActionMenu/OperationalList visually premium;
- no harsh black dividers/default outlines;
- screenshots 390/768/1024/1440.

### Codex current track

Codex note/status work is merged. Do not ask Codex for more in that area until user/front validation confirms a functional gap.

Next Codex work should be either:

- validation fixtures/E2E for the integrated notes if needed;
- or CORE-E2E golden path after visual pilots stabilize.

## 6. Next likely development after current validation

Do not send until current work is validated.

| Condition | Next work |
|---|---|
| Financeiro + Anamnese visual pilot accepted | Claude: Agenda V3 visual pass with FilterSheet and calendar dominance |
| Notes integrated but visually unclear | Claude: expose notes in Cliente/Agenda using accepted DS |
| Agenda V3 accepted | Codex/Claude: core E2E and remaining status/recurrent edge cases |
| Finance needs confidence | ChatGPT/Codex: finance example validation and fixtures |
| Catalog becomes next core priority | Claude: Catalog V3/bundles polish |

## 7. Non-negotiable validation rule

For every future delivery:

- code commit exists in remote;
- scope matches prompt;
- tests/build pass or failure is proven preexisting;
- real affected page opens;
- mobile 390px validated for UI;
- tablet 768px validated for UI;
- desktop 1024px and 1440px validated for UI;
- backend-only delivery states exactly how it will be exposed in frontend later;
- module status is not marked complete unless the user can use the feature end-to-end.