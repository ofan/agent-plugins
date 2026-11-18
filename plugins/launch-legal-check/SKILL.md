---
name: launch-legal-check
description: Pre-launch legal check for a vibe-coded or AI-built app — audit for the 6 laws such apps commonly break (COPPA age gate, GDPR external fonts, CIPA session replay, CAN-SPAM email, California auto-renewal, DMCA agent), fix what is fixable in code, and list what only the owner can do. Trigger phrasing: "check my app before launch", "legal check this app", "is this app compliant", "vibe coder laws", "pre-launch checklist".
---

# Pre-launch legal check — 6 laws vibe-coded apps break

## Purpose
Catch the 6 legal traps that weekend-built apps ship with by default, before launch. Each trap takes minutes to fix in code. Left unfixed, each carries per-violation fines or refund liability. This skill is a checklist and fix procedure, not legal advice. When a finding depends on audience, jurisdiction, or business model, flag it for a lawyer instead of calling it pass or fail.

Source: X post by @Voxyz_ai (Vox), 2026-11-17, https://x.com/voxyz_ai/status/2122736531701977117 — 97.5K impressions, 1,905 bookmarks at save time. Full text filed in `references/source-post.md` next to this file.

## When to use
- Before any public launch, paid launch, or Product Hunt / directory submission of an app Ryan built or vibe-coded.
- When Ryan asks for a legal, compliance, or pre-launch check on an app, site, or SaaS.
- As the final step in a fleet build brief for any user-facing app that has signup, email, payments, uploads, analytics, or third-party embeds.
- Not for a full legal audit, terms drafting, or regulated industries (health, finance, kids-only products). Those need a lawyer. This check does not replace one.

## The ready-to-paste prompt
The post's own prompt, for handing to Claude Code or Codex on the target repo:

> Check my app for: missing age gate, externally loaded fonts, session replay without consent, marketing emails without unsubscribe and address, renewal terms not beside the subscribe button and no DMCA agent. Fix what you can and list what I need to do myself.

When Manto runs this skill directly or briefs a fleet agent, use the Procedure below instead. It is that prompt expanded into evidence, fixes, and verification.

## Procedure
1. Scope first. Establish 6 facts from the code and the live site before checking anything: does it have user signup, does it send marketing email, does it charge a recurring subscription, does it let users upload or post content, does it run analytics or session replay, does it serve visitors in the EU or California. Record each answer. A check with no matching surface is N/A with that reason written down, never silently skipped.
2. Run all 6 checks below. For each one collect evidence, not impressions: the file and line, the network request, the screenshot, or the live flow result.
3. Split every finding into two lists. Fixable in code: Manto or the fleet agent fixes it in the same turn. Owner-only: only Ryan can do it (register an agent, supply a postal address, confirm legal entity name, accept a policy). Never mark an owner-only item done because the code side is ready.
4. Fix the code findings. Keep each fix minimal and in the shared place (one email footer component, one font load path, one consent gate), not patched per page.
5. Verify every fix on the real path. Load the live page and inspect network requests. Walk the signup flow. Walk the checkout flow. Send a test marketing email and click its unsubscribe link. A grep with no hits is secondary evidence only.
6. Report in the fixed format below. State what was not verified.

## The 6 checks

### 1. COPPA — no age gate at signup
- Law: US Children's Online Privacy Protection Act. Collecting personal information from a child under 13 without verifiable parental consent is a violation, up to about $53K per child (FTC civil penalty, inflation-adjusted — verify the current figure before quoting it).
- Look for: a signup or account creation flow with no age or date of birth question, no neutral age screen before collecting name or email, and no different path for under-13 users. Check the privacy policy for any mention of children.
- Evidence: signup form fields, the auth handler, and the result of a test signup claiming age under 13.
- Fix in code: add a neutral age gate before personal data collection. Block under-13 signup, or route it to a parental consent flow if the product intends to serve children. Do not just add a checkbox that says "I am 13 or older" to a product aimed at kids and call it fixed.
- Owner-only: decide whether the product targets children at all. If it does, this check stops here and goes to a lawyer — COPPA compliance for a kids product is more than a gate.

### 2. GDPR — externally loaded fonts and other IP-leaking resources
- Law: EU GDPR. Loading Google Fonts from Google servers sends every visitor IP address to Google without consent. A Munich court (LG München I, 20 Jan 2022) ordered a site to pay a visitor 100 euros for exactly this.
- Look for: `fonts.googleapis.com` and `fonts.gstatic.com` links, and the same pattern for any external resource loaded on page view without consent — CDN scripts, embeds, trackers, external images. Search the codebase and the built HTML for external hosts, then confirm with a live network capture.
- Evidence: the link tags or imports, plus the live page network log showing the external request.
- Fix in code: self-host the fonts. Download the woff2 files, serve them from the app own domain, and use `@font-face` locally, or use a self-hosted package such as Fontsource. Remove the external request entirely. Apply the same self-host or consent-gate treatment to any other non-essential external load found.
- Owner-only: none for fonts. For trackers or embeds that are the product, confirm whether EU visitors are in scope before consent-gating them.

### 3. CIPA — session replay recording users without consent
- Law: California Invasion of Privacy Act, section 631. Session replay that records keystrokes or form input without consent has been sued as wiretapping, up to $5K per violation. Other state wiretap laws raise the same risk.
- Look for: FullStory, Hotjar, Microsoft Clarity, LogRocket, Smartlook, PostHog session recording, OpenReplay, or any replay snippet. Check whether it is on by default, whether it captures form fields, passwords, or payment fields, and whether any consent banner actually blocks it before consent.
- Evidence: the snippet or package in code, its config (masking settings), and whether recording starts before a visitor interacts with a consent prompt.
- Fix in code: turn replay off by default and start it only after consent, or remove it if nobody uses the recordings. Where it stays, enable input masking for all text fields, and exclude auth, checkout, and settings pages entirely. Never record password or payment fields in any configuration.
- Owner-only: confirm the privacy policy discloses session recording if it remains enabled anywhere.

### 4. CAN-SPAM — marketing email with no unsubscribe or postal address
- Law: US CAN-SPAM Act. A marketing email with no working unsubscribe link or no physical postal address violates the Act, up to about $53K per email (FTC civil penalty, inflation-adjusted — verify the current figure before quoting it). Opt-outs must be honored within 10 business days.
- Look for: every marketing email template and send path (Resend, SendGrid, Mailchimp, Loops, custom SMTP). Distinguish marketing from transactional email (receipts, password resets) — CAN-SPAM applies to marketing, but a marketing message dressed as transactional gets no exemption. Check the From name and subject line are not deceptive.
- Evidence: a real test marketing email, received and inspected, with its unsubscribe link clicked through to a working opt-out.
- Fix in code: one shared email footer component carrying the unsubscribe link and postal address, used by every marketing template. Wire the unsubscribe to the provider suppression or opt-out list so it actually stops sends.
- Owner-only: supply a real physical postal address for the footer (a PO Box is acceptable). Manto never invents one and never uses a home address without Ryan saying so.

### 5. California Automatic Renewal Law — renewal terms not beside the subscribe button
- Law: California Business and Professions Code section 17600 and following, plus federal ROSCA. If renewal terms are not clear and conspicuous right next to the consent button, California treats each renewal as an unconditional gift — the money goes back to the customer. Easy cancellation is also required: cancel must be as easy as signup.
- Look for: the checkout or subscribe flow. Are price after trial, billing interval, renewal date or trigger, and how to cancel stated immediately adjacent to the subscribe button, not only in linked terms. Is there an explicit consent action for the renewal terms. Does a post-purchase acknowledgement go out with cancellation instructions. Can a user cancel online without calling or chatting support.
- Evidence: a screenshot of the checkout at the subscribe step, the acknowledgement email, and a walked cancellation flow.
- Fix in code: move the full renewal terms beside the subscribe button, add an explicit consent checkbox or equivalent affirmative action for auto-renewal, send the acknowledgement email with a direct cancel link, and build an online cancel path with the same number of steps as signup or fewer.
- Owner-only: confirm the exact renewal wording and trial terms match what billing (Stripe or other) will actually charge.

### 6. DMCA — no designated agent for user-uploaded content
- Law: US DMCA section 512 safe harbor. A service that hosts user uploads loses safe harbor protection without a designated agent registered with the Copyright Office. Willful infringement exposure runs up to $150K per work. Registration costs $6 through the Copyright Office DMCA Designated Agent Directory and must be renewed every 3 years.
- Look for: any user upload or posting surface — files, images, video, text posts, comments, avatars. Then look for a published DMCA page naming the agent and contact, a takedown intake path, and a repeat infringer policy in the terms.
- Evidence: the upload surfaces found, the DMCA page URL or its absence, and the terms section on repeat infringers.
- Fix in code: publish a `/dmca` page with agent name, organization, address, phone, and email (filled from the registration once it exists), add a takedown contact or form, and add the repeat infringer termination clause to the terms.
- Owner-only: register the agent at dmca.copyright.gov, pay the $6 fee, and calendar the 3-year renewal. Manto prepares the page and the exact registration steps. Manto does not register on Ryan behalf and does not invent agent details. If the app has no user content at all, this check is N/A — record that.

## Report format
One table or list, 6 rows, in the order above. Each row carries:
- Verdict: PASS, FAIL FIXED, FAIL OPEN, or N/A with the one-line reason.
- Evidence: file and line, network capture, screenshot, or live flow result.
- Fix applied: the change made, or none.
- Owner action: the exact remaining step for Ryan, or none.

Close the report with two short sections: what was not verified, and the owner-only list consolidated as a checklist Ryan can work through in one sitting.

## Rules and pitfalls
- This is a checklist, not legal advice, and a PASS here is not a claim that an app is legally compliant. Say so in every report. Jurisdiction, audience, and business model change the answer.
- Do not quote a penalty figure as current law without checking the current FTC or statutory figure first. The figures above are the source post figures, close to the 2025-2026 adjusted amounts.
- Do not fix only the homepage. Fonts, replay snippets, and email footers live in shared layouts and templates — check every route and every template, including error pages and auth pages.
- Do not treat a consent banner as a fix by itself. Verify the replay tool and external loads actually wait for consent in the network log.
- Do not put Ryan personal data, home address, or financials in any report, DMCA page draft, or email footer. Postal address for CAN-SPAM and DMCA comes from Ryan explicitly.
- A fleet brief that uses this skill must carry this skill name, require the report format above as the delivery, and keep owner-only items open until Ryan confirms them. Code fixes still ship under the standing push and deploy rule.
- When a check's fix would change product behavior (blocking under-13 users, gating replay, adding a renewal checkbox), do the fix and surface the behavior change in the report — do not skip the fix to avoid the change, and do not hide the change.

## Available connectors
- Use `muse.connector_search` to find other connectors and `muse.skill_search` to find related skills.
- If nothing here fits, look on the web for a maintained API or MCP server and set it up with [Custom Connectors and MCPs](/opt/muse/skills/custom-connector-setup/SKILL.md), or build a custom connector.
