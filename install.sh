#!/usr/bin/env bash
set -euo pipefail

# Claude Punch — Installer
# Installs the punch skill and auto-punch hook for Claude Code

CLAUDE_DIR="${HOME}/.claude"
TIMELOG_DIR="${CLAUDE_DIR}/timelog"
SKILL_DIR="${CLAUDE_DIR}/skills/punch"
HOOKS_DIR="${CLAUDE_DIR}/hooks"
SETTINGS="${CLAUDE_DIR}/settings.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing Claude Punch..."

# Create directories
mkdir -p "${SKILL_DIR}" "${TIMELOG_DIR}" "${HOOKS_DIR}"

# Copy skill
cp "${SCRIPT_DIR}/skills/punch/SKILL.md" "${SKILL_DIR}/SKILL.md"
echo "  Skill installed to ${SKILL_DIR}/"

# Copy hook
cp "${SCRIPT_DIR}/hooks/autopunch.mjs" "${HOOKS_DIR}/autopunch.mjs"
echo "  Hook installed to ${HOOKS_DIR}/"

# Create default config if not exists
if [ ! -f "${TIMELOG_DIR}/autopunch.json" ]; then
  cat > "${TIMELOG_DIR}/autopunch.json" <<'EOF'
{
  "enabled": true,
  "idleMinutes": 5,
  "autoBackOnPrompt": true,
  "autoAwayOnIdle": true
}
EOF
  echo "  Config created at ${TIMELOG_DIR}/autopunch.json"
else
  echo "  Config already exists, skipping"
fi

# Create example locations if not exists
if [ ! -f "${TIMELOG_DIR}/locations.json" ]; then
  HOSTNAME_VAL=$(hostname)
  cat > "${TIMELOG_DIR}/locations.json" <<EOF
{
  "${HOSTNAME_VAL}": "My Workstation"
}
EOF
  echo "  Locations created at ${TIMELOG_DIR}/locations.json (edit to customize)"
else
  echo "  Locations already exists, skipping"
fi

# Add hook to settings.json
if [ -f "${SETTINGS}" ]; then
  if grep -q "autopunch" "${SETTINGS}" 2>/dev/null; then
    echo "  Hook already registered in settings.json, skipping"
  else
    HOOK_PATH="${HOOKS_DIR}/autopunch.mjs"
    # Use node to safely merge into settings.json
    node -e "
      const fs = require('fs');
      const settings = JSON.parse(fs.readFileSync('${SETTINGS}', 'utf8'));
      if (!settings.hooks) settings.hooks = {};
      if (!settings.hooks.PreToolUse) settings.hooks.PreToolUse = [];
      settings.hooks.PreToolUse.unshift({
        matcher: '*',
        hooks: [{ type: 'command', command: 'node \"${HOOK_PATH}\"', timeout: 5 }]
      });
      fs.writeFileSync('${SETTINGS}', JSON.stringify(settings, null, 2));
    "
    echo "  Hook registered in settings.json"
  fi
else
  echo "  WARNING: ${SETTINGS} not found. Create it or add the hook manually."
fi

echo ""
echo "Done! Restart Claude Code to activate."
echo ""
echo "Usage:"
echo "  /punch in        Start your work session"
echo "  /punch out       End your work session"
echo "  /punch status    Check current status"
echo "  /punch report    Weekly report"
echo ""
echo "Auto-punch will detect idle time (>${IDLE_MIN:-5}min) and log AWAY/BACK automatically."
echo "Edit ${TIMELOG_DIR}/locations.json to customize location names."
