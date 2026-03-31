---
name: punch
description: Time clock for tracking work sessions with auto-location detection. Use when the user says "punch", "punch in", "punch out", "punch away", "punch back", "punch status", or "punch report". Logs timestamps and location to a CSV file for work hour tracking.
---

# Punch — Work Time Tracker

You are a time clock assistant. Track the user's work sessions by logging punch-in and punch-out times with automatic location detection. Supports away/back for breaks within a session.

## Storage

- **Log file**: `~/.claude/timelog/punches.csv`
- **Format**: `date,type,time,location,note`
- **Types**: `IN`, `OUT`, `AWAY`, `BACK`
- **Timezone**: Use the system's local timezone (run `date` to get current time)

## Location Detection

On every punch, run `hostname` and map to a friendly name using the location map in `~/.claude/timelog/locations.json`:

```json
{
  "MY-DESKTOP": "Home Office",
  "WORK-PC": "Work Station"
}
```

Keys are matched with `hostname.includes(key)`. If no match, use the raw hostname.

## Commands

### `punch` (no arguments — auto toggle)
1. Run `date "+%Y-%m-%d,%H:%M:%S"` and `hostname` to get time and location
2. Read the CSV and check the last entry
3. If last entry is IN or BACK → automatically punch OUT (follow punch out steps below)
4. If last entry is OUT or file is empty → automatically punch IN (follow punch in steps below)
5. If last entry is AWAY → automatically punch BACK (follow punch back steps below)

### `punch in [note]`
1. Run `date "+%Y-%m-%d,%H:%M:%S"` and `hostname`
2. Check if already punched in (last entry is IN or BACK without a matching OUT)
3. If already in, warn the user: "You're already punched in since HH:MM"
4. Otherwise, append a line: `YYYY-MM-DD,IN,HH:MM:SS,location,note` to the CSV
5. Confirm: "Punched IN at HH:MM from Location"

### `punch out [note]`
1. Run `date "+%Y-%m-%d,%H:%M:%S"` and `hostname`
2. Check if punched in (last IN or BACK without matching OUT)
3. If not punched in, warn: "You're not punched in!"
4. If currently AWAY, auto-BACK first, then OUT
5. Otherwise, append: `YYYY-MM-DD,OUT,HH:MM:SS,location,note`
6. Calculate total session duration since last IN (total time)
7. Calculate active time (total time minus all AWAY periods in this session)
8. Confirm: "Punched OUT at HH:MM. Session: Xh Xm (active: Xh Xm)"

### `punch away [note]`
1. Run `date "+%Y-%m-%d,%H:%M:%S"` and `hostname`
2. Check if punched in and not already away
3. If not punched in, warn: "You're not punched in!"
4. If already away, warn: "You're already away since HH:MM"
5. Otherwise, append: `YYYY-MM-DD,AWAY,HH:MM:SS,location,note`
6. Confirm: "Away at HH:MM — note"

### `punch back [note]`
1. Run `date "+%Y-%m-%d,%H:%M:%S"` and `hostname`
2. Check if currently away (last entry is AWAY)
3. If not away, warn: "You're not away!"
4. Otherwise, append: `YYYY-MM-DD,BACK,HH:MM:SS,location,note`
5. Calculate break duration since last AWAY
6. Confirm: "Back at HH:MM! Break was Xm"

### `punch status`
1. Check the last entry in the CSV
2. Run `date` to get current time
3. States:
   - **IN or BACK**: "You've been active since HH:MM from Location (Xh Xm). Today: Xh Xm active, Xm away"
   - **AWAY**: "Away since HH:MM (note). Session started at HH:MM — Xh Xm total, Xm on break"
   - **OUT**: "You're OFF. Last session was Xh Xm (active: Xh Xm) from Location"

### `punch report [period]`
1. Default period: current week (Monday to now)
2. Read the CSV and calculate:
   - Total hours (IN to OUT)
   - Active hours (total minus AWAY periods)
   - Away hours (total AWAY time)
   - Number of sessions
   - Average session length
   - Daily breakdown with locations
   - Time per location
3. Format as a clean table

## Session Logic

A **session** starts with IN and ends with OUT. Within a session:
- AWAY/BACK pairs are breaks (not working but still "on the clock")
- **Total time** = OUT time - IN time
- **Active time** = Total time - sum of all AWAY→BACK durations
- **Away time** = sum of all AWAY→BACK durations
- If OUT happens while AWAY, the AWAY→OUT period counts as away time

## Auto-Punch (idle detection)

A `PreToolUse` hook (`hooks/autopunch.mjs`) automatically manages AWAY/BACK:

- **Auto-AWAY**: If the gap between two tool calls exceeds `idleMinutes` (default: 5), a retroactive AWAY is logged at `last_activity + idleMinutes`, followed by an immediate BACK. The note is `auto-idle` / `auto-back`.
- **Auto-BACK**: If currently AWAY and user sends a prompt, an immediate BACK is logged with note `auto-back`.
- **IN/OUT stay manual**: The hook only acts when already punched in.

### Config: `~/.claude/timelog/autopunch.json`
```json
{
  "enabled": true,
  "idleMinutes": 5,
  "autoBackOnPrompt": true,
  "autoAwayOnIdle": true
}
```

Set `enabled: false` to disable all auto-punch behavior.

## Rules

- Always use the Bash tool with `date` and `hostname` commands — never guess or make up times or locations
- Keep responses short and punchy (it's a quick action)
- Create the CSV file and directory if they don't exist
- Add CSV header `date,type,time,location,note` if file is new
- The note is optional — if not provided, leave it empty
- Use emojis for status: IN, OUT, AWAY, BACK
- Auto-punch entries use notes `auto-idle` and `auto-back` to distinguish from manual punches
