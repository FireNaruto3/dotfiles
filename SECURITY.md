# Security Policy

## Supported Version

Only the current `main` branch is maintained. This is a personal configuration
repository, not a hardened distribution; review every command and path before
deploying it on another system.

## Reporting

Report a suspected vulnerability through GitHub's private security advisory
feature. Do not include passwords, tokens, private keys, private hostnames, or
other live credentials in an issue, pull request, or log attachment.

## Security-Relevant Behavior

- The lock screen uses the dedicated `quickshell-lock` PAM service and the
  Wayland session-lock protocol. Do not treat appearance alone as proof that the
  session is secured. Restart, power-off, and user-wide logout actions require
  successful password authentication; sleep requires confirmation.
- Lock acquisition fails closed for suspend. The system suspend precondition
  locates the active local Wayland session, invokes a bounded user service, and
  aborts suspend if the dedicated lock-shell process does not report a secured
  protocol lock. Its auth-private journal messages may contain session metadata
  and should be shared only after review.
- The tracked `system/` files require root installation and affect sleep,
  critical-battery shutdown, PAM, kernel modules, and keyboard-backlight
  restoration. UPower is configured to power off at 2%, after 20% low and 5%
  critical thresholds, because hibernation is unavailable under kernel
  lockdown.
- `asusctl` commands mutate daemon-owned files under `/etc/asusd`. The setup
  disables the keyboard firmware's sleep animation while retaining boot,
  awake, and shutdown lighting; fan curves, charge limits, and other ASUS state
  remain machine-local and should not be assumed safe on different hardware.
- Helpers invoke local system services and utilities, including systemd,
  NetworkManager, BlueZ, PipeWire, `asusd`, and Niri IPC.
- The NetBird autostart entry starts third-party networking software when the
  optional `autostart` package is deployed.
- OpenCode and Neovim plugins can execute local commands and contact upstream
  services. Review their configuration and pinned revisions before use.

No credentials should be committed. Git identity belongs in
`~/.gitconfig.local`, outside this repository.
