# Dirty fixture
Run `./scripts/ghost.sh` to start.
See [the guide](docs/NOPE.md).

A guard on the wrong file must not excuse the command:

```bash
[ -f scripts/real.sh ] && bash scripts/ghost.sh
```
