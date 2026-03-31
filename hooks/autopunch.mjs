#!/usr/bin/env node

/**
 * Auto-Punch Hook — Retroactive idle detection
 *
 * Runs on PreToolUse. Detects idle gaps between tool calls
 * and automatically inserts AWAY/BACK entries in the punch CSV.
 *
 * Config: ~/.claude/timelog/autopunch.json
 * Log:    ~/.claude/timelog/punches.csv
 * State:  ~/.claude/timelog/last_activity
 */

import { readFileSync, writeFileSync, appendFileSync, existsSync } from 'fs';
import { execSync } from 'child_process';
import { join } from 'path';

const HOME = process.env.HOME || process.env.USERPROFILE;
const TIMELOG_DIR = join(HOME, '.claude', 'timelog');
const CONFIG_PATH = join(TIMELOG_DIR, 'autopunch.json');
const CSV_PATH = join(TIMELOG_DIR, 'punches.csv');
const ACTIVITY_PATH = join(TIMELOG_DIR, 'last_activity');
const LOCATIONS_PATH = join(TIMELOG_DIR, 'locations.json');

function loadLocationMap() {
  try {
    return JSON.parse(readFileSync(LOCATIONS_PATH, 'utf8'));
  } catch {
    return {};
  }
}

function getLocation() {
  const locationMap = loadLocationMap();
  try {
    const hostname = execSync('hostname', { encoding: 'utf8' }).trim();
    for (const [key, name] of Object.entries(locationMap)) {
      if (hostname.includes(key)) return name;
    }
    return hostname;
  } catch {
    return 'Unknown';
  }
}

function formatTime(date) {
  const pad = (n) => String(n).padStart(2, '0');
  return `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
}

function formatDate(date) {
  const pad = (n) => String(n).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

function formatCsvLine(date, type, location, note = '') {
  return `${formatDate(date)},${type},${formatTime(date)},${location},${note}`;
}

function getLastPunchEntry() {
  if (!existsSync(CSV_PATH)) return null;
  const lines = readFileSync(CSV_PATH, 'utf8').trim().split('\n');
  const dataLines = lines.filter((l) => !l.startsWith('date,'));
  if (dataLines.length === 0) return null;
  const last = dataLines[dataLines.length - 1];
  const [date, type, time] = last.split(',');
  return { date, type, time, raw: last };
}

function getLastActivity() {
  if (!existsSync(ACTIVITY_PATH)) return null;
  const ts = readFileSync(ACTIVITY_PATH, 'utf8').trim();
  const parsed = new Date(ts);
  return isNaN(parsed.getTime()) ? null : parsed;
}

function saveLastActivity(date) {
  writeFileSync(ACTIVITY_PATH, date.toISOString());
}

function appendPunch(line) {
  appendFileSync(CSV_PATH, line + '\n');
}

function minutesBetween(a, b) {
  return (b.getTime() - a.getTime()) / 60000;
}

function main() {
  let stdin = '';
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', (chunk) => { stdin += chunk; });
  process.stdin.on('end', () => {
    // Pass through stdin (required by hook protocol)
    process.stdout.write(stdin);

    // Load config
    let config;
    try {
      config = JSON.parse(readFileSync(CONFIG_PATH, 'utf8'));
    } catch {
      return;
    }

    if (!config.enabled) return;

    const lastEntry = getLastPunchEntry();
    if (!lastEntry) return;

    const { type: lastType } = lastEntry;

    // Only act when punched in (IN or BACK) or AWAY
    if (lastType === 'OUT') return;

    const now = new Date();
    const location = getLocation();
    const lastActivity = getLastActivity();

    if ((lastType === 'IN' || lastType === 'BACK') && config.autoAwayOnIdle && lastActivity) {
      const idleMinutes = minutesBetween(lastActivity, now);

      if (idleMinutes >= config.idleMinutes) {
        // Retroactive AWAY at (lastActivity + idleMinutes threshold)
        const awayTime = new Date(lastActivity.getTime() + config.idleMinutes * 60000);
        const awayLine = formatCsvLine(awayTime, 'AWAY', location, 'auto-idle');
        appendPunch(awayLine);

        // Immediate BACK at now
        const backLine = formatCsvLine(now, 'BACK', location, 'auto-back');
        appendPunch(backLine);

        const idleMins = Math.round(idleMinutes);
        process.stderr.write(
          `\u23F8\uFE0F Auto-away (${idleMins}m idle) \u2192 \uD83D\uDFE2 Auto-back!\n`
        );
      }
    } else if (lastType === 'AWAY' && config.autoBackOnPrompt) {
      // Currently AWAY → auto BACK
      const backLine = formatCsvLine(now, 'BACK', location, 'auto-back');
      appendPunch(backLine);

      const [, , awayTimeStr] = lastEntry.raw.split(',');
      const [awayDate] = lastEntry.raw.split(',');
      const awayDateTime = new Date(`${awayDate}T${awayTimeStr}`);
      const breakMins = Math.round(minutesBetween(awayDateTime, now));
      process.stderr.write(`\uD83D\uDFE2 Auto-back! Break was ${breakMins}m\n`);
    }

    // Always update last activity
    saveLastActivity(now);
  });
}

main();
