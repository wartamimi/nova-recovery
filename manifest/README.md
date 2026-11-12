# Source manifests

- `nova_local.xml`: copied to `.repo/local_manifests/` by `scripts/sync.sh`.
- `pinned.xml`: created by the first successful `scripts/sync.sh` (`repo manifest -r`). It records the exact commit of every project. Commit it. Later syncs use it, so builds are reproducible. Refresh it on purpose with `scripts/sync.sh --update-pins`, then re-run the full test plan.

The upstream manifest repository itself is pinned in `nova/config/build.env` (`NOVA_MANIFEST_REV`).
