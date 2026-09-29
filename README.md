# claude-multi-profile-sync-drive

Shell scripts to sync [Claude Code](https://claude.com/claude-code) data
(projects, memory, session transcripts, `settings.json`, `CLAUDE.md`) to cloud
storage via [rclone](https://rclone.org/).

Two use cases:

1. **Keeping the same files in sync across devices** (e.g. laptop + desktop).
2. **Strict separation of multiple Claude logins** (e.g. a private and a work
   profile) by giving each profile its own config directory via
   [`CLAUDE_CONFIG_DIR`](https://docs.claude.com/en/docs/claude-code) **and**
   its own cloud account — deliberately *not* `~/.claude`, see
   [below](#why-not-homeclaude).

## Quickstart

1. Set up an rclone remote for each profile: `rclone config`
   (e.g. a separate Google Drive account per profile, for strict separation).
2. Copy the profile template(s) you need and edit them:
   ```sh
   cp profiles/private.conf.example profiles/private.conf
   $EDITOR profiles/private.conf   # fill in REMOTE, PROJECTS, CFG
   ```
   Only need one profile? Just copy that one `*.conf.example` file — no need
   to touch the others.
3. At session **start**: `./claude-pull <profile>`
   At session **end**: `./claude-push <profile>`

`<profile>` is the file name (without `.conf`) under `profiles/`
(e.g. `private` / `work`).

⚠️ This repo is my personal setup, not a drop-in universal solution —
you'll need to adapt the paths in your `profiles/*.conf` files to your own
environment.

---

## The scripts

| Script | Purpose |
|---|---|
| `claude-pull <profile>` | Fetches project data, memory (incl. transcripts), `settings.json`, `CLAUDE.md`, `bin/`, `docs/`, `tmp/` from the cloud. Run at session **start**. |
| `claude-push <profile>` | Backs up the same categories to the cloud. Run at session **end**. Checks beforehand that the local source folders exist (otherwise a moved/deleted directory would empty the cloud copy). |
| `profiles/*.conf.example` / `profiles/*.conf` | Profile definitions (remote, local paths), one file per profile. The `.example` files are checked in as templates, the plain `.conf` files hold your real values and are gitignored (see [Setup](#setup)). |
| `claude-sync-report <profile>` | Size/content overview (local state) by category and project. Automatically called at the end of `pull`/`push`. |

## Security notes

- **Everything ends up in the cloud unfiltered** — including session
  transcripts, which may contain sensitive content (passwords, API keys,
  personal data). Secure cloud accounts with a password + two-factor
  authentication. Claude credentials (`.credentials.json`) are **not**
  synced.
- **Mirror risk:** `claude-push` deletes in the cloud whatever is missing
  locally; `claude-pull` deletes locally whatever is missing in the cloud.
  Rule of thumb: session **start** → `claude-pull`, **end** → `claude-push`.
  Otherwise a pull can overwrite newer, not-yet-pushed work.
- With most cloud providers, deleted files/projects stay recoverable in the
  trash for a while (a temporary emergency backup — e.g. ~30 days on Google
  Drive), then are gone for good.

## Setup

Each profile is one file `profiles/<name>.conf`, defining three variables:

```sh
REMOTE="myprivate_remote:claude-sync"        # rclone remote:path
PROJECTS="$HOME/Projects/claude-private"     # local project folder
CFG="$HOME/.claude-private"                  # this profile's CLAUDE_CONFIG_DIR
```

`MEM` (the memory + transcript directory) is derived automatically as
`$CFG/projects` — no need to set it. Adding a new profile just means adding a
new `profiles/<name>.conf` file, nothing else to touch. The plain `.conf`
files are gitignored (see `.gitignore`); `profiles/*.conf.example` are
checked in and show the format.

## Why not `~/.claude`?

When Claude Code starts, it walks up from the current directory to the
filesystem root and checks *every* directory along the way for `CLAUDE.md`
and `.claude/CLAUDE.md`. `~/.claude` is additionally **always loaded
automatically**, regardless of `CLAUDE_CONFIG_DIR` — this cannot be turned
off. If you want strict separation between two profiles (e.g. private/work,
with different Claude logins), neither profile may live in `~/.claude`,
otherwise its memory/config bleeds into every session of the other profile.

That's why the profiles here use their own directory names, like
`~/.claude-private` and `~/.claude-work`, activated via:

```sh
export CLAUDE_CONFIG_DIR="$HOME/.claude-private"
```

(e.g. as a per-profile shell alias, or set per project.)

## Requirements

- [`rclone`](https://rclone.org/) installed and configured for the desired
  cloud remotes via `rclone config`.
- POSIX `sh` (the scripts avoid bashisms).

## License

[MIT](LICENSE)
