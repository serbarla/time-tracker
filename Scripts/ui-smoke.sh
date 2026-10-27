#!/usr/bin/env bash
# Automated UI smoke for the bundled TimeTracker.app, driven via AppleScript UI
# scripting. Launches the bundle against a temp fixture store (redirected through
# TIMETRACKER_CHECKS_FILE), then asserts: menubar title, panel tabs, editor row,
# quit, and that neither the fixture nor the real store was mutated.
#
# Prerequisite: the terminal app must be enabled under
# System Settings > Privacy & Security > Accessibility.
#
# SMOKE FAIL assertion names: app-launch, menubar-title, panel-open, tabs-present,
# status-row, edit-row, quit, fixture-unchanged, real-store-unchanged.
#
# AX selectors (confirmed via System Events tree dumps on macOS 27) live in the
# ax.applescript helper below; its header documents the version-dependent shapes.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
APP="$ROOT/dist/TimeTracker.app"
BIN="$APP/Contents/MacOS/TimeTracker"
REAL_STORE="$HOME/Library/Application Support/TimeTracker/checks.json"

command -v osascript >/dev/null 2>&1 && command -v shasum >/dev/null 2>&1 || {
  echo "ui-smoke: requires macOS (osascript and shasum not found)" >&2
  exit 1
}

if [[ ! -x "$BIN" ]]; then
  bash "$ROOT/Scripts/package-app.sh"
fi

if [[ "$(osascript -e 'tell application "System Events" to UI elements enabled' 2>/dev/null || echo false)" != "true" ]]; then
  echo "Enable your terminal in System Settings > Privacy & Security > Accessibility and re-run" >&2
  exit 1
fi

# Strays register duplicate hotkeys/status items (AGENTS.md).
pkill -x TimeTracker 2>/dev/null || true

WORKDIR=""
APP_PID=""
# The smoke asserts English AX labels ("Status"/"Edit"/"Add preset"), so the
# run pins uiLocale=en and restores whatever the user had chosen.
UI_LOCALE_DOMAIN="com.sergiobarba.timetracker"
UI_LOCALE_PINNED=0
UI_LOCALE_SAVED=""
cleanup() {
  if [[ -n "$APP_PID" ]] && kill -0 "$APP_PID" 2>/dev/null; then
    kill "$APP_PID" 2>/dev/null || true
    wait "$APP_PID" 2>/dev/null || true
  fi
  if [[ "$UI_LOCALE_PINNED" == "1" ]]; then
    if [[ -n "$UI_LOCALE_SAVED" ]]; then
      defaults write "$UI_LOCALE_DOMAIN" uiLocale -string "$UI_LOCALE_SAVED"
    else
      defaults delete "$UI_LOCALE_DOMAIN" uiLocale 2>/dev/null || true
    fi
  fi
  if [[ -n "$WORKDIR" ]]; then rm -rf "$WORKDIR"; fi
  return 0
}
trap cleanup EXIT

UI_LOCALE_SAVED="$(defaults read "$UI_LOCALE_DOMAIN" uiLocale 2>/dev/null || true)"
defaults write "$UI_LOCALE_DOMAIN" uiLocale -string "en"
UI_LOCALE_PINNED=1

dump_tree() {
  echo "--- AX tree (popover; one element per line) ---"
  osascript -e 'tell application "System Events" to return entire contents of pop over 1 of menu bar item 1 of menu bar 2 of process "TimeTracker"' 2>/dev/null | tr ',' '\n' \
    || osascript -e 'tell application "System Events" to return entire contents of pop over 1 of menu bar 2 of process "TimeTracker"' 2>/dev/null | tr ',' '\n' \
    || osascript -e 'tell application "System Events" to return entire contents of menu bar 2 of process "TimeTracker"' 2>/dev/null | tr ',' '\n' \
    || true
}

fail() {
  echo "SMOKE FAIL: $1" >&2
  dump_tree
  exit 1
}

# wait_until SECONDS CMD [ARGS...] -- until CMD exits 0.
wait_until() {
  local timeout="$1" deadline
  shift
  deadline=$((SECONDS + timeout))
  while (( SECONDS < deadline )); do
    if "$@"; then return 0; fi
    sleep 0.3
  done
  return 1
}

ax() {
  osascript "$WORKDIR/ax.applescript" "$@" 2>/dev/null || true
}

proc_alive()     { [[ "$(osascript -e 'tell application "System Events" to return exists process "TimeTracker"' 2>/dev/null || true)" == "true" ]]; }
proc_gone()      { [[ "$(osascript -e 'tell application "System Events" to return not (exists process "TimeTracker")' 2>/dev/null || true)" == "true" ]]; }
popover_open()   { [[ "$(ax pop-exists)" == "true" ]]; }
title_active()   { [[ "$(osascript -e 'tell application "System Events" to tell process "TimeTracker" to return (name of menu bar item 1 of menu bar 2) contains "SMOKE"' 2>/dev/null || true)" == "true" ]]; }
edit_row_present() { [[ "$(ax edit-shape)" == "true" ]]; }

# --- Fixture: one check named SMOKE, active at any run time --------------------
# Two ranges per day tile the full day exactly: 00:00-00:01 plus the overnight
# 00:01-00:00, which the engine builds as [00:01, next 00:00). A lone
# 00:01-00:00 would leave [00:00, 00:01) uncovered (yesterday's spillover ends
# exactly at 00:00, half-open). UTC zone keeps the schedule deterministic.
WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/tt-smoke.XXXXXX")"
cat > "$WORKDIR/checks.json" <<'FIXTURE'
{
  "version": 2,
  "checks": [
    {
      "id": "00000000-0000-0000-0000-000000000001",
      "name": "SMOKE",
      "timeZoneIdentifier": "UTC",
      "schedule": {
        "mon": [{"start": "00:00", "end": "00:01"}, {"start": "00:01", "end": "00:00"}],
        "tue": [{"start": "00:00", "end": "00:01"}, {"start": "00:01", "end": "00:00"}],
        "wed": [{"start": "00:00", "end": "00:01"}, {"start": "00:01", "end": "00:00"}],
        "thu": [{"start": "00:00", "end": "00:01"}, {"start": "00:01", "end": "00:00"}],
        "fri": [{"start": "00:00", "end": "00:01"}, {"start": "00:01", "end": "00:00"}],
        "sat": [{"start": "00:00", "end": "00:01"}, {"start": "00:01", "end": "00:00"}],
        "sun": [{"start": "00:00", "end": "00:01"}, {"start": "00:01", "end": "00:00"}]
      },
      "notifyOnFlip": false
    }
  ]
}
FIXTURE
cp "$WORKDIR/checks.json" "$WORKDIR/checks.orig"

if [[ -f "$REAL_STORE" ]]; then
  REAL_SUM="$(shasum "$REAL_STORE" | cut -d' ' -f1)"
else
  REAL_SUM="absent"
fi

# --- AppleScript helper -------------------------------------------------------
cat > "$WORKDIR/ax.applescript" <<'EOF'
-- UI smoke AX helper for TimeTracker.app (driven by Scripts/ui-smoke.sh).
-- Usage: osascript ax.applescript <mode> [label]
-- Modes: pop-exists, tabs, exists <label>, click <label>, edit-shape, quit-click.
--
-- macOS-version-dependent shapes (tree-dump confirmed on macOS 27):
-- * The popover is "pop over 1 of menu bar item 1 of menu bar 2"; earlier macOS
--   reports it at "pop over 1 of menu bar 2". Both are tried everywhere.
-- * Segmented Picker tabs are "radio button 1/2 of radio group 1 of group 1";
--   their labels ("Status"/"Edit") live in "description", NOT "name".
-- * "Add Time Zone" and "Quit TimeTracker" expose no label at all; they are matched
--   structurally as the first/last of the two "button"s of "group 1".

on popOf()
  tell application "System Events"
    tell process "TimeTracker"
      try
        return pop over 1 of menu bar item 1 of menu bar 2
      end try
      try
        return pop over 1 of menu bar 2
      end try
    end tell
  end tell
  error "popover not found"
end popOf

on labelMatch(el, wanted)
  try
    if (name of el) is wanted then return true
  end try
  try
    if (description of el) is wanted then return true
  end try
  return false
end labelMatch

on clickMatch(popRef, wanted)
  tell application "System Events"
    tell process "TimeTracker"
      set els to entire contents of popRef
      set fallback to missing value
      repeat with el in els
        if my labelMatch(el, wanted) then
          set clicked to false
          try
            set r to role of el
            if r is "AXRadioButton" or r is "AXButton" or r is "AXMenuButton" or r is "AXPopUpButton" then
              click el
              set clicked to true
            end if
          end try
          if clicked then return true
          if fallback is missing value then set fallback to el
        end if
      end repeat
      if fallback is not missing value then
        click fallback
        return true
      end if
      -- Tab labels sit in radio-button description; fall back to Picker order.
      set tabIdx to 0
      if wanted is "Status" then set tabIdx to 1
      if wanted is "Edit" then set tabIdx to 2
      if tabIdx > 0 then
        try
          click radio button tabIdx of radio group 1 of group 1 of popRef
          return true
        end try
      end if
      return false
    end tell
  end tell
end clickMatch

on run argv
  set mode to item 1 of argv
  set wanted to ""
  if (count of argv) > 1 then set wanted to item 2 of argv

  if mode is "pop-exists" then
    tell application "System Events"
      tell process "TimeTracker"
        try
          if exists pop over 1 of menu bar item 1 of menu bar 2 then return "true"
        end try
        try
          if exists pop over 1 of menu bar 2 then return "true"
        end try
        return "false"
      end tell
    end tell
  end if

  set popRef to my popOf()

  if mode is "tabs" then
    tell application "System Events"
      tell process "TimeTracker"
        -- Literal specifiers only: "description" is not readable through a
        -- generic handler parameter (probe-confirmed), and the labels live there.
        set ok1 to false
        set ok2 to false
        try
          if (description of radio button 1 of radio group 1 of group 1 of popRef) is "Status" then set ok1 to true
        end try
        try
          if (name of radio button 1 of radio group 1 of group 1 of popRef) is "Status" then set ok1 to true
        end try
        try
          if (description of radio button 2 of radio group 1 of group 1 of popRef) is "Edit" then set ok2 to true
        end try
        try
          if (name of radio button 2 of radio group 1 of group 1 of popRef) is "Edit" then set ok2 to true
        end try
        if ok1 and ok2 then return "true"
        return "false"
      end tell
    end tell
  end if

  if mode is "exists" then
    tell application "System Events"
      tell process "TimeTracker"
        set els to entire contents of popRef
        repeat with el in els
          if my labelMatch(el, wanted) then return "true"
        end repeat
        return "false"
      end tell
    end tell
  end if

  if mode is "click" then
    if my clickMatch(popRef, wanted) then return "true"
    return "false"
  end if

  if mode is "edit-shape" then
    tell application "System Events"
      tell process "TimeTracker"
        -- Edit list shows the fixture check: row text is not exposed in List
        -- rows on macOS 27, so accept the row's presence (or a named text).
        set rowOk to false
        try
          if (count of rows of outline 1 of scroll area 1 of group 1 of popRef) > 0 then set rowOk to true
        end try
        if not rowOk then
          set els to entire contents of popRef
          repeat with el in els
            if my labelMatch(el, "SMOKE") then
              set rowOk to true
              exit repeat
            end if
          end repeat
        end if
        if not rowOk then return "false"
        -- "Add preset" is a named menu button; "Add Time Zone" is unnamed and is
        -- the first of the two group-1 buttons (Add Time Zone, Quit).
        try
          if (name of menu button 1 of group 1 of popRef) = "Add preset" then
            if (count of buttons of group 1 of popRef) = 2 then return "true"
          end if
        end try
        return "false"
      end tell
    end tell
  end if

  if mode is "quit-click" then
    if my clickMatch(popRef, "Quit TimeTracker") then return "true"
    -- Unnamed on macOS 27: quit is the last button of group 1 in every tab.
    tell application "System Events"
      tell process "TimeTracker"
        try
          click button (count of buttons of group 1 of popRef) of group 1 of popRef
          return "true"
        end try
        return "false"
      end tell
    end tell
  end if

  return "false"
end run
EOF

# --- Launch (direct binary keeps the bundle id; `open` cannot pass env) --------
TIMETRACKER_CHECKS_FILE="$WORKDIR/checks.json" "$BIN" &
APP_PID=$!

wait_until 10 proc_alive    || fail "app-launch"
wait_until 10 title_active  || fail "menubar-title"

# Open the panel: click the status item; fallback to the registered hotkey.
osascript -e 'tell application "System Events" to tell process "TimeTracker" to click menu bar item 1 of menu bar 2' >/dev/null 2>&1 || true
if ! wait_until 5 popover_open; then
  osascript -e 'tell application "System Events" to key code 17 using {control down, option down}' >/dev/null 2>&1 || true
  wait_until 5 popover_open || fail "panel-open"
fi

# --- Assertions inside the popover --------------------------------------------
[[ "$(ax tabs)" == "true" ]]           || fail "tabs-present"
[[ "$(ax exists SMOKE)" == "true" ]]   || fail "status-row"

[[ "$(ax click Edit)" == "true" ]] || fail "edit-row"
wait_until 5 edit_row_present    || fail "edit-row"

[[ "$(ax quit-click)" == "true" ]] || fail "quit"
wait_until 5 proc_gone           || fail "quit"

# --- Post-conditions: the smoke never mutates anything ------------------------
cmp -s "$WORKDIR/checks.json" "$WORKDIR/checks.orig" || fail "fixture-unchanged"

if [[ -f "$REAL_STORE" ]]; then
  NOW_SUM="$(shasum "$REAL_STORE" | cut -d' ' -f1)"
else
  NOW_SUM="absent"
fi
[[ "$NOW_SUM" == "$REAL_SUM" ]] || fail "real-store-unchanged"

echo "UI SMOKE PASS"
