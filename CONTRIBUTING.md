# Contributing

Keep code, documentation, issue text and commit messages in English. Start with a narrow reproducible problem and observable evidence. Do not upload personal environment dumps, passwords, tokens, Keychain exports or screenshots of a real user's desktop.

Run the commands in README.md. Add tests for meaningful safety behavior and call ordering, not just matching implementation strings. Fixtures must be synthetic. Never place a real credential in tests or CI. Preserve one-attempt limits, local consent, fail-closed guards and explicit unknown outcomes.

Changing app identity, signing, permissions, target checks or credential storage requires renewed source review and a new live enrollment/test on the owner's Mac. Public CI cannot substitute for physical GUI evidence. Record OS/build, helper version, exact action, observed result and untested cases in VERIFICATION.md. Label unverified variants experimental.

Before each push, run `scripts/scan.sh` and inspect the Git diff and file list. A clean scanner is supporting evidence, not proof that arbitrary text contains no private information. Do not ship build products or local receipts. Disclose vulnerabilities through SECURITY.md rather than a public exploit report.
