# multi-claude

**Use several Claude accounts (personal + Team + as many others as you like) in Claude Code on the same machine, and carry a conversation from one account to another when you hit a usage limit.**

After a default setup you have two commands (add more with `./setup.sh <name> ...` — see [Adding more accounts](#5a-adding-more-accounts)):

| Command | Account | Config folder |
|---|---|---|
| `claude` | Personal (your default — unchanged) | `~/.claude` |
| `claude-team` | Team | `~/.claude-team` |
| `claude-<name>` | Any extra account you add | `~/.claude-<name>` |

All profiles share your settings, `CLAUDE.md`, skills, agents, slash commands **and your conversation history**, so this works:

```bash
claude            # working on a project with the personal account... usage limit hit
claude-team -c    # same folder → continues the exact same conversation on the Team account
```

Works on **macOS and Linux**, with **zsh or bash**. Setup takes about two minutes per machine.

---

## Contents

1. [Why this is needed](#1-why-this-is-needed)
2. [Setup — step by step](#2-setup--step-by-step)
3. [Check it worked](#3-check-it-worked)
4. [Daily use](#4-daily-use)
5. [Switching accounts mid-conversation](#5-switching-accounts-mid-conversation)
   - [Adding more accounts](#5a-adding-more-accounts)
6. [What the script actually does](#6-what-the-script-actually-does)
7. [Manual setup (no script)](#7-manual-setup-no-script)
8. [Troubleshooting](#8-troubleshooting)
9. [Caveats](#9-caveats)
10. [Undo](#10-undo)
11. [References](#11-references)

---

## 1. Why this is needed

The Claude desktop/web app has an account switcher. **Claude Code does not.** Running `/login` simply replaces whichever login is stored, so swapping accounts the naive way means `/logout` → `/login` → browser sign-in every single time.

The way around it: Claude Code keeps *everything* — your login token, settings, and conversation transcripts — inside one config folder, normally `~/.claude`. The environment variable **`CLAUDE_CONFIG_DIR`** tells it to use a different folder instead. So:

- `claude` (no variable set) → uses `~/.claude` → logged in as **personal**
- `CLAUDE_CONFIG_DIR=~/.claude-team claude` → uses `~/.claude-team` → logged in as **Team**

`claude-team` is just a shell alias for that second command.

Conversation transcripts are plain files stored at `<config folder>/projects/<your-project-path>/<session-id>.jsonl`, and they are **not tied to the account that created them**. By pointing `~/.claude-team/projects` at `~/.claude/projects` (a symlink), both accounts read and write the same history, which is what makes `claude-team -c` pick up where `claude` left off.

---

## 2. Setup — step by step

Do this on each machine.

### Step 1 — Make sure Claude Code is installed and logged in with your personal account

```bash
claude
```

If this opens a Claude Code session and `/status` shows your personal email, you're ready. If `claude` isn't found, install it first: <https://code.claude.com/docs/en/setup>. Type `exit` to leave the session.

### Step 2 — Get this repo and run the setup script

```bash
git clone https://github.com/jamesruffle/multi-claude.git
cd multi-claude
./setup.sh
```

You'll see output like:

```
Team config dir: /home/you/.claude-team
Sharing files:
  link     /home/you/.claude-team/settings.json -> /home/you/.claude/settings.json
  link     /home/you/.claude-team/CLAUDE.md -> /home/you/.claude/CLAUDE.md
Sharing directories:
  link     /home/you/.claude-team/projects -> /home/you/.claude/projects
  link     /home/you/.claude-team/skills -> /home/you/.claude/skills
  link     /home/you/.claude-team/agents -> /home/you/.claude/agents
  link     /home/you/.claude-team/commands -> /home/you/.claude/commands
Added alias to /home/you/.bashrc

Done. Next steps: ...
```

The script is safe to run more than once — it only adds what's missing and never deletes anything.

Want more than one extra account? Pass the names you want instead — each name `X` becomes a `claude-X` command:

```bash
./setup.sh team work lab     # -> claude-team, claude-work, claude-lab
```

### Step 3 — Reload your shell so the new alias exists

Pick the one that matches your shell (the script's final message tells you which file it edited):

```bash
source ~/.zshrc           # macOS default (zsh)
source ~/.bashrc          # Linux (bash)
source ~/.bash_profile    # macOS if you use bash
```

Or just open a new terminal window.

### Step 4 — Log the Team profile in (one-off)

```bash
claude-team
```

Because `~/.claude-team` has never been logged in, Claude Code runs its first-launch setup and opens your browser. **Sign in with the Team account** (not personal). When the browser confirms, return to the terminal.

Your normal `claude` command is completely untouched by this — it stays logged in as personal.

---

## 3. Check it worked

Inside the `claude-team` session you just opened, type:

```
/status
```

It should show the **Team** email address and organisation. Type `exit`.

Now run plain `claude` and `/status` again — it should still show your **personal** account. Type `exit`.

If both are correct, setup is complete.

---

## 4. Daily use

```bash
claude            # personal account
claude-team       # Team account
```

- You can have both open at the same time in different terminal windows/tabs.
- All normal flags work with either: `claude-team -c`, `claude-team -r`, `claude-team -p "..."`, etc.
- Settings changes made in one apply to both (they share the same `settings.json`).
- Skills, subagents and custom slash commands you add are available in both.

---

## 5. Switching accounts mid-conversation

This is the main reason for the setup. Say you're deep in a coding session with the personal account and hit the usage limit.

**From the same project folder**, run:

```bash
claude-team -c
```

`-c` (`--continue`) resumes the **most recent conversation in the current folder**, regardless of which account started it. You're now on the Team account with the full context intact. The same works in reverse (`claude -c` after a `claude-team` session).

Other useful options:

| Command | What it does |
|---|---|
| `claude-team -c` | Continue the most recent conversation in this folder |
| `claude-team -r` | Show a picker of recent conversations in this folder and choose one |
| `claude-team -r <session-id>` | Resume a specific conversation by ID (searches all your projects) |
| `claude-team -c --fork-session` | Continue as a *copy*, leaving the original transcript untouched |

Tips:

- **Same folder matters.** `-c` looks at the folder you're in. If you started in `~/code/myproject`, run `claude-team -c` from `~/code/myproject`.
- **Compact first if you can.** If you see the limit coming, type `/compact` before you leave; the resumed session then starts from a tidy summary instead of the whole transcript.
- **First-time trust prompt.** The first time the Team profile opens a given project folder, Claude Code asks you to trust that folder again. That's normal — trust is stored per profile — and only happens once per folder.

---

### 5a. Adding more accounts

You can add as many accounts as you need, at any time — including on a machine that already has `claude-team`:

```bash
cd multi-claude && git pull
./setup.sh work                  # adds claude-work  (~/.claude-work)
./setup.sh lab1 lab2 grant-xyz   # adds several at once
source ~/.bashrc                 # or ~/.zshrc
claude-work                      # first launch: sign in with that account
```

Names may contain letters, digits, `-` and `_`. `work` and `claude-work` are treated the same. Re-running with a name that already exists just checks its links.

Manage profiles:

| Command | What it does |
|---|---|
| `./setup.sh --list` | Show every profile installed in your rc file and whether its folder exists |
| `./setup.sh --remove work` | Remove the `claude-work` alias; asks before deleting `~/.claude-work` (its login + local state) |
| `./setup.sh --help` | Usage summary |

Every profile shares the same `projects/` history, so you can hop along a chain of accounts: `claude` → `claude-team -c` → `claude-work -c` → …

---

## 6. What the script actually does

For each profile name (default: `team`), `setup.sh` performs four things, all idempotent:

1. **Creates `~/.claude-<name>`** (e.g. `~/.claude-team`) — that profile's config folder.
2. **Symlinks shared files** so both profiles behave identically:
   - `~/.claude-team/settings.json` → `~/.claude/settings.json`
   - `~/.claude-team/CLAUDE.md` → `~/.claude/CLAUDE.md`
   (skipped if the personal file doesn't exist)
3. **Symlinks shared folders** (created in `~/.claude` first if missing):
   - `projects/` — conversation history (this is what makes `-c` work across accounts)
   - `skills/`, `agents/`, `commands/` — your personal skills, subagents and slash commands
4. **Adds one alias line** to your shell rc file:
   ```bash
   alias claude-team='CLAUDE_CONFIG_DIR=/home/you/.claude-team claude'
   ```
   The file is chosen by your shell and OS: `~/.zshrc` (zsh), `~/.bashrc` (bash on Linux), `~/.bash_profile` (bash on macOS), `~/.profile` (anything else).

What stays **separate** between the profiles (deliberately):

- `.credentials.json` — the login token. This is the whole point.
- `.claude.json` — per-profile state such as onboarding, folder-trust decisions and MCP servers.
- `history.jsonl` — the prompt-history file used for up-arrow recall.

Safety: if the script finds a real file or folder (not a symlink) where it wants to put a link, it moves it aside as `<name>.bak.<timestamp>` rather than deleting it.

When run with **no names**, the legacy overrides still work for a single custom profile:

```bash
CLAUDE_TEAM_DIR=~/.claude-work CLAUDE_TEAM_ALIAS=claude-work ./setup.sh
```

With names, the folder is always `~/.claude-<name>` and the command `claude-<name>`.

---

## 7. Manual setup (no script)

Exactly what the script does, by hand:

```bash
mkdir -p ~/.claude-team ~/.claude/projects ~/.claude/skills ~/.claude/agents ~/.claude/commands

ln -sfn ~/.claude/settings.json ~/.claude-team/settings.json
ln -sfn ~/.claude/CLAUDE.md     ~/.claude-team/CLAUDE.md
ln -sfn ~/.claude/projects      ~/.claude-team/projects
ln -sfn ~/.claude/skills        ~/.claude-team/skills
ln -sfn ~/.claude/agents        ~/.claude-team/agents
ln -sfn ~/.claude/commands      ~/.claude-team/commands

# Add to ~/.zshrc (macOS) or ~/.bashrc (Linux):
alias claude-team='CLAUDE_CONFIG_DIR=$HOME/.claude-team claude'
```

Then `source` your rc file and run `claude-team` to log in.

---

## 8. Troubleshooting

**`claude-team: command not found`**
The alias isn't loaded in this terminal. Run `source ~/.zshrc` (or `~/.bashrc`) or open a new terminal. Check the alias line is present with `grep claude-team ~/.zshrc ~/.bashrc ~/.bash_profile 2>/dev/null`.

**`claude-team` shows my personal account in `/status`**
The alias probably isn't taking effect (see above), or `CLAUDE_CONFIG_DIR` is already exported globally somewhere. Run `echo $CLAUDE_CONFIG_DIR` in a fresh terminal — it should be empty.

**`claude-team -c` says there's no conversation to continue**
- Are you in the same folder the original session ran in? `-c` is per-folder.
- Is `~/.claude-team/projects` a symlink? `ls -la ~/.claude-team` should show `projects -> /…/.claude/projects`. If not, re-run `./setup.sh`.
- Has the transcript expired? Transcripts are deleted after 30 days by default (`cleanupPeriodDays` in `settings.json`).

**Setup script says `'claude' not found on PATH`**
Install Claude Code first: <https://code.claude.com/docs/en/setup>.

**Setup script says `~/.claude does not exist`**
Run `claude` once and complete login with your personal account, then re-run the script.

**Claude Code exits on startup complaining about the organisation**
Your Team organisation may enforce `forceLoginOrgUUID` in managed settings, which refuses credentials from any other org. See Caveats.

**I want to resume a specific transcript without the shared `projects/` link**
Resuming by absolute file path is supported and works across profiles:

```bash
ls -t ~/.claude/projects/-Users-you-myproject/*.jsonl | head -1     # newest transcript
claude-team --resume ~/.claude/projects/-Users-you-myproject/<session-id>.jsonl
```

---

## 9. Caveats

- **Sharing `projects/` between config folders is not described in the Claude Code docs.** Resuming a transcript by path *is* documented, and a transcript is just a file, so this works today — but if a future release changes transcript handling, fall back to `--resume <path>` above.
- **Transcript retention** is 30 days by default (`cleanupPeriodDays` in `settings.json`, shared by both profiles here).
- **`forceLoginOrgUUID`**: if your Team org enforces this via *machine-wide* managed settings, Claude Code refuses to start with a personal credential. Applied per config folder it's fine.
- **`ANTHROPIC_API_KEY`** is pay-as-you-go API billing via the Console, not a way to switch between subscription accounts — leave it unset for this setup.
- **Usage limits are per account**, so switching does give you a fresh allowance; it does not merge the two.

---

## 10. Undo

For any extra profile:

```bash
./setup.sh --remove team     # removes the alias, then asks before deleting ~/.claude-team
```

Or by hand:

```bash
rm -rf ~/.claude-team    # removes the Team login and the symlinks; ~/.claude is untouched
```

Then delete the `alias claude-team=...` line (and the comment above it) from your shell rc file.

---

## 11. References

- [Claude Code — Authentication](https://code.claude.com/docs/en/authentication): `CLAUDE_CONFIG_DIR`, where credentials are stored, `/login` and `/logout`
- [Claude Code — Sessions](https://code.claude.com/docs/en/sessions): `--continue`, `--resume`, `--fork-session`, transcript location
- [Claude Code — The `~/.claude` directory](https://code.claude.com/docs/en/claude-directory): what each file and folder holds
