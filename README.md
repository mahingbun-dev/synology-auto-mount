# synology-auto-mount

English | [简体中文](README.zh-CN.md)

![Platform](https://img.shields.io/badge/platform-macOS-black) ![License](https://img.shields.io/badge/license-MIT-green) ![Shell](https://img.shields.io/badge/shell-bash%20%2F%20sh-4EAA25)

**Keep a Synology (or any) SMB share mounted on macOS — through reboots, sleep/wake and network drops.**

The mounted share shows up in Finder and Terminal exactly like a local disk at `/Volumes/<share>`, and a tiny launchd watchdog re-attaches it within 60 seconds whenever it drops. No sudo, no plaintext passwords: the credentials live in your macOS keychain, saved by macOS itself.

## Why

Every "standard" way of auto-mounting an SMB share on macOS has a failure mode:

| Approach | Why it fails |
| --- | --- |
| Finder "Open at login" | Doesn't survive sleep/wake or network drops; flaky before the network is up |
| `/etc/fstab` | Mounts before the network is ready at boot; no retry afterwards |
| `autofs` | Known macOS bugs (mounts as root after reboot, no re-mount after wake) |
| `mount_smbfs` + CLI keychain entry | **Silently rejected** on modern macOS — Apple's partition check keeps `mount_smbfs` from reading entries created via `security add-internet-password`, and it never saves them itself |
| Synology Drive | Sync client, not a mount; duplicates data onto your local disk |

This project uses the one channel that actually works headlessly: **`osascript mount volume`** — the Finder auth stack. macOS saves the password to the keychain itself (during one credentialed mount at install time), creates `/Volumes/<share>` for you (no sudo), and every 60 seconds a LaunchAgent re-mounts the share if it isn't mounted.

## Install

```sh
git clone https://github.com/mahingbun-dev/synology-auto-mount.git
cd synology-auto-mount
./install.sh                          # interactive
./install.sh HOST SHARE USER 'PASS'   # non-interactive
```

Example:

```sh
./install.sh 192.168.31.165 MacHardDrive Mr.Ma 'password123'
```

`SHARE` is the shared-folder name as configured in DSM (Control Panel → Shared Folders) — not a `/volume2/...` path. A subfolder of a share can be targeted as `SHARE/subfolder`.

What the installer does, in order:

1. Preflight: checks the NAS answers on port 445.
2. Connects once with credentials — macOS stores the password in your **login keychain**.
3. Generates the watchdog script at `~/.local/bin/synology-automount.sh`.
4. Unmounts and re-mounts **without a password** to prove the keychain path works.
5. Installs and loads `~/Library/LaunchAgents/dev.mahingbun.synology-automount.plist` (`RunAtLoad` + `StartInterval=60`).

## Verify

```sh
mount | grep smbfs                                # the share, (smbfs, ...)
diskutil unmount /Volumes/<share>                 # eject it…
# …within 60 seconds it is back:
mount | grep smbfs
tail -n 20 ~/Library/Logs/synology-automount.log  # what the watchdog did
```

Reboot the Mac — the volume re-appears at login without any prompt.

## How it stays out of your way

- **Already mounted** → the script exits instantly.
- **NAS unreachable** (off-network, NAS asleep) → a 2-second TCP probe exits before any Apple-event hang or password dialog can appear.
- **Unreachable / reachable-but-dropped** states are logged to `~/Library/Logs/synology-automount.log`.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| "First mount failed" | Wrong credentials, or SMB service off in DSM. Test once in Finder: `Cmd+K` → `smb://host` |
| Passwordless remount fails | In Finder `Cmd+K`, connect to the share and tick **"Remember this password in my keychain"**, then re-run `install.sh` |
| Mount is listed but file access hangs (stale mount after sleep) | `diskutil unmount force /Volumes/<share>` — the watchdog re-mounts it |
| Want to pause auto-remount | `launchctl unload ~/Library/LaunchAgents/dev.mahingbun.synology-automount.plist` (and `load` to resume) |
| Time Machine keeps noticing the volume | If the share contains a `.sparsebundle`, macOS may offer it as a backup destination — just decline |

## Uninstall

```sh
./uninstall.sh
```

Removes the LaunchAgent and watchdog script; optionally unmounts the volume and deletes the keychain entry.

## Security notes

- The password is stored **only** in your login keychain, by macOS itself. No config file, dotfile or repository contains it.
- The install script accepts the password as an argument (`./install.sh … 'PASS'`) for agent/CI use — it appears in the process list only for the duration of the install.
- All files installed are user-owned; nothing runs as root.

## Requirements

- macOS — no third-party dependencies (developed and tested on macOS 26/27)
- A Synology NAS (or any SMB server) with the SMB service enabled — tested against DSM 7.4

## License

[MIT](LICENSE.md)
