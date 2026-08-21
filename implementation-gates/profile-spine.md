# Gates: Profile Spine

Scope: Opt-in profile resolution, clean-user installation, and Codex smoke compatibility.

- [x] G1: Missing config resolves to generic and valid client config resolves to the shipped profile.
  CHECK: bash scripts/verify-profile-resolution.sh
  EXPECT: profile resolution: PASS
  EVIDENCE: `bash scripts/verify-profile-resolution.sh` prints `profile resolution: PASS`; fixtures cover absent config, configured selection, named override, and generic override.

- [x] G2: Invalid/missing profiles fail with setup exit code 2 and actionable output.
  CHECK: bash scripts/verify-profile-resolution.sh
  EXPECT: invalid profile rejected
  EVIDENCE: The verifier prints `invalid profile rejected` after asserting exit 2 plus `profile setup error:` for malformed config, missing keys/manifests, invalid versions, mismatches, and traversal names.

- [x] G3: Fresh installer/package manifests contain profile runtime assets while leaving profile inactive.
  CHECK: bash scripts/verify-create-context-compiler.sh
  EXPECT: Passed
  EVIDENCE: Installer verifier passes all checks; its file-granular manifest includes `profile-resolve.py`, `use-profile.sh`, and `profiles/client-decision/profile.json` but excludes `context-profile.json`. Packaging conditionally copies `profiles/` plus activation config.

- [x] G4: Codex smoke registry supports a temporary non-git wiki without the trusted-directory failure.
  CHECK: rg -n -- '--skip-git-repo-check' scripts/smoke-tool.sh
  EXPECT: skip-git-repo-check
  EVIDENCE: `rg -n -- '--skip-git-repo-check' scripts/smoke-tool.sh` finds the flag in the Codex registry invocation.
