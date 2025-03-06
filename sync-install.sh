#!/usr/bin/env bash
#
# sync-install.sh
# ---------------
# Installs sync-holes.sh from https://github.com/TheMegamind/sync-holes
# with optional advanced features, simulation mode, Pi-hole version checks,
# color-coded prompts, cron duplication logic, and a single symlink block.
#
# Usage:
#   ./sync-install.sh [options]
#
# Options:
#   -s, --simulate     Perform a dry-run (simulate) without making changes
#   -a, --advanced     Enable advanced install mode (change dirs, symlink, etc.)
#   -h, --help         Show this help message
#
# Example:
#   ./sync-install.sh
#   ./sync-install.sh --simulate
#   ./sync-install.sh --advanced
#   ./sync-install.sh -s -a
#
# -----------------------------------------------------------------------------
set -e

###############################################################################
# Color Variables
###############################################################################
YELLOW="\033[1;33m"
GREEN="\033[1;32m"
RED="\033[1;31m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
NC="\033[0m"

###############################################################################
# Default Variables
###############################################################################
REPO_URL="https://github.com/TheMegamind/sync-holes.git"
CLONE_DIR="sync-holes"  # Local clone directory name

# Basic (non-advanced) defaults
INSTALL_DIR="/usr/local/bin"
ENV_DIR="/usr/local/etc"
SIMULATE=0
ADVANCED=0

CRON_DEFAULT_SCHEDULE="0 3 * * *"  # e.g., run daily at 3:00 AM

###############################################################################
# Helper: Print usage
###############################################################################
usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  -s, --simulate     Perform a dry-run (simulate) without making changes
  -a, --advanced     Enable advanced install mode (change dirs, symlink, etc.)
  -h, --help         Show this help message

Examples:
  $(basename "$0")
  $(basename "$0") --simulate
  $(basename "$0") --advanced
  $(basename "$0") -s -a
EOF
  exit 1
}

###############################################################################
# Parse Command-Line Arguments
###############################################################################
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--simulate)
      SIMULATE=1
      shift
      ;;
    -a|--advanced)
      ADVANCED=1
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo -e "[${RED}ERROR${NC}] Unknown option: $1"
      usage
      ;;
  esac
done

###############################################################################
# run_cmd: Wrapper to run commands or simulate
###############################################################################
run_cmd() {
  if [[ $SIMULATE -eq 1 ]]; then
    echo -e "[${YELLOW}SIMULATE${NC}] $*"
  else
    eval "$@"
  fi
}

###############################################################################
# Logging/Prompt Functions
###############################################################################
info() {
  echo -e "[${GREEN}INFO${NC}] $*"
}

warn() {
  echo -e "[${YELLOW}WARN${NC}] $*"
}

prompt() {
  # Print a prompt in cyan
  echo -en "${CYAN}$*${NC}"
}

###############################################################################
# 1. Check for Dependencies
###############################################################################
info "Checking for necessary packages: git, curl, jq..."
run_cmd "sudo apt-get update -y"
run_cmd "sudo apt-get install -y git curl jq"

# Quick check for Bash 4+
BASH_VERSION_MAJOR="${BASH_VERSINFO:-0}"
if (( BASH_VERSION_MAJOR < 4 )); then
  warn "You appear to be running an older Bash (<4). Arrays may not work."
fi

###############################################################################
# 2. Check Pi-hole Version
###############################################################################
info "Checking Pi-hole version..."

if command -v pihole >/dev/null 2>&1; then
  PIHOLE_VERSION_OUTPUT=$(pihole -v 2>/dev/null || true)
  info "Pi-hole version info:"
  echo "$PIHOLE_VERSION_OUTPUT"

  # Check if "v6" is found in the output
  if grep -q "v6" <<< "$PIHOLE_VERSION_OUTPUT"; then
    info "Pi-hole v6 found!"
  else
    warn "Pi-hole v6 not detected. This script is intended for Pi-hole 6+."
    prompt "Continue anyway? (y/N): "
    read -r ver_choice
    if [[ ! "$ver_choice" =~ ^[Yy]$ ]]; then
      echo -e "[${RED}ERROR${NC}] Exiting..."
      exit 1
    fi
  fi
else
  warn "'pihole' command not found. Are you sure Pi-hole is installed?"
  prompt "Continue anyway? (y/N): "
  read -r ver_choice
  if [[ ! "$ver_choice" =~ ^[Yy]$ ]]; then
    echo -e "[${RED}ERROR${NC}] Exiting..."
    exit 1
  fi
fi

###############################################################################
# 3. Clone or Update the Repository
###############################################################################
if [[ -d "$CLONE_DIR" ]]; then
  info "Directory '$CLONE_DIR' already exists. Pulling latest changes..."
  run_cmd "cd \"$CLONE_DIR\" && git pull && cd .."
else
  info "Cloning repository from $REPO_URL into '$CLONE_DIR'..."
  run_cmd "git clone \"$REPO_URL\" \"$CLONE_DIR\""
fi

###############################################################################
# 4. Basic vs Advanced Install
###############################################################################
if [[ $ADVANCED -eq 1 ]]; then
  info "Entering ADVANCED install mode..."

  prompt "Script install directory? Press Enter to keep default: [$INSTALL_DIR] "
  read -r choice
  if [[ -n "$choice" ]]; then
    INSTALL_DIR="$choice"
  fi

  prompt "Environment (.env) directory? Press Enter to keep default: [$ENV_DIR] "
  read -r choice
  if [[ -n "$choice" ]]; then
    ENV_DIR="$choice"
  fi
else
  info "BASIC install mode: using default directories ($INSTALL_DIR, $ENV_DIR)."
fi

###############################################################################
# 5. Create Directories & Copy Script
###############################################################################
info "Creating target directories if needed..."
run_cmd "sudo mkdir -p \"$INSTALL_DIR\""
run_cmd "sudo mkdir -p \"$ENV_DIR\""

info "Copying sync-holes.sh → $INSTALL_DIR/sync-holes.sh"
run_cmd "sudo cp \"$CLONE_DIR/sync-holes.sh\" \"$INSTALL_DIR/sync-holes.sh\""
run_cmd "sudo chmod +x \"$INSTALL_DIR/sync-holes.sh\""

###############################################################################
# 6. Back Up Existing sync-holes.env if Present, Then Copy
###############################################################################
ENV_PATH="$ENV_DIR/sync-holes.env"

if [[ -f "$ENV_PATH" ]]; then
  BACKUP_PATH="$ENV_PATH.$(date +%Y%m%d%H%M%S).bak"
  warn "Found existing sync-holes.env at $ENV_PATH"
  warn "Backing it up to $BACKUP_PATH"
  run_cmd "sudo mv \"$ENV_PATH\" \"$BACKUP_PATH\""
fi

info "Copying sync-holes.env → $ENV_DIR"
run_cmd "sudo cp \"$CLONE_DIR/sync-holes.env\" \"$ENV_PATH\""

###############################################################################
# 7. Prompt to Edit .env
###############################################################################
echo ""
prompt "Do you wish to edit '$ENV_PATH' now to configure you Pi-holes? (y/N): "
read -r env_edit_choice

if [[ "$env_edit_choice" =~ ^[Yy]$ ]]; then
  EDITOR_CMD="${EDITOR:-nano}"
  if ! command -v "$EDITOR_CMD" >/dev/null 2>&1; then
    warn "Editor '$EDITOR_CMD' not found. Falling back to 'nano'..."
    EDITOR_CMD="nano"
  fi

  if ! command -v "$EDITOR_CMD" >/dev/null 2>&1; then
    warn "Neither \$EDITOR nor nano is available. Cannot open .env file."
  else
    if [[ $SIMULATE -eq 1 ]]; then
      info "[SIMULATE] Would open $EDITOR_CMD $ENV_PATH"
    else
      sudo "$EDITOR_CMD" "$ENV_PATH"
    fi
  fi
fi

###############################################################################
# 8. Symlink Creation
###############################################################################
if [[ $ADVANCED -eq 1 ]]; then
  # In advanced mode, prompt user for symlink creation
  echo ""
  prompt "Create symlink '/usr/local/bin/sync-holes'? (y/N): "
  read -r link_choice
  if [[ "$link_choice" =~ ^[Yy]$ ]]; then
    run_cmd "sudo ln -sf \"$INSTALL_DIR/sync-holes.sh\" /usr/local/bin/sync-holes"
    info "Symlink created: /usr/local/bin/sync-holes → $INSTALL_DIR/sync-holes.sh"
  fi
else
  # In basic mode, always create the symlink without prompting
  info "Basic mode: creating symlink /usr/local/bin/sync-holes → $INSTALL_DIR/sync-holes.sh"
  run_cmd "sudo ln -sf \"$INSTALL_DIR/sync-holes.sh\" /usr/local/bin/sync-holes"
fi

###############################################################################
# 9. Cron Option (with Duplicate Check)
###############################################################################
echo ""
prompt "Do you want to schedule sync-holes via cron? (y/N): "
read -r cron_choice
if [[ "$cron_choice" =~ ^[Yy]$ ]]; then
  info "Default schedule is daily at 3:00 AM: $CRON_DEFAULT_SCHEDULE"
  echo -e "Press Enter to accept default or type a cron expression (e.g. '0 4 * * *')"
  prompt "Cron schedule: "
  read -r user_schedule
  if [[ -z "$user_schedule" ]]; then
    user_schedule="$CRON_DEFAULT_SCHEDULE"
  fi

  SCRIPT_PATH="$INSTALL_DIR/sync-holes"
  CRON_LINE="$user_schedule $SCRIPT_PATH -v"

  existing_cron="$(crontab -l 2>/dev/null || true)"
  existing_line="$(echo "$existing_cron" | grep "$SCRIPT_PATH" || true)"

  if [[ -n "$existing_line" ]]; then
    info "Found existing crontab line(s) referencing '$SCRIPT_PATH':"
    echo "$existing_line"
    echo ""
    echo -e "${CYAN}Options:${NC}"
    echo -e "  ${CYAN}A)${NC} Add a new line anyway"
    echo -e "  ${CYAN}R)${NC} Replace the existing line(s) with your new schedule"
    echo -e "  ${CYAN}N)${NC} Do nothing (keep the old line, skip new one)"
    echo -e "  ${CYAN}C)${NC} Cancel (abort installation)"
    prompt "Please select [A/R/N/C]: "
    read -r user_choice

    case "$user_choice" in
      [Aa])
        info "Adding a new line anyway..."
        updated_cron="$existing_cron
$CRON_LINE"
        ;;
      [Rr])
        info "Replacing existing line(s) with new schedule..."
        updated_cron="$(echo "$existing_cron" | grep -v "$SCRIPT_PATH")
$CRON_LINE"
        ;;
      [Nn])
        info "Doing nothing. Keeping existing line(s)."
        updated_cron="$existing_cron"
        ;;
      [Cc])
        info "Canceling. No changes made to cron."
        updated_cron="$existing_cron"
        ;;
      *)
        warn "Invalid option. No changes made to cron."
        updated_cron="$existing_cron"
        ;;
    esac
  else
    info "No existing crontab entry referencing '$SCRIPT_PATH'."
    info "Adding a new line: $CRON_LINE"
    updated_cron="$existing_cron
$CRON_LINE"
  fi

  if [[ "$user_choice" != "C" ]]; then
    if [[ $SIMULATE -eq 1 ]]; then
      info "[SIMULATE] Would update crontab with:"
      echo "$updated_cron"
    else
      echo "$updated_cron" | crontab -
      info "Crontab updated."
    fi
  fi
fi

###############################################################################
# 10. Warn about system directories
###############################################################################
if [[ "$INSTALL_DIR" =~ ^/usr/ || "$ENV_DIR" =~ ^/usr/ ]]; then
  warn "You installed files in a system directory. Future updates or modifications may require sudo privileges."
fi

###############################################################################
# 11. Final Message
###############################################################################
echo ""
if [[ $SIMULATE -eq 1 ]]; then
  info "Installation simulated. No changes were made."
else
  info "Installation complete!"
  info "You can run the script via: $INSTALL_DIR/sync-holes"
  if [[ $ADVANCED -eq 0 ]]; then
    info "If you need to relocate files or create a symlink, re-run with --advanced."
  fi
fi
