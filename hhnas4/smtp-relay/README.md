# SMTP Relay Placeholder

This directory is currently an intentional placeholder only.

## Current state

- There is no live Synology SMTP relay stack committed here.
- The directory was empty when audited on 2026-03-17.
- Homelab SMTP relay traffic currently points at the relay running on
  `relay-host.internal.example`, not at `hhnas4`.

## Why this exists

- It likely reflects an earlier plan to host a relay on Synology.
- Keeping this README avoids future confusion during incident response by making
  it explicit that there is nothing to deploy from this directory today.

If a Synology relay is added later, replace this file with service-specific
deployment and validation documentation.
