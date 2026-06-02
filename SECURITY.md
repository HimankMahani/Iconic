# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

Only the latest minor release line receives security updates. Please upgrade before reporting.

## Reporting a Vulnerability

**Preferred (private):** Open a GitHub Security Advisory:

https://github.com/HimankMahani/Iconic/security/advisories/new

This keeps the report private until a fix is ready and a CVE/advisory is published.

**Backup (email):** `[INSERT CONTACT EMAIL]`

Use email only if the GitHub Advisory path is unavailable. Encrypt sensitive details (e.g. proof-of-concept code) at your discretion.

Please **do not** file a public GitHub issue, discussion, or pull request for security bugs.

## What to Expect

| Step                          | Timeline              |
| ----------------------------- | --------------------- |
| Acknowledgement               | within 3 business days |
| Initial triage & severity     | within 7 business days |
| Patch for high-severity issues | within 30 days        |

We follow coordinated disclosure: we ask that you give us a reasonable window to patch before publishing details. We are happy to credit reporters in the advisory (under whatever name/handle you prefer) and to coordinate disclosure timing with you.

If a report turns out to be out of scope or not a vulnerability, we will explain why.

## Scope

In-scope security concerns for Iconic include:

- **macOS sandbox / TCC bypasses** — ways the app escapes its declared entitlements, reads protected user data without consent, or prompts for permissions it does not actually need.
- **Keychain handling** — anything that causes the user-supplied Gemini API key to leak (e.g. writing it to disk in plaintext, logging it, exposing it to other processes or over the network).
- **Local file-system access** — path traversal, symlink-following bugs, or other issues that let the app read/write outside the folders the user explicitly selected (e.g. via crafted folder/alias paths).
- **Network calls** — MITM, TLS validation, or credential-handling issues affecting the one outbound call the app makes: requests to the Google Gemini API.
- **Crashes or data loss from malformed input** — denial-of-service or corruption triggered by crafted folder names, symlink loops, broken aliases, malformed image inputs, or unexpected API responses.
- **Code-signing / notarization** — anything that weakens Gatekeeper, code-signing, or Hardened Runtime guarantees on the shipped binary.

## Out of Scope

The following are **not** security issues for this project:

- **SIP-protected folders cannot be iconified** (e.g. `/System`, `/usr`, the boot volume root). This is a macOS-imposed limitation, not a bug. Apple will not grant the entitlement that would be required to override it.
- **Bugs in SF Symbol or emoji rendering.** These are upstream Apple issues — file a normal bug report.
- **Feature requests or UX complaints** about permission prompts, file pickers, etc. — not security concerns.
- **Reports against versions that are not in the Supported Versions table above.**
- **Theoretical issues** with no reproducible impact on a default install.

## Disclosure Policy

We practice **coordinated disclosure**:

1. Reporter sends details privately (GitHub Advisory or email).
2. We acknowledge, triage, and develop a fix on a private branch.
3. We release the fix and publish a GitHub Security Advisory (and CVE, if applicable) at the same time, crediting the reporter by their chosen name/handle.
4. Details are public from the moment the advisory is published.

Please do not disclose the vulnerability publicly (blog post, tweet, public issue, etc.) until the advisory is published or we have agreed on a disclosure date.

## Past Advisories

None yet. The project is just being open-sourced. As advisories are published they will be listed here:

- _No advisories to date._

## Notes

Iconic is a local macOS app. It does not run a server, does not collect telemetry, and only makes one optional outbound network call (Google Gemini) when the user supplies an API key. The attack surface is small and largely confined to the user's own machine, but we still want to hear about anything that can be exploited.
