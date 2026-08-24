# Clean fixture
Run `./scripts/real.sh` to start.
See [the manifest](scripts/installer-skeleton-manifest.txt).

A correctly guarded optional step:

```bash
[ -f scripts/optional.sh ] && bash scripts/optional.sh
```
