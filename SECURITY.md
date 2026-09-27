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

- The lock screen uses PAM and the Wayland session-lock protocol. Do not treat
  appearance alone as proof that the session is secured.
- The tracked `system/` files require root installation and affect sleep,
  kernel modules, and keyboard-backlight restoration.
- Helpers invoke local system services and utilities, including systemd,
  NetworkManager, BlueZ, PipeWire, `asusd`, and Niri IPC.
- The NetBird autostart entry starts third-party networking software when the
  optional `autostart` package is deployed.
- OpenCode and Neovim plugins can execute local commands and contact upstream
  services. Review their configuration and pinned revisions before use.

No credentials should be committed. Git identity belongs in
`~/.gitconfig.local`, outside this repository.
