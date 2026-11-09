# claude-multi-profile-sync-rclone

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
   Not sure what a run would do? Add the option `-n` (`--dry-run`) first.

`<profile>` is the file name (without `.conf`) under `profiles/`
(e.g. `private` / `work`).

⚠️ This repo is my personal setup, not a drop-in universal solution —
you'll need to adapt the paths in your `profiles/*.conf` files to your own
environment.

---

## The scripts

| Script | Purpose |
|---|---|
| `claude-pull [-n] <profile>` | Fetches project data, memory (incl. transcripts), `settings.json`, `CLAUDE.md`, `bin/`, `docs/`, `tmp/` (and `skills/`, see [Skills](#skills)) from the cloud. Run at session **start**. |
| `claude-push [-n] <profile>` | Backs up the same categories to the cloud. Run at session **end**. Checks beforehand that the local source folders exist (otherwise a moved/deleted directory would empty the cloud copy). |
| `profiles/*.conf.example` / `profiles/*.conf` | Profile definitions (remote, local paths), one file per profile. The `.example` files are checked in as templates, the plain `.conf` files hold your real values and are gitignored (see [Setup](#setup)). |
| `claude-profile [-c] [-n] <profile> [claude options]` | Starts `claude` with the profile's `CLAUDE_CONFIG_DIR` (replaces per-profile shell aliases/functions). Starts in the **current** directory; `-c`/`--cd` changes to the profile's `PROJECTS` first. Asks for confirmation if started inside the project tree of another profile. Options after the profile name go to `claude` unchanged. |
| `claude-sync-report <profile>` | Size/content overview (local state) by category and project. Automatically called at the end of `pull`/`push`. |

### Options

| Option | Meaning |
|---|---|
| `-n`, `--dry-run` | `claude-pull`/`claude-push`: shows what would be transferred or deleted, changes nothing. Use it for the first run on a new machine. `claude-profile`: only prints what would be started. |
| `-c`, `--cd` | `claude-profile` only: change to the profile's `PROJECTS` directory before starting. |
| `-h`, `--help` | Usage and the list of available profiles. |

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

`CFG` is optional and defaults to `$HOME/.claude-<profile>`. Optional extra variable:

```sh
SYNC_SKILLS=1                                # also sync $CFG/skills (see below)
```

`MEM` (the memory + transcript directory) is derived automatically as
`$CFG/projects` — no need to set it. Adding a new profile just means adding a
new `profiles/<name>.conf` file, nothing else to touch. The plain `.conf`
files are gitignored (see `.gitignore`); `profiles/*.conf.example` are
checked in and show the format.

## Per-project `tmp/` and `docs/`

Nothing extra is needed for them: if the workspace folder (`PROJECTS`) contains
`projects/<name>/tmp/` and `projects/<name>/docs/`, they travel with step 1
(`PROJECTS` ⇄ `$REMOTE/projects`) like every other project file. Only
`node_modules/`, `.git/` and `.DS_Store` are excluded. The `bin/`, `docs/` and
`tmp/` steps in the scripts refer to the **profile** directory (`$CFG/...`),
not to the per-project folders.

## Skills

With `SYNC_SKILLS=1` in a profile, `$CFG/skills/` is synced to `$REMOTE/skills/`
using `rclone copy --update`:

- **Nothing is ever deleted**, on either side (a removed skill has to be
  removed by hand on the other machine).
- A file is only transferred if the source is **newer** than the target, so a
  pull on a machine with newer skills can't overwrite its work.
- `skills/synced/` is excluded: it is managed by claude.ai itself and bound to
  the account, so it must not get a second sync path.
- `*.bak-*` backup files stay local.

Profiles without `SYNC_SKILLS=1` (e.g. a private profile) don't touch skills at
all.

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

`claude-profile <profile>` does exactly that, reading `CFG` and `PROJECTS` from
`profiles/<profile>.conf` — one source of truth for sync **and** start (no
hard-coded paths in shell aliases/functions):

```sh
claude-profile work              # start in the current directory
claude-profile -c work           # start in the profile's PROJECTS directory
claude-profile work --resume     # options after the profile go to claude
```

## Requirements

- [`rclone`](https://rclone.org/) installed and configured for the desired
  cloud remotes via `rclone config`.
- POSIX `sh` (the scripts avoid bashisms).

## License

[MIT](LICENSE)
