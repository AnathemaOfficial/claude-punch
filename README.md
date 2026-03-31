# Claude Punch

A time tracking skill for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) with **automatic idle detection**.

Never forget to clock out again. Claude Punch tracks your work sessions with simple `/punch` commands and automatically detects when you step away.

## Features

- `/punch in` / `/punch out` — Start and end work sessions
- `/punch away` / `/punch back` — Manual break tracking
- `/punch status` — Current session info
- `/punch report` — Weekly time report with breakdowns
- **Auto-punch** — Automatically detects idle time (>5 min between prompts) and logs AWAY/BACK retroactively
- **Auto-location** — Detects which machine you're on via hostname
- **Simple CSV storage** — Human-readable, easy to export

## How Auto-Punch Works

Instead of running timers or crons, Claude Punch uses **retroactive idle detection**:

```
10:00 → you prompt → timestamp recorded
10:02 → you prompt → 2 min gap, still active
10:30 → you come back → 28 min gap detected!
  → Auto-AWAY logged at 10:07 (last activity + 5 min threshold)
  → Auto-BACK logged at 10:30 (now)
```

No background processes. No polling. Just a `PreToolUse` hook that checks the gap between tool calls.

## Install

### Linux / macOS

```bash
git clone https://github.com/AnathemaOfficial/claude-punch.git
cd claude-punch
chmod +x install.sh
./install.sh
```

### Windows (PowerShell)

```powershell
git clone https://github.com/AnathemaOfficial/claude-punch.git
cd claude-punch
.\install.ps1
```

### Manual Install

1. Copy `skills/punch/SKILL.md` to `~/.claude/skills/punch/SKILL.md`
2. Copy `hooks/autopunch.mjs` to `~/.claude/hooks/autopunch.mjs`
3. Create `~/.claude/timelog/autopunch.json`:
   ```json
   {
     "enabled": true,
     "idleMinutes": 5,
     "autoBackOnPrompt": true,
     "autoAwayOnIdle": true
   }
   ```
4. Add the hook to `~/.claude/settings.json`:
   ```json
   {
     "hooks": {
       "PreToolUse": [
         {
           "matcher": "*",
           "hooks": [
             {
               "type": "command",
               "command": "node /path/to/.claude/hooks/autopunch.mjs",
               "timeout": 5
             }
           ]
         }
       ]
     }
   }
   ```
5. Restart Claude Code

## Usage

```
/punch in           Start your work day
/punch out          End your work day
/punch away lunch   Manual break with note
/punch back         Return from break
/punch status       Where am I?
/punch report       Weekly summary
/punch              Auto-toggle (in→out, out→in, away→back)
```

## Configuration

### Auto-Punch: `~/.claude/timelog/autopunch.json`

| Setting | Default | Description |
|---------|---------|-------------|
| `enabled` | `true` | Enable/disable auto-punch |
| `idleMinutes` | `5` | Minutes of inactivity before auto-AWAY |
| `autoBackOnPrompt` | `true` | Auto-BACK when you return |
| `autoAwayOnIdle` | `true` | Auto-AWAY on idle detection |

### Locations: `~/.claude/timelog/locations.json`

Map hostnames to friendly names:

```json
{
  "DESKTOP-ABC": "Home Office",
  "WORK-PC": "Work Station",
  "MACBOOK": "Laptop"
}
```

Matching uses `hostname.includes(key)`, so partial matches work.

## Data Format

All data is stored in `~/.claude/timelog/punches.csv`:

```csv
date,type,time,location,note
2026-03-31,IN,07:46:41,Home Office,
2026-03-31,AWAY,07:52:18,Home Office,auto-idle
2026-03-31,BACK,08:25:02,Home Office,auto-back
2026-03-31,OUT,17:30:00,Home Office,done for the day
```

Easy to import into spreadsheets, time tracking tools, or process with scripts.

## How It Works

### Session Logic

- A **session** starts with IN and ends with OUT
- AWAY/BACK pairs are breaks within a session
- **Total time** = OUT - IN
- **Active time** = Total time - all AWAY periods
- Auto-punch entries are marked with `auto-idle` / `auto-back` notes

### Hook Architecture

The auto-punch hook runs as a `PreToolUse` hook in Claude Code's `settings.json`. On every tool call:

1. Reads the last punch entry from the CSV
2. Checks the gap since `last_activity`
3. If gap > `idleMinutes` and status is IN/BACK → inserts retroactive AWAY + BACK
4. If status is AWAY → inserts BACK
5. Updates `last_activity` timestamp

The hook is async and non-blocking (5s timeout), so it won't slow down your workflow.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (any version with hooks support)
- Node.js 18+

## License

MIT
