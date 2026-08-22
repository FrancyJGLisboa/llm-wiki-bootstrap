# Gates: Universal evidence intake

Scope: Make adding arbitrary evidence a direct choose, drop, paste, link, or inbox action while preserving every original and reporting extraction limitations honestly.

- [x] G1: The primary Add Evidence action opens the universal file/folder chooser immediately, without an intermediate modality menu.
  CHECK: bash scripts/verify-vscode-extension.sh
  EXPECT: /universal intake: PASS/
  EVIDENCE: `verify-vscode-extension.sh` printed `universal intake: PASS`.

- [x] G2: Files and folders dropped onto the Context Workspace sidebar are staged through the same safe boundary.
  CHECK: node --test tests/vscode-extension/*.test.js
  EXPECT: /fail 0/
  EVIDENCE: Node test suite passed 10/10, including URI-list drop parsing.

- [x] G3: Clipboard intake detects text versus one-or-many HTTP(S) links; text uses stdin and links require explicit network consent.
  CHECK: node --test tests/vscode-extension/*.test.js
  EXPECT: /fail 0/
  EVIDENCE: Node test suite passed 10/10, including clipboard classification and safe stdin routing.

- [x] G4: Arbitrary regular files are preserved even without a known extractor, and the user sees added, unchanged, degraded, and failed outcomes instead of a false all-success message.
  CHECK: bash scripts/verify-vscode-extension.sh
  EXPECT: /arbitrary preservation: PASS/
  EVIDENCE: Arbitrary `.unknown-binary` fixture passed byte-for-byte; verifier printed `arbitrary preservation: PASS`.

- [x] G5: Fresh compiler guidance, extension walkthrough, README, and GitHub page all present the same universal intake without claiming universal extraction.
  CHECK: bash scripts/verify-vscode-extension.sh
  EXPECT: /intake guidance: PASS/
  EVIDENCE: Static cross-surface assertions printed `intake guidance: PASS`; site claim verifier passed.

- [x] G6: The VSIX remains reproducible/installable, npm audit is clean, and all generic/profile regressions remain green.
  CHECK: bash scripts/vscode-extension-regression.sh
  EXPECT: /VS Code extension regression: PASS/
  EVIDENCE: VSIX SHA-256 `734fe44415ea0330c89f45b12e3c3632f680c2f519c68711629d689eabe2b41a`; install passed; npm audit found 0 vulnerabilities; all 57 checks green.
