# Beauty System — Future Modules Map

Status: planning / not active implementation
Owner: Alexandre + ChatGPT orchestration
Last updated: 2026-06-16

This document records product modules and expansion requirements that must not be lost while the core is being built.

## Product name

The product name is **Beauty System**.

`/ka-beauty` is currently treated as an organization/tenant slug, not the product name.

Do not remove the tenant slug without a technical decision. It supports future multi-company operation.

Possible future models:

- `beautysystem.app/ka-beauty`;
- `ka-beauty.beautysystem.app`;
- custom domain per tenant.

## Current priority remains core

Do not start future modules before the core gate unless required by security, access or blocking architecture.

Core remains:

1. Cliente;
2. Anamnese;
3. Catalogo;
4. Agenda/Agendamento;
5. Comanda/Checkout;
6. Financeiro.

## Next product modules after core

When core modules are stable enough for operational use, the next product line is:

1. Marketing;
2. Fidelidade / Loyalty;
3. Access and collaborators;
4. Tenant/SaaS expansion;
5. Module availability by profile/plan.

Marketing comes before Access/Collaborators unless access becomes a blocking security requirement.

## Future module: Marketing

Future scope ID: `MKT-01`.

Required capabilities:

- campaign/contact audience builder;
- client segmentation by service, last visit, birthday, inactive clients, tags, spend, city/language and consent status;
- campaign drafts and templates;
- manual send queue first;
- WhatsApp provider abstraction, not hardcoded vendor;
- optional SMS fallback/redundancy abstraction;
- delivery status tracking when provider integration exists;
- opt-out/consent flags before automated sends;
- Google Reviews/post-visit campaign support;
- birthday, reactivation, aftercare and review-request journeys;
- no bulk automation without provider/legal review.

Research pending before provider implementation:

- official WhatsApp Business Platform / Cloud API requirements;
- template approval and conversation/category rules;
- WhatsApp provider options, including official API and intermediaries;
- SMS providers and cost/coverage for Spain/Portugal/Brazil if needed;
- n8n/AWA/other middleware suitability for MVP vs official API;
- compliance around consent, opt-out, logs and message categories.

## Future module: Fidelidade / Loyalty

Future scope ID: `LOY-01`.

Required capabilities:

- loyalty points or credits;
- birthday or visit-based rewards;
- package/member benefit display;
- client-facing balance/history;
- safe interaction with client balance ledger;
- reporting of issued/redeemed rewards;
- anti-duplication and audit trail.

## Future module: Access and collaborators

Future scope ID: `CORE-ACCESS-01`.

Required capabilities:

- user profile screen;
- change password;
- logout / end session;
- account data;
- collaborators/team management;
- roles: owner, admin, manager, finance, professional/collaborator and future limited roles;
- permissions by module;
- hide or disable modules by role;
- audit-sensitive actions by role;
- future plan-based feature access.

## Future module: Tenant and environment management

Future scope ID: `SAAS-TENANT-01`.

Required capabilities:

- create new organization/tenant;
- choose tenant slug;
- tenant settings;
- tenant branding/localization;
- initial admin user;
- future plan/subscription limits;
- optional custom domain.

## Future module: Module availability by profile/plan

Future scope ID: `SAAS-MODULES-01`.

Required capabilities:

- module registry;
- module enabled/disabled per organization;
- module access per role;
- navigation generated from accessible modules;
- safe backend enforcement, not only hidden UI;
- upgrade/downgrade path for commercial plans.

## Future module: Mobile-first product polish

Future scope ID: `UX-MOBILE-01`.

Required capabilities:

- premium mobile layout for all core modules;
- mobile navigation patterns validated against Fresha mobile references;
- touch targets, bottom safe area, scroll behavior and active tab state;
- no weak mobile version of desktop screens.

## Current architectural expectation

The system should remain modular:

- backend access must enforce organization and role;
- frontend navigation must reflect accessible modules;
- features should be implemented as isolated module capabilities;
- core modules must not hardcode only Karenn/ka-beauty assumptions;
- Marketing and Loyalty must not be hardwired only to WhatsApp or only to Karenn.

## Not active now unless explicitly prioritized

- public signup / new tenant creation;
- billing plans;
- white-label domains;
- marketplace/integrations;
- official WhatsApp API;
- automated bulk marketing;
- booking public beyond core readiness.
