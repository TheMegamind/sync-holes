#!/usr/bin/env bash
SCRIPT_VERSION="0.9.7.4"
#
# ===============================================================================
#                            sync-install.sh
#
#      Installs sync-holes.sh from https://github.com/TheMegamind/sync-holes
#     with optional advanced features, simulation mode, Pi-hole version checks,
#              color-coded prompts, and cron duplication logic.
# ===============================================================================
#
# MIT License
#
# (c) 2025 by Megamind
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
#   Date            Description
#   -------------   --------------------------------------------------------------------
#   03-05-2025      0.9.4    Initial Beta Release of Installation Script
#   03-05-2025      0.9.5    Beta Release Candidate 0.9.5 (Debian-based)
#   03-15-2025      0.9.6    Fixes for Fedora-based, and macOS installs
#   03-15-2025      0.9.6.1  If no local .env exists, skip “newer .env available” prompt 
#   03-16-2025      0.9.7    Check for newer install script, add logging, bump version #
#   03-16-2025      0.9.7.1  Revise check for newer install script
#   03-17-2025      0.9.7.2  Add Retry Options+ when Pi-hole config fails validation
#   03-17-2025      0.9.7.3  Clarify port suggestion for https//
#   03-23-2025      0.9.7.4  Improved guidance on default protocol/port pairings
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

#==============================================================================
# Color Variables
#==============================================================================
YELLOW="\033[1;33m"
GREEN="\033[1;32m"
RED="\033[1;31m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
NC="\033[0m"

#==============================================================================
# Default Variables
#==============================================================================
REPO_URL="https://github.com/TheMegamind/sync-holes.git"
CLONE_DIR="."  
INSTALL_DIR="/usr/local/bin"
ENV_DIR="/usr/local/etc"
SIMULATE=0
ADVANCED=0

CRON_DEFAULT_SCHEDULE="0 3 * * *"  # e.g., run daily at 3:00 AM

#==============================================================================
# Helper: Print usage
#==============================================================================
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

#==============================================================================
# Parse Command-Line Arguments
#==============================================================================
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
      echo -e "[\033[1;31mERROR\033[0m] Unknown option: $1"
      usage
      ;;
  esac
done

#==============================================================================
# Rotate Old Log & Start Logging
# Keep one backup (sync-install.log.old) and create a fresh sync-install.log
#==============================================================================
LOGFILE="./sync-install.log"
if [[ -f "$LOGFILE" ]]; then
  mv "$LOGFILE" "${LOGFILE}.old"
fi

exec > >(tee -a "$LOGFILE") 2>&1

#==============================================================================
# run_cmd: Wrapper to run commands or simulate
#==============================================================================
run_cmd() {
  if [[ $SIMULATE -eq 1 ]]; then
    echo -e "[${YELLOW}SIMULATE${NC}] $*"
  else
    eval "$@"
  fi
}

#==============================================================================
# Logging/Prompt Functions
#==============================================================================
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

script_name=$(basename "$0")  #
info "Running $(basename "$0") v${SCRIPT_VERSION}..."

#==============================================================================
# 1. Check for Dependencies
#==============================================================================
info "Checking for necessary packages: git, curl, jq..."

# Replaced Debian-only apt-get lines with OS detection for Debian, Fedora, macOS
if command -v apt-get >/dev/null 2>&1; then
  run_cmd "sudo apt-get update -y"
  run_cmd "sudo apt-get install -y git curl jq"
elif command -v dnf >/dev/null 2>&1; then
  run_cmd "sudo dnf install -y git curl jq"
elif [[ "$(uname)" == "Darwin" ]]; then
  run_cmd "brew install git curl jq"
else
  warn "No recognized package manager found. Please install git, curl, and jq manually."
fi

# Quick check for Bash 4+
BASH_VERSION_MAJOR="${BASH_VERSINFO:-0}"
if (( BASH_VERSION_MAJOR < 4 )); then
  warn "You appear to be running an older Bash (<4). Arrays may not work."
fi

#==============================================================================
# 2. Check Pi-hole Version
#==============================================================================
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

#==============================================================================
# 3. Clone or Update the Repository
#==============================================================================

if [[ -d "$CLONE_DIR/.git" ]]; then
  info "Directory '$CLONE_DIR' has .git; pulling latest changes..."

  # 1. Capture the current commit hash before pulling
  old_sha="$(git rev-parse HEAD 2>/dev/null || true)"

  # 2. Pull the latest changes
  run_cmd "cd \"$CLONE_DIR\" && git pull"

  # 3. Capture the new commit hash after pulling
  new_sha="$(git rev-parse HEAD 2>/dev/null || true)"

  # 4. Only if we actually got a different commit do we check for changed files
  if [[ "$old_sha" != "$new_sha" ]]; then
    # Find which files changed between old_sha and new_sha
    changed_files="$(git diff --name-only "$old_sha" "$new_sha" 2>/dev/null || true)"

    # 5. If sync-install.sh is indeed in the changed set, prompt user
    if echo "$changed_files" | grep -q '^sync-install.sh$'; then
      warn "A newer version of 'sync-install.sh' is now available."
      prompt "Would you like to restart with the updated script? (y/N): "
      read -r restart_choice
      if [[ "$restart_choice" =~ ^[Yy]$ ]]; then
        info "Re-running updated install script..."
        exec "$0" "$@"  # re-run the script with the same args
      else
        warn "Continuing with old version of sync-install.sh."
      fi
    fi
  fi

else
  info "Cloning repository from $REPO_URL into current directory..."
  run_cmd "git clone \"$REPO_URL\" ."
fi

#==============================================================================
# 4. Basic vs Advanced Install
#==============================================================================
if [[ $ADVANCED -eq 1 ]]; then
  info "Entering ADVANCED install mode..."

  prompt "Script install directory? Press Enter to keep default: [$INSTALL_DIR] "
  read -r choice
  if [[ -n "$choice" ]]; then
    # If there's an old file in the old $INSTALL_DIR, remove it
    if [[ -f "$INSTALL_DIR/sync-holes.sh" && "$INSTALL_DIR" != "$choice" ]]; then
      prompt "Remove old $INSTALL_DIR/sync-holes.sh? (y/N): "
      read -r remove_sh
      if [[ "$remove_sh" =~ ^[Yy]$ ]]; then
        run_cmd "sudo rm -f \"$INSTALL_DIR/sync-holes.sh\""
      fi
    fi
    INSTALL_DIR="$choice"
  fi

  prompt "Environment (.env) directory? Press Enter to keep default: [$ENV_DIR] "
  read -r choice
  if [[ -n "$choice" ]]; then
    # If there's an old env file in the old $ENV_DIR, remove it
    if [[ -f "$ENV_DIR/sync-holes.env" && "$ENV_DIR" != "$choice" ]]; then
      prompt "Remove old $ENV_DIR/sync-holes.env? (y/N): "
      read -r remove_env
      if [[ "$remove_env" =~ ^[Yy]$ ]]; then
        run_cmd "sudo rm -f \"$ENV_DIR/sync-holes.env\""
      fi
    fi
    ENV_DIR="$choice"
  fi
else
  info "BASIC install mode: using default directories ($INSTALL_DIR, $ENV_DIR)."
fi

#==============================================================================
# 5. Create Directories & Copy Script
#==============================================================================
info "Creating target directories if needed..."
run_cmd "sudo mkdir -p \"$INSTALL_DIR\""
run_cmd "sudo mkdir -p \"$ENV_DIR\""

info "Copying sync-holes.sh → $INSTALL_DIR/sync-holes.sh"
run_cmd "sudo cp \"sync-holes.sh\" \"$INSTALL_DIR/sync-holes.sh\""
run_cmd "sudo chmod +x \"$INSTALL_DIR/sync-holes.sh\""

#==============================================================================
# 6. Compare Timestamps & Back Up Existing sync-holes.env if Repo is Newer
#    Now also prompt the user whether to overwrite or keep the old .env, and
#    display the last commit message if available.
#==============================================================================
ENV_PATH="$ENV_DIR/sync-holes.env"

LOCAL_MTIME=0
REPO_MTIME=0

if [[ -f "$ENV_PATH" ]]; then
  LOCAL_MTIME=$(stat -c %Y "$ENV_PATH" 2>/dev/null || echo 0)

  if [[ -f "sync-holes.env" ]]; then
    REPO_MTIME=$(stat -c %Y "sync-holes.env" 2>/dev/null || echo 0)
  fi

  if (( REPO_MTIME > LOCAL_MTIME )); then
    # Attempt to retrieve last commit message for sync-holes.env, if .git is present
    if [[ -d .git ]]; then
      last_commit_msg=$(git log -1 --pretty=format:"%B" -- sync-holes.env 2>/dev/null || true)
      if [[ -n "$last_commit_msg" ]]; then
        warn "Latest commit message for sync-holes.env (for your reference):"
        info "$last_commit_msg"
      fi
    fi

    # Prompt user to overwrite or keep old
    prompt "A newer sync-holes.env is available. Overwrite your existing .env? (O=Overwrite, K=Keep) [O/K]: "
    read -r env_choice
    if [[ "$env_choice" =~ ^[Oo]$ ]]; then
      if [[ -f "$ENV_PATH" ]]; then
        BACKUP_PATH="$ENV_PATH.$(date +%Y%m%d%H%M%S).bak"
        warn "Found existing sync-holes.env at $ENV_PATH"
        warn "Backing it up to $BACKUP_PATH"
        run_cmd "sudo mv \"$ENV_PATH\" \"$BACKUP_PATH\""
      fi
      info "Copying sync-holes.env → $ENV_DIR (newer version detected)"
      run_cmd "sudo cp \"sync-holes.env\" \"$ENV_PATH\""
    else
      info "Keeping your existing .env. Skipping copy."
    fi
  else
    info "Local sync-holes.env is same or newer than repo's; skipping .env copy."
  fi

else
  # If no local .env exists at all, just copy from repo if it exists
  if [[ -f "sync-holes.env" ]]; then
    info "No existing .env found at $ENV_PATH. Copying sync-holes.env to $ENV_DIR now."
    run_cmd "sudo cp \"sync-holes.env\" \"$ENV_PATH\""
  else
    warn "No sync-holes.env in the repo and none locally. Nothing to copy."
  fi
fi

#==============================================================================
# 6b. If user changed ENV_DIR, create symlink so main script can still find it
#==============================================================================
DEFAULT_ENV_PATH="/usr/local/etc/sync-holes.env"
if [[ "$ENV_DIR" != "/usr/local/etc" ]]; then
  warn "You changed ENV_DIR from the default. We'll create a symlink so sync-holes.sh can still read /usr/local/etc/sync-holes.env."
  run_cmd "sudo ln -sf \"$ENV_PATH\" \"$DEFAULT_ENV_PATH\""
fi

#==============================================================================
# 7. Prompt to Edit or Configure .env
#==============================================================================
echo ""
prompt "Do you wish to configure your Pi-hole(s) in '$ENV_PATH' now? (y/N): "
read -r config_choice

configure_piholes() {
  # DELETE any existing session files to avoid mismatches
  info "Removing any existing session files to avoid stale or mismatched sessions..."
  run_cmd "sudo rm -f /tmp/primary-session.json /tmp/secondary-session_*.json 2>/dev/null || true"
  
  echo ""
  info "Configuration Notes:"
  info "  Pi-hole #1 is the PRIMARY/SOURCE. All others are SECONDARY/TARGETS."
  info "  Pi-hole addresses must be entered in the form of http(s)://ip_address:port"
  info "  For https, the default port is 443; for http, use 80 (or sometimes 8080)"
  info "  Example: https://192.168.1.10:443 or http://192.168.1.10:80"
  info "  If you changed the Pi-hole webserver.port in advanced settings, use that port."
  echo ""

  prompt "How many Pi-hole instances do you want to configure? "
  read -r pi_count
  if ! [[ "$pi_count" =~ ^[0-9]+$ ]]; then
    warn "Invalid number. Aborting configuration."
    return
  fi

  local primary_done=0
  local second_names=()
  local second_urls=()
  local second_passes=()

  for (( i=1; i<=$pi_count; i++ )); do
    echo ""
    if (( i == 1 )); then
      info "Configuring Pi-hole #$i (PRIMARY)"
    else
      info "Configuring Pi-hole #$i (SECONDARY)"
    fi

    local done_configuring=0

    while [[ $done_configuring -eq 0 ]]; do
      prompt "Friendly Name: "
      read -r friendly
      prompt "URL (e.g. https://192.168.1.10:443): "
      read -r pihole_url
      prompt "Password (leave blank if none): "
      read -r pihole_pass

      info "Validating Pi-hole #$i with a test auth..."
      local curl_cmd="curl -s -S -k -X POST \"$pihole_url/api/auth\" -H \"Content-Type: application/json\" --data '{\"password\":\"$pihole_pass\"}'"
      local response=''

      if [[ $SIMULATE -eq 1 ]]; then
        info "[SIMULATE] Would run: $curl_cmd"
        response='{"session":{"valid":true,"sid":"fake","message":"password correct"}}'
      else
        response=$(eval "$curl_cmd" 2>/dev/null || true)
      fi

      # Check if validation succeeded
      if [[ -n "$response" ]] && echo "$response" | grep -q '"valid":true'; then
        info "Validation successful for $friendly!"
        # Immediately store data and break from loop
        done_configuring=1
      else
        # Validation failed
        if [[ -z "$response" ]]; then
          warn "No response from the API. Check your URL:port or SSL settings."
        else
          warn "Validation failed for Pi-hole #$i. Response: $response"
        fi

        echo -e "${CYAN}Choose an action:${NC}"
        echo -e "  ${CYAN}R)${NC} Retry data entry for this Pi-hole"
        echo -e "  ${CYAN}A)${NC} Accept these settings anyway? (NOT RECOMMENDED)"
        echo -e "  ${CYAN}S)${NC} Skip configuring this Pi-hole entirely"
        echo -e "  ${CYAN}C)${NC} Cancel/quit installation"
        prompt "[R/A/S/C]: "
        read -r user_choice

        case "$user_choice" in
          [Rr])
            warn "Re-entering data for Pi-hole #$i..."
            ;;
          [Aa])
            prompt "Are you sure you want to ACCEPT these settings for Pi-hole #$i? (y/N): "
            read -r confirm_a
            if [[ "$confirm_a" =~ ^[Yy]$ ]]; then
              warn "Accepting data for Pi-hole #$i even though validation failed."
              done_configuring=1
            fi
            ;;
          [Ss])
            prompt "Are you sure you want to SKIP Pi-hole #$i entirely? (y/N): "
            read -r confirm_s
            if [[ "$confirm_s" =~ ^[Yy]$ ]]; then
              warn "Skipping configuration for Pi-hole #$i. This Pi-hole won't be added to .env."
              # We'll set 'friendly' etc. to blank
              friendly=""
              pihole_url=""
              pihole_pass=""
              done_configuring=1
            fi
            ;;
          [Cc])
            prompt "Are you sure you want to CANCEL the entire installation? (y/N): "
            read -r confirm_c
            if [[ "$confirm_c" =~ ^[Yy]$ ]]; then
              warn "User chose to cancel installation. Exiting now."
              exit 1
            fi
            ;;
          *)
            warn "Invalid choice. Please select [R/A/S/C]."
            ;;
        esac
      fi
    done

    # If the user ended up skipping this Pi-hole, 'friendly' will be blank.
    if [[ -n "$friendly" && -n "$pihole_url" ]]; then
      # If it's the first Pi-hole and not done yet, it’s primary
      if (( i == 1 && primary_done == 0 )); then
        run_cmd "sudo sed -i 's|^primary_name=.*|primary_name=\"$friendly\"|' \"$ENV_PATH\" || true"
        run_cmd "sudo sed -i 's|^primary_url=.*|primary_url=\"$pihole_url\"|' \"$ENV_PATH\" || true"
        run_cmd "sudo sed -i 's|^primary_pass=.*|primary_pass=\"$pihole_pass\"|' \"$ENV_PATH\" || true"
        primary_done=1
      else
        second_names+=("$friendly")
        second_urls+=("$pihole_url")
        second_passes+=("$pihole_pass")
      fi
    else
      # User explicitly skipped
      warn "Pi-hole #$i was skipped. No data recorded in .env."
    fi
  done

# ---------------------------------------------------------------------------
# Insert Secondary Arrays Below:
#   "# ** DO NOT REMOVE OR MODIFY THIS LINE — INSTALL SCRIPT INSERTS DATA BELOW **"
# but only if pi_count > 1
# ---------------------------------------------------------------------------
if (( pi_count > 1 )); then
  local names_str="secondary_names=("
  local urls_str="secondary_urls=("
  local passes_str="secondary_passes=("

  for (( j=0; j<${#second_names[@]}; j++ )); do
    # Original user input
    local raw_name="${second_names[$j]}"
    local raw_url="${second_urls[$j]}"
    local raw_pass="${second_passes[$j]}"

    # Only escape double quotes in user input (e.g., if they typed " or \")
    # so that your .env remains valid shell syntax:
    raw_name="${raw_name//\"/\\\"}"
    raw_url="${raw_url//\"/\\\"}"
    raw_pass="${raw_pass//\"/\\\"}"

    names_str+="\"$raw_name\" "
    urls_str+="\"$raw_url\" "
    passes_str+="\"$raw_pass\" "
  done

  names_str+=")"
  urls_str+=")"
  passes_str+=")"

  # Remove any old secondary_ lines from .env
  run_cmd "sudo sed -i '/^secondary_names=/d' \"$ENV_PATH\""
  run_cmd "sudo sed -i '/^secondary_urls=/d' \"$ENV_PATH\""
  run_cmd "sudo sed -i '/^secondary_passes=/d' \"$ENV_PATH\""

  # Build a temporary file with new lines
  local temp_file
  temp_file="$(mktemp)"
  echo "$names_str"  >> "$temp_file"
  echo "$urls_str"   >> "$temp_file"
  echo "$passes_str" >> "$temp_file"

  # Insert them right after the line:
  # ** DO NOT REMOVE OR MODIFY THIS LINE — INSTALL SCRIPT INSERTS DATA BELOW **
  run_cmd "sudo sed -i '/^# \\*\\* DO NOT REMOVE OR MODIFY THIS LINE - INSTALL SCRIPT INSERTS DATA BELOW/r $temp_file' \"$ENV_PATH\""

  rm -f "$temp_file"
fi

info "Done configuring Pi-holes!"
}

if [[ "$config_choice" =~ ^[Yy]$ ]]; then
  if [[ $SIMULATE -eq 1 ]]; then
    info "[SIMULATE] Would configure Pi-holes by prompting user..."
  else
    configure_piholes
  fi
else
  info "Skipping Pi-hole configuration. Any existing Pi-hole settings in $ENV_PATH will remain unchanged."
fi

#==============================================================================
# 8. Symlink Creation
#==============================================================================
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
  info "Creating symlink /usr/local/bin/sync-holes → $INSTALL_DIR/sync-holes.sh"
  run_cmd "sudo ln -sf \"$INSTALL_DIR/sync-holes.sh\" /usr/local/bin/sync-holes"
fi

#==============================================================================
# 9. Cron Option (with Duplicate Check)
#==============================================================================
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
    echo -e "  ${CYAN}N)${NC} Do nothing (keep the existing line, skip new one)"
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

#==============================================================================
# 10. Warn about system directories
#==============================================================================
if [[ "$INSTALL_DIR" =~ ^/usr/ || "$ENV_DIR" =~ ^/usr/ ]]; then
  warn "You installed files in a system directory. Future updates or modifications may require sudo privileges."
fi

#==============================================================================
# 11. Final Message
#==============================================================================
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

#==============================================================================
# 12. Append .env to the Log without printing to console
#==============================================================================
if [[ -f "$ENV_PATH" ]]; then
  info "Your final .env has been appended to the log: $LOGFILE (with passwords masked)."
  echo ""
  echo "" >> "$LOGFILE"
  echo "" >> "$LOGFILE"
  echo "=== Final .env (masked) ===" >> "$LOGFILE"
  echo "" >> "$LOGFILE"
  
  # Read the .env file, mask the passwords, and append to the log
  cat "$ENV_PATH" \
    | sed -E 's/^(primary_pass=")[^"]*(")/\1*****\2/' \
    | sed -E 's/^(.*secondary_passes=.*\().*(\).*)/\1*****\2/' \
    >> "$LOGFILE"
fi
