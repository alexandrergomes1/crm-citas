# Privacy and Consent Risk Register

Status: research-backed risk register / not final legal wording
Owner: Alexandre + ChatGPT orchestration
Last updated: 2026-06-15

This document organizes privacy, consent and jurisdiction requirements for the anamnese, client profile, image authorization, messaging and future payment flows.

It is not a final privacy policy and must not be copied into production as legal text without validation by a qualified professional for the operating jurisdiction.

---

## 1. Current conclusion

The system must not use **LGPD** as the global default term.

Jurisdiction wording should be configurable:

| Jurisdiction | Product wording |
|---|---|
| Spain / European Union | RGPD/GDPR + LOPDGDD |
| Portugal / European Union | RGPD/GDPR + Portugal-specific privacy wording if needed |
| Brazil | LGPD |
| Future global use | configurable privacy template by tenant/jurisdiction |

For the current Spain-first operation, the system should use Spanish-facing privacy and consent language based on RGPD/GDPR and Spain's LOPDGDD.

---

## 2. Why this matters

The anamnese flow can collect or process:

- identity data;
- contact data;
- document number/type;
- address;
- appointment/service data;
- answers about health, pregnancy, allergies, medication, procedures, contraindications and clinical safety;
- signature;
- professional observations;
- before/after photos;
- authorization for image use;
- future messaging and review invitations.

Some of this information may fall into sensitive or special-category treatment depending on jurisdiction, purpose and professional context. The safest product posture is to treat anamnese and clinical/procedure safety information as high-risk data.

---

## 3. Source-backed operating rules

### 3.1 Consent must be granular

Spain's LOPDGDD defines consent as a free, specific, informed and unequivocal expression of will, and when consent is used for multiple purposes, each purpose must be specifically and unequivocally covered.

Product implication:

- do not use one checkbox for everything;
- separate essential service/anamnese acceptance from image authorization;
- separate marketing/messaging consent from service communication;
- separate Google Reviews/reputation invitation logic from clinical consent;
- image use must be explicit yes/no.

### 3.2 Service cannot depend on unrelated consent

The LOPDGDD states that a contract cannot be made dependent on consent to data processing for purposes unrelated to the maintenance, development or control of that contractual relationship.

Product implication:

- a client should be able to refuse image-use authorization and still receive the service;
- a client should be able to refuse marketing and still receive the service;
- non-essential consent must not block the appointment/comanda;
- only clinically/operationally necessary fields should block service flow.

### 3.3 Basic information must be presented clearly

The LOPDGDD allows layered information: when data is collected from the affected person, the controller can provide basic information plus an electronic address or other simple immediate way to access the remaining information. Basic information must at least include controller identity, processing purpose and possibility to exercise GDPR rights.

Product implication:

- use a short visible privacy summary;
- full text should be available via expand/collapse or link/modal;
- do not hide privacy information only in a long unreadable paragraph;
- record the version of the text accepted.

### 3.4 Special-category / health-related data requires extra caution

The LOPDGDD points to GDPR Article 9 for special categories and establishes additional caution around special categories. It also recognizes that processing health data under certain grounds may require legal support and specific safeguards.

Product implication:

- do not treat anamnese as a normal contact form;
- do not use sensitive anamnese answers for marketing segmentation;
- restrict access by role;
- audit access and edits where practical;
- avoid unnecessary fields;
- define retention and deletion/archiving rules;
- do not implement final legal basis without legal validation.

### 3.5 Risk of non-compliance is material

The LOPDGDD classifies as very serious, among other things, processing without lawful basis, invalid consent, incompatible use of data, processing special-category data without proper condition, omission of information duty, breach of confidentiality, and unlawful international transfer.

Product implication:

- privacy must be treated as a product requirement, not copywriting;
- consent records must be auditable;
- data purposes must be separated;
- processors/providers must be reviewed before integration;
- payment/messaging providers may introduce transfer and processor risks.

### 3.6 Privacy by design should guide UX and architecture

AEPD guidance on privacy by design identifies strategies such as minimizing, hiding, separating, abstracting, informing, controlling, complying and demonstrating. It also emphasizes collecting the minimum necessary data and making policies understandable.

Product implication:

- minimize collected fields;
- separate clinical data from marketing data;
- hide/restrict sensitive fields by role;
- inform users in context;
- give control over optional consents;
- demonstrate consent and changes with logs/versions.

---

## 4. Consent purposes to model separately

Recommended purpose model:

| Purpose | Required? | Product behavior |
|---|---:|---|
| Service/appointment administration | Yes | needed for booking, attendance, comanda and history |
| Ficha Cliente / anamnese clinical-safety questions | Usually yes for relevant services | should block only when service requires it |
| Ficha Profissional notes/evidence | Operational/professional | access-controlled, audit-sensitive |
| Signature and record of acceptance | Yes when form is required | store version, timestamp and linked appointment |
| Internal image/photo evidence for case evaluation | Usually operational when needed | separate from public image authorization; visible to professional only |
| Public image use / before-after marketing | Optional | explicit yes/no; refusal must be highlighted and must not block service |
| WhatsApp operational communication | Initial informal/manual; future official provider | document as operational communication; do not build full campaign engine initially |
| Marketing/promotions | Optional/future | separate opt-in; easy opt-out |
| Google Reviews invitation | Optional/operational to validate | should not be tied to clinical consent; configurable |
| Payment/deposit provider | Future | requires provider/privacy/fiscal review before implementation |

---

## 5. UX requirements for anamnese and consents

### Ficha Cliente

Should show:

- short privacy summary;
- expandable full privacy information;
- clear purpose of the form;
- required clinical-safety questions;
- separate consent/acknowledgement for the anamnese;
- separate yes/no for public image/marketing authorization;
- signature;
- language-specific text and answers;
- link to full privacy information.

### Ficha Profissional

Should show:

- whether public image use is authorized or denied;
- whether internal case-evaluation photos exist or are expected;
- whether the Ficha Cliente was signed;
- whether clinical information is pending;
- no marketing use of clinical answers;
- edit/reopen controls with audit trail.

### Appointment / Comanda

Should show:

- Ficha Cliente status;
- Ficha Profissional status;
- image authorization status if relevant;
- blocking only for required clinical/operational gaps;
- no marketing consent prompts mixed with checkout.

---

## 6. Data model recommendations

Do not implement blindly; use as architecture direction.

### Tenant / organization

Potential fields:

- `legal_jurisdiction`: `ES`, `PT`, `BR`, `GLOBAL`;
- `privacy_policy_version`;
- `consent_model_version`;
- `default_language`;
- `data_controller_name`;
- `data_controller_contact`;
- `data_processor_name`, if the SaaS/operator is not the same legal entity as the clinic.

### Consent templates

Potential table:

- `consent_templates`;
- `jurisdiction`;
- `language`;
- `purpose`;
- `version`;
- `short_text`;
- `full_text`;
- `active_from`;
- `active_to`;
- `requires_explicit_acceptance`.

### Consent records

Potential table:

- `client_consents`;
- `client_id`;
- `appointment_id` optional;
- `anamnese_id` optional;
- `purpose`;
- `value`: accepted/declined/withdrawn/not_required;
- `template_version`;
- `language`;
- `captured_at`;
- `captured_by`: client/professional/system;
- `source`: public_form/internal_form/checkout/profile;
- `withdrawn_at`;
- `withdrawal_reason` optional.

### Clinical/anamnese evidence

Potential requirements:

- store snapshot of the questions and answers;
- store language;
- store signature and timestamp;
- store whether public image use was accepted or declined;
- separate internal clinical/case photo evidence from public marketing authorization;
- protect signed records from silent overwrite;
- reopen/edit only through correction, retification or versioning.

---

## 7. Product decisions recorded

### 7.1 Image use

Current product decision:

- images/photos are needed primarily for client case evaluation and professional follow-up;
- eventual use in marketing may happen only when the professional judges it appropriate;
- public/marketing image use must remain optional and separately authorized;
- refusal of marketing/public image use must be highlighted to the professional and must not block service.

Product split:

1. **Internal/case evaluation image evidence**: operational/professional context.
2. **Public marketing/before-after use**: optional consent, explicit yes/no.

### 7.2 Minors

Current product decision:

- minors are not attended in principle.

Product implication:

- no guardian/minor consent flow is needed for the initial release;
- if minors are later accepted, a new legal/product flow must be designed before enabling it.

### 7.3 Data controller / processor

Current product intention:

- the company managing the system is expected to be the data controller.

Risk note:

- in a SaaS/tenant model, the clinic/tenant often may be the controller for its own client data, while the software operator may be a processor or joint/independent controller depending on contracts and operational control;
- final role must be validated before legal text is published;
- the product should support configurable controller information by tenant to avoid hardcoding the wrong party.

### 7.4 WhatsApp / messaging

Current product decision:

- start informally/manual or semi-manual for occasional operational communications;
- do not implement a full official WhatsApp API provider at the beginning;
- future evolution may use official WhatsApp API or a workflow/integration layer such as n8n or a similar provider;
- avoid campaign/marketing automation until consent, opt-out and provider responsibilities are clear.

Implementation implication:

- initial product can support simple WhatsApp link/action for operational messages;
- API-based automation should wait for MSG-LEGAL-01 and provider review.

---

## 8. Product decisions still required

1. Which procedures require mandatory anamnese?
2. Which procedures require internal photo evidence?
3. What is the tenant's legal jurisdiction at launch: Spain only, Spain/Portugal/Brazil, or configurable from day one?
4. What is the final data-controller/processor role by tenant and by SaaS operator?
5. Which providers will process official messages, payments, storage, analytics or reviews?
6. What retention period applies to anamnese, photos and professional notes?
7. How will users request access, correction, deletion, restriction or portability?
8. Whether operational WhatsApp communication needs explicit opt-in in the first version or can be handled as service communication with clear notice.

---

## 9. Recommended implementation order

### LEGAL-01 — Research and text model

- Confirm jurisdiction model.
- Draft Spain/EU privacy summary and consent purposes.
- Validate with legal professional before production text.

### LEGAL-02 — Consent architecture

- Add consent purpose/version model.
- Separate public image authorization from internal case-evaluation image evidence.
- Store consent records per purpose.

### ANA-LEGAL-01 — Anamnese UX compliance

- Add short summary + expandable full privacy information.
- Add public image authorization yes/no.
- Highlight refusal to professional.
- Store text version and language.

### MSG-LEGAL-01 — Messaging consent and opt-out

- Separate operational communication from marketing.
- Add template consent/opt-out before campaign messaging.

### PAY-LEGAL-01 — Payment/deposit provider review

- Review provider role, fiscal reporting, privacy processor terms and data transfer before implementation.

---

## 10. What not to do

- Do not call the European term LGPD.
- Do not bundle image use, marketing and clinical consent in one checkbox.
- Do not block service if the client refuses public image use.
- Do not use anamnese answers for marketing segmentation.
- Do not overwrite client profile data from anamnese without professional validation.
- Do not implement final legal text without jurisdiction validation.
- Do not add payment or messaging providers without processor/privacy review.
- Do not enable minor-service workflows without a dedicated consent/guardian model.

---

## 11. Sources consulted

- BOE — Ley Organica 3/2018, de Proteccion de Datos Personales y garantia de los derechos digitales, consolidated text, last update 2025-12-27.
- AEPD — Guia de Privacidad desde el Diseno, October 2019.
- GDPR / Regulation (EU) 2016/679 references as cited by LOPDGDD and official EU framework.
