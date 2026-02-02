---
name: github-workflows
description: Manages CI/CD pipelines for OpenWrt firmware building. Use when modifying build steps, cache strategies, or troubleshooting CI failures.
---

## Cache Management

Workflows implement two critical cache strategies:
1. Preemptive cleanup: `github.com/mdlayher/socket@v0.5.1` is removed from `/workdir/openwrt/dl/go-mod-cache` before restoration to prevent corruption.
2. Timestamp refresh: `staging_dir` timestamps are updated after cache restore to prevent `make` from flagging toolchain files as outdated.

## Debugging

SSH debugging can be enabled via `workflow_dispatch` input ('SSH 远程调试'). Uses `mxschmitt/action-tmate` to pause the workflow and provide a remote shell for troubleshooting.

## Workflows

`build.yml`: Main ImmortalWrt build pipeline.
`libwrt.yml`: Specialized build for LiBwrt (Kernel 6.6) targeting JD Cloud devices.
`test-mosdns.yml`: Isolated build test for `mosdns` package to verify cache fixes.

## Related files

- `.github/workflows/build.yml`
- `.github/workflows/libwrt.yml`
- `.github/workflows/test-mosdns.yml`
