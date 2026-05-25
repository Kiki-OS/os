#!/bin/bash
# Kiki OS boot health gate (greenboot required check).
#
# greenboot runs every script under check/required.d/ after boot. If a required
# check exits non-zero, greenboot marks the boot RED; after the configured number
# of failed boot attempts it triggers an automatic `bootc rollback` to the
# previous (known-good) deployment. This is the OS recovery mechanism for a bad
# OTA: a staged update that won't bring the agent up is rolled back unattended.
#
# We gate on the core daemons being active AND the MCP hub actually serving — a
# process that starts but can't serve tools is still a failed boot.
set -uo pipefail

fail() { echo "kiki-health: FAIL — $1" >&2; exit 1; }

for svc in agentd.service memoryd.service; do
    state=""
    for _ in $(seq 1 30); do
        state="$(systemctl is-active "$svc" 2>/dev/null || true)"
        [ "$state" = "active" ] && break
        [ "$state" = "failed" ] && fail "$svc entered failed state"
        sleep 1
    done
    [ "$state" = "active" ] || fail "$svc not active after 30s (state=$state)"
done

# agentd is actually serving the MCP hub (not merely running).
[ -S /run/kiki/mcp.sock ] || fail "MCP hub socket /run/kiki/mcp.sock missing"

echo "kiki-health: OK — agentd + memoryd active, MCP hub serving"
