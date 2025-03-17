#!/usr/bin/env bash
SCRIPT_VERSION="0.9.7"
#
# ===============================================================================
#                            sync-holes.sh
#         Synchronize Primary Pi-hole to Multiple Secondary Pi-holes
#
#       ** Back-up Teleporter settings BEFORE testing this script!! **
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
#   Date          Description
#   -----------   ------------------------------------------------------------
#   01-05-2025    0.9.0    Initial Beta Release
#   01-19-2025    0.9.1    Fix Log Rotation
#   02-22-2025    0.9.2    Fix Import Options Handling
#   03-03-2025    0.9.3    Synchronize > 2 Pi-holes
#   03-04-2025    0.9.4    Override Import Settings via CLI
#   03-06-2025    0.9.5    Beta Release Candidate 0.9.5
#   03-09-2025    0.9.5.2  dhcp_leases default to false, use /usr/bin/env bash
#   03-12-2025    0.9.5.3  Add version number to logging for troubleshooting
#   03-15-2025    0.9.6    Fixes for Fedora-based, and macOS installs
#   03-15-2025    0.9.6.1  Expand checks for valid JSON and added error handling
#   03-15-2025    0.9.6.2  Tweak Error Messages for invalid JSON response
#   03-15-2025    0.9.6.3  Add validation of Pi-hole Configuration changes
#   03-15-2025    0.9.7    Bump Version # for newest release
#
# ===============================================================================
#

# =======================================
# Color Codes
# =======================================
declare -Ar COLORS=(
  [green]="\e[32m"
  [yellow]="\e[33m"
  [red]="\e[31m"
  [nc]="\e[0m"  # No Color
)

# ========================================
# Default Values for Environment Variables
# ========================================
# Note:
# The .env is read from /usr/local/etc/sync-holes.env. Depending on the
# the installation this may be a literal file OR a symlink to the user's
# preferred directory created by the install script.
declare -r env_file="/usr/local/etc/sync-holes.env"

declare -r default_log_file="/var/log/sync-holes.log"
declare -r default_temp_files_path="/tmp"

declare -r default_log_size_limit=1   # Default log file size limit in MB
declare -r default_max_old_logs=1     # Default max number of old log files to retain
declare -r default_verify_ssl=0       # Default to SSL verification disabled
declare -r default_mask_sensitive=1   # Default masking for sensitive data

declare -r default_import_settings_json="{}"  # Default import settings JSON placeholder
declare -r default_curl_error_log="$default_temp_files_path/curl_error_log.log"
declare -r auth_response_file="$default_temp_files_path/auth_response.json"

################################################################################
#                           ENVIRONMENT & LOGGING
################################################################################

# =======================================
# Logging & Print output functions
# =======================================
# Arguments:
#   $1 - Tag (e.g., INFO, DEBUG, ERROR)
#   $2 - Message to log (and optionally print to console)
#   $3 - Mode: "always" or "if_verbose"
#        "always" = message is both logged and printed to console
#        "if_verbose" = message is logged, but only printed when verbose=1
#   $4 - Optional color code (e.g., green, yellow, red)
#
#   Log file entries include a timestamp. Console Entries do not.
# =======================================
log_message() {
    local tag="$1"
    local message="$2"
    local mode="$3"
    local color="$4"

    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    # Try to append the message to the log file silently
    if [[ -n "$log_file" ]] && [[ -w "$(dirname "$log_file")" ]]; then
        echo "$timestamp [$tag] $message" >> "$log_file" 2>/dev/null
    fi

    # Handle verbosity for console output
    local is_verbose=0
    if [[ "${verbose:-0}" == "1" ]]; then
        is_verbose=1
    fi

    # Print to console if "always" or "if_verbose" and verbose mode is enabled
    if [[ "$mode" == "always" || ("$mode" == "if_verbose" && "$is_verbose" == "1") ]]; then
        if [[ -n "$color" && -n "${COLORS[$color]}" ]]; then
            if [[ "$is_verbose" == "1" ]]; then
                # Print with tag and color
                echo -e "[${COLORS[nc]}${COLORS[$color]}$tag${COLORS[nc]}] ${COLORS[$color]}$message${COLORS[nc]}" >&2
            else
                # Print message only, with color
                echo -e "${COLORS[$color]}$message${COLORS[nc]}" >&2
            fi
        else
            if [[ "$is_verbose" == "1" ]]; then
                # Print with tag, no color
                echo "[$tag] $message" >&2
            else
                # Print message only, no color
                echo "$message" >&2
            fi
        fi
    fi
}

# =======================================
# Mask Sensitive Data Function
# =======================================
# Masks sensitive information like passwords and session IDs in logs.
mask_sensitive_data() {
    local data="$1"
    # Skip masking if mask_sensitive is 0
    if [[ "$mask_sensitive" -eq 0 ]]; then
        echo "$data"
        return
    fi

    # Apply masking if enabled
    echo "$data" | sed -E '
        s/("password":[ ]*)"[^"]*"/\1"*****"/g;
        s/("sid":[ ]*)"[^"]*"/\1"*****"/g;
        s/(password:[ ]*)[^ ]*/\1*****/g;
        s/(sid:[ ]*)[^ ]*/\1*****/g;
        s/(Found sessionID:[ ]*)[^ ]*/\1*****/g;
    '
}

# =======================================
# Display Usage Instructions
# =======================================
# Prints the script's usage information and exits.
usage() {
    example_json='{"config":false,"dhcp_leases":false,"gravity":{"group":true,"adlist":false,"adlist_by_group":true,"domainlist":true,"domainlist_by_group":true,"client":true,"client_by_group":false}}'
    pretty_json=$(echo "$example_json" | jq .)
    echo ""
    echo "============================================================================="
    echo ""
    echo "Description:"
    echo "  This script synchronizes Teleporter settings from a primary Pi-hole to"
    echo "  multiple secondary Pi-hole instances."
    echo "    ** Pi-hole v6 is required. This will not work with earlier versions **"
    echo ""
    echo "Usage: $(basename "$0") [-v] [-h] [-u] [-I inline_json] [-F json_file]"
    echo ""
    echo "Options:"
    echo "  -v               Enable verbose mode"
    echo "  -h               Display this help message"
    echo "  -u               Disable masking of sensitive data in logs (unmask)"
    echo "  -I inline_json   Override import settings with an inline JSON string."
    echo "  -F json_file     Override import settings by specifying a JSON file."
    echo ""
    echo "Examples:"
    echo "  # Run the script normally"
    echo "    $(basename "$0")"
    echo "  # Run the script with verbose output"
    echo "    $(basename "$0") -v"
    echo "  # Run the script without masking sensitive data"
    echo "    $(basename "$0") -u"
    echo ""
    echo "  # Run with import settings overridden inline via JSON"
    echo "    $(basename "$0") -I '$pretty_json'"
    echo ""
    echo "  # Run with import settings overridden by a JSON file"
    echo "    $(basename "$0") -F /path/to/import_settings.json"
    echo ""
    echo "Note:"
    echo "  Any import settings keys omitted from the inline or file-based JSON will,"
    echo "  assume their default value from the .env file. So if a user wants to"
    echo "  override only one or two keys, they may supply an abbreviated JSON"
    echo "  (e.g. '{\"dhcp_leases\": false}') and only the default value(s) for the"
    echo "  specified key(s) will be overridden while all others remain unchanged."
    echo ""
    echo "Reminder:"
    echo "  Depending on your installation and system configuration, you may need to run"
    echo "  this script with sudo to access protected directories, for example:"
    echo ""
    echo "    sudo $(basename "$0")           # Run the script normally using sudo"
    echo "    sudo $(basename "$0") -v        # Run the script with verbose output using sudo"
    echo ""
    echo "============================================================================="
    echo ""
    exit 1
}

# =======================================
# Parse options using getopts
# =======================================
verbose=0
override_import_settings=""
import_settings_file=""

while getopts ":vhuI:F:" opt; do
  case ${opt} in
    v )
      verbose=1
      ;;
    u )
      mask_sensitive_override=0  # Explicit override for unmasking
      ;;
    I )
      override_import_settings="$OPTARG"
      ;;
    F )
      import_settings_file="$OPTARG"
      ;;
    h )
      usage
      ;;
    \? )
      echo "Invalid Option: -$OPTARG" 1>&2
      usage
      ;;
  esac
done

# =======================================
# Load Environment Variables
# =======================================
script_name=$(basename "$0")  #
load_env() {
    if [ -f "$env_file" ]; then
        source "$env_file"

        # .env file loaded, log script version for reference in troubleshooting
        script_name=$(basename "$0")  #
        log_message "START" "Running $(basename "$0") v${SCRIPT_VERSION}..." "always"

        log_message "ENV" "Environment file '$env_file' loaded." "if_verbose"

        # Ensure getopts overrides the .env file for mask_sensitive
        mask_sensitive="${mask_sensitive_override:-$mask_sensitive}"
    else
        handle_error "Environment file '$env_file' not found. Exiting."
    fi
}

# =======================================
# Check Required Dependencies
# =======================================
check_dependencies() {
    local missing_deps=()
    if ! command -v jq &> /dev/null; then
        missing_deps+=("'jq'")
    fi
    if ! command -v curl &> /dev/null; then
        missing_deps+=("'curl'")
    fi

    # NEW: Attempt to auto-install if missing. Then re-check. Debian, Fedora, macOS only.
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_message "INFO" "Detected missing dependencies: ${missing_deps[*]}."

        # Convert array to space-separated string (strip quotes)
        local to_install=""
        for dep in "${missing_deps[@]}"; do
            to_install+=" ${dep//\'/}"
        done

        log_message "INFO" "Attempting to install missing dependencies on Debian-based, Fedora-based, or macOS..."

        if command -v apt-get >/dev/null 2>&1; then
            # Debian-based
            log_message "INFO" "Using apt-get to install $to_install..."
            sudo apt-get update -y && sudo apt-get install -y $to_install || true
        elif command -v dnf >/dev/null 2>&1; then
            # Fedora-based
            log_message "INFO" "Using dnf to install $to_install..."
            sudo dnf install -y $to_install || true
        elif [[ "$(uname)" == "Darwin" ]]; then
            # macOS
            log_message "INFO" "Using Homebrew to install $to_install..."
            brew install $to_install || true
        else
            log_message "WARN" "No recognized package manager found. Please install dependencies manually."
        fi
    fi

    # Re-check if dependencies are still missing
    local still_missing=()
    if ! command -v jq &> /dev/null; then
        still_missing+=("'jq'")
    fi
    if ! command -v curl &> /dev/null; then
        still_missing+=("'curl'")
    fi

    if [ ${#still_missing[@]} -ne 0 ]; then
        handle_error "Missing dependencies after attempted install: ${still_missing[*]}. Please install them to run this script."
    fi
}

# =======================================
# SSL Verification Check
# =======================================
ssl_verification() {
    if [ "${verify_ssl:-0}" -eq 0 ]; then
        log_message "ENV" "SSL verification is disabled (verify_ssl=0) in .env." "if_verbose"
    fi
}

# =======================================
# Validate Environment Variables and Paths
# =======================================
validate_env() {
    temp_files_path="${temp_files_path:-$default_temp_files_path}"
    log_file="${log_file:-$default_log_file}"
    log_size_limit="${log_size_limit:-$default_log_size_limit}"
    max_old_logs="${max_old_logs:-$default_max_old_logs}"
    verify_ssl="${verify_ssl:-$default_verify_ssl}"
    mask_sensitive="${mask_sensitive:-$default_mask_sensitive}"
    import_settings_json="${import_settings_json:-$default_import_settings_json}"

    import_config="${import_config:-false}"
    import_dhcp_leases="${import_dhcp_leases:-false}"
    import_gravity_group="${import_gravity_group:-true}"
    import_gravity_adlist="${import_gravity_adlist:-true}"
    import_gravity_adlist_by_group="${import_gravity_adlist_by_group:-true}"
    import_gravity_domainlist="${import_gravity_domainlist:-true}"
    import_gravity_domainlist_by_group="${import_gravity_domainlist_by_group:-true}"
    import_gravity_client="${import_gravity_client:-true}"
    import_gravity_client_by_group="${import_gravity_client_by_group:-true}"

    teleporter_file="$temp_files_path/teleporter.zip"
    primary_session_file="$temp_files_path/primary-session.json"
    curl_error_log="$temp_files_path/curl_error.log"

    local required_vars=("primary_url" "primary_pass" "primary_name")
    local missing_vars=()
    local invalid_urls=()

    # Check that temp_files_path is writable
    if [[ ! -d "$temp_files_path" || ! -w "$temp_files_path" ]]; then
        handle_error "Temporary files path '$temp_files_path' does not exist or is not writable. Please run with sudo or fix permissions."
    fi

    # Check that the directory of log_file is writable
    local log_dir
    log_dir="$(dirname "$log_file")"
    if [[ ! -d "$log_dir" || ! -w "$log_dir" ]]; then
        handle_error "Log file directory '$log_dir' does not exist or is not writable. Please run with sudo or fix permissions."
    fi

    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done

    if [ -z "${secondary_names[*]}" ] || [ -z "${secondary_urls[*]}" ] || [ -z "${secondary_passes[*]}" ]; then
        missing_vars+=("secondary_names, secondary_urls, secondary_passes")
    elif [ "${#secondary_names[@]}" -ne "${#secondary_urls[@]}" ] || [ "${#secondary_names[@]}" -ne "${#secondary_passes[@]}" ]; then
        handle_error "The arrays secondary_names, secondary_urls, and secondary_passes must have the same number of elements."
    fi

    local url_regex='^(https?://)([a-zA-Z0-9.-]+\.[a-zA-Z]{2,}|([0-9]{1,3}\.){3}[0-9]{1,3})(:[0-9]{1,5})?$'
    if [[ ! "$primary_url" =~ $url_regex ]]; then
        invalid_urls+=("primary_url")
    fi

    if [ ${#missing_vars[@]} -gt 0 ]; then
        handle_error "Missing environment variables: ${missing_vars[*]}."
    fi

    if [ ${#invalid_urls[@]} -gt 0 ]; then
        handle_error "Invalid URL format for: ${invalid_urls[*]} in $(basename "$env_file")."
    fi

    log_message "ENV" "All required environment variables and paths validated successfully." "if_verbose"
}

# =======================================
# Logging Size Limit & Rotation
# =======================================
check_log_size() {
    local log_size_limit=${log_size_limit:-5}
    local max_old_logs=${max_old_logs:-5}

    if [ -f "$log_file" ]; then
        local log_size_kb
        log_size_kb=$(du -k "$log_file" | cut -f1)

        if (( log_size_kb / 1024 >= log_size_limit )); then
            rotate_log
        fi
    fi

    cleanup_old_logs "$log_file" "$max_old_logs"
}

# =======================================
# Rotate Log File
# =======================================
rotate_log() {
    local timestamp
    timestamp=$(date +"%Y%m%d%H%M%S")
    mv "$log_file" "${log_file}.${timestamp}"
    log_message "INFO" "Log file rotated at $(date +"%Y-%m-%d %H:%M:%S")" "if_verbose"
    log_message "INFO" "Log file rotated. Previous log saved as ${log_file}.${timestamp}." "if_verbose"
}

# =======================================
# Cleanup Old Logs
# =======================================
cleanup_old_logs() {
    local log_file_base="$1"
    local retention_count="$2"

    ls -1t "${log_file_base}."* 2>/dev/null | tail -n +$((retention_count + 1)) | while read -r old_log; do
        rm -f "$old_log"
        log_message "INFO" "Deleted old log file: $old_log" "if_verbose"
    done
}

################################################################################
#                            ERROR & CLEANUP
################################################################################

# =======================================
# Handle Errors
# =======================================
handle_error() {
    local message="$1"
    verbose=1

    if [ -s "$curl_error_log" ]; then
        log_message "ERROR" "$(cat "$curl_error_log")" "always" "red"
        rm -f "$curl_error_log"
    else
        log_message "ERROR" "$message" "always" "red"
    fi

    exit 1
}

# =======================================
# Remove File Safely
# =======================================
remove_file() {
    local file_path="$1"
    local description="$2"

    if [ -f "$file_path" ]; then
        if rm -f "$file_path"; then
            log_message "CLEANUP" "Deleted $description: $file_path" "if_verbose"
        else
            log_message "ERROR":" Failed to delete $description: $file_path." "always"
            return 1
        fi
    fi
    return 0
}

# =======================================
# Cleanup Temporary Files on Exit Function
# =======================================
cleanup() {
    local exit_code=$?

    log_message "CLEANUP" "Beginning cleanup..." "if_verbose"

    local cleanup_failed=0

    remove_file "$teleporter_file" "temporary backup file" || cleanup_failed=1
    remove_file "$curl_error_log" "curl error log" || cleanup_failed=1
    remove_file "$auth_response_file" "authentication response file" || cleanup_failed=1

    if [ $cleanup_failed -ne 0 ]; then
        exit_code=1
    fi

    if [ $exit_code -ne 0 ]; then
        log_message "INFO" "Exiting ($exit_code)." "always"
    else
        log_message "INFO" "Done." "if_verbose"
    fi

    exit "$exit_code"
}

trap 'cleanup' EXIT

################################################################################
#                              RUN_CURL
################################################################################

# =======================================
# Run Curl Commands (except Upload)
# =======================================
run_curl() {
    local method="$1"
    local url="$2"
    local headers="$3"
    local data="$4"
    local output="$5"
    shift 5
    local extra_args=("$@")

    local curl_args=(-s -k -S -X "$method" "$url")
    > "$curl_error_log"

    if [ -n "$headers" ]; then
        read -r -a header_array <<< "$headers"
        curl_args+=("${header_array[@]}")
    fi

    if [ ${#extra_args[@]} -gt 0 ]; then
        curl_args+=("${extra_args[@]}")
    fi

    if [ -n "$data" ]; then
        curl_args+=(--data "$data")
    fi

    if [ -n "$output" ]; then
        curl_args+=(-o "$output")
    fi

    local curl_command="curl $(printf "%s " "${curl_args[@]}")"
    local masked_curl_cmd
    masked_curl_cmd=$(mask_sensitive_data "$curl_command")
    log_message "CURL" "Run: ${masked_curl_cmd}" "if_verbose"

    local response
    response=$(curl "${curl_args[@]}" 2>"$curl_error_log")
    local curl_exit_code=$?

    if [ $curl_exit_code -ne 0 ]; then
        handle_error "Unable to complete synchronization due to CURL failure (transport or DNS error)."
    fi

    if [ -z "$output" ]; then
        echo "$response"
    fi
}

################################################################################
#                 AUTHENTICATION & SESSION MANAGEMENT
################################################################################

# =======================================
# Store Session
# =======================================
store_session() {
    local file="$1"
    local sid="$2"
    local validity="$3"
    local current_time
    current_time=$(date +%s)
    local expires_at=$((current_time + validity))

    jq -n --arg sid "$sid" --argjson expires_at "$expires_at" \
        '{sid: $sid, expires_at: $expires_at}' > "$file"

    local human_readable_expires_at
    human_readable_expires_at=$(date -d "@$expires_at" '+%Y-%m-%d %H:%M:%S')

    log_message "AUTHENTICATION" "$(mask_sensitive_data "New sessionID (SID) stored in $file (expires at $human_readable_expires_at)")" "if_verbose"
}

# =======================================
# Reuse Session
# =======================================
reuse_session() {
    local file="$1"

    log_message "AUTHENTICATION" "Attempting to reuse sessionID from $file" "if_verbose"

    if [ -f "$file" ]; then
        local current_time
        current_time=$(date +%s)
        local expires_at
        expires_at=$(jq -r '.expires_at' "$file" 2>/dev/null || echo 0)
        local sid
        sid=$(jq -r '.sid' "$file" 2>/dev/null)

        if ((current_time < expires_at)); then
            local human_readable_expires_at
            human_readable_expires_at=$(date -d "@$expires_at" '+%Y-%m-%d %H:%M:%S')

            log_message "AUTHENTICATION" "$(mask_sensitive_data "Found sessionID: $sid (expires at $human_readable_expires_at)")" "if_verbose"
            log_message "AUTHENTICATION" "Reusing valid sessionID for $(basename "$file" | cut -d'-' -f1) from $file" "always"
            echo "$sid"
            return 0
        fi

        log_message "AUTHENTICATION" "sessionID in $file has expired. Removing $file." "if_verbose"
        rm -f "$file"
    else
        log_message "AUTHENTICATION" "No sessionID file found at $file." "if_verbose"
    fi

    return 1
}

# =======================================
# Authenticate with REST API
# =======================================
authenticate() {
    local pi_name="$1"
    local pi_pass="$2"
    local pi_url="$3"
    local pi_session_file="$4"
    local pi_sid_var_name="$5"

    local pi_sid
    pi_sid=$(reuse_session "$pi_session_file")
    if [ -z "$pi_sid" ]; then
        local pi_auth_data="{\"password\":\"$pi_pass\"}"
        local pi_auth_url="$pi_url/api/auth"
        log_message "AUTHENTICATION" "$(mask_sensitive_data "Authenticating with $pi_name using password: $pi_pass")" "if_verbose"

        run_curl "POST" "$pi_auth_url" '-H Content-Type:application/json' "$pi_auth_data" "$auth_response_file"

        if [ ! -s "$auth_response_file" ]; then
            handle_error "Authentication response from $pi_name is empty or missing."
        fi

        local raw_auth
        raw_auth=$(cat "$auth_response_file")
        log_message "AUTHENTICATION" "API Response: $(mask_sensitive_data "$raw_auth")" "if_verbose"

        if ! echo "$raw_auth" | jq . >/dev/null 2>&1; then
            handle_error "Authentication failed. Invalid JSON returned from $pi_name. Confirm Pi-hole is running at $pi_url."
        fi

        local session_valid
        session_valid=$(echo "$raw_auth" | jq -r '.session.valid')
        pi_sid=$(echo "$raw_auth" | jq -r '.session.sid')
        local pi_validity
        pi_validity=$(echo "$raw_auth" | jq -r '.session.validity')

        if [ "$session_valid" == "false" ]; then
            handle_error "Authentication failed for $pi_name. $(echo "$raw_auth" | jq -r '.session.message')"
        elif [ -z "$pi_sid" ] || [ "$pi_sid" = "null" ]; then
            handle_error "No valid sessionID returned by $pi_name. Confirm Pi-hole is running at  $pi_url."
        else
            store_session "$pi_session_file" "$pi_sid" "$pi_validity"
            log_message "AUTHENTICATION" "$pi_name authenticated with session ID." "always"
        fi
    else
        log_message "AUTHENTICATION" "Using stored unexpired sessionID for $pi_name." "if_verbose"
    fi

    eval "$pi_sid_var_name='$pi_sid'"
    rm -f "$auth_response_file"
}

################################################################################
#                                 TELEPORTER
################################################################################

# =======================================
# Generate Import JSON
# =======================================
generate_import_json() {
  default_import_json=$(jq -n \
    --argjson config "$import_config" \
    --argjson dhcp_leases "$import_dhcp_leases" \
    --argjson gravity_group "$import_gravity_group" \
    --argjson gravity_adlist "$import_gravity_adlist" \
    --argjson gravity_adlist_by_group "$import_gravity_adlist_by_group" \
    --argjson gravity_domainlist "$import_gravity_domainlist" \
    --argjson gravity_domainlist_by_group "$import_gravity_domainlist_by_group" \
    --argjson gravity_client "$import_gravity_client" \
    --argjson gravity_client_by_group "$import_gravity_client_by_group" \
    '{config: $config, dhcp_leases: $dhcp_leases, gravity: {group: $gravity_group, adlist: $gravity_adlist, adlist_by_group: $gravity_adlist_by_group, domainlist: $gravity_domainlist, domainlist_by_group: $gravity_domainlist_by_group, client: $gravity_client, client_by_group: $gravity_client_by_group}}'
  )

  if [ -n "$override_import_settings" ]; then
    clean_override=$(echo "$override_import_settings" | jq 'with_entries(select(.value != null))')
    final_import_json=$(echo "$default_import_json" "$clean_override" | jq -s '.[0] * .[1] | del(..|select(. == null))')
  else
    final_import_json="$default_import_json"
  fi

  echo "$final_import_json"
}

# =======================================
# Download Teleporter File
# =======================================
download_teleporter_file() {
    local headers="-H Accept:application/zip"

    if [ -n "$primary_sid" ]; then
        headers="$headers -H sid:$primary_sid"
    else
        log_message "DOWNLOAD" "No sessionID provided for $primary_name; proceeding without authentication." "if_verbose"
    fi

    log_message "DOWNLOAD" "Downloading Teleporter settings from $primary_name." "if_verbose"
    run_curl "GET" "$primary_url/api/teleporter" "$headers" "" "$teleporter_file"

    if [ ! -f "$teleporter_file" ] || ! file "$teleporter_file" | grep -q "Zip archive data"; then
        handle_error "Failed to download or validate Teleporter file from $primary_name."
        return
    fi

    log_message "DOWNLOAD" "Teleporter file downloaded from $primary_name." "always"
}

# =======================================
# Upload Teleporter File to a Secondary Pi-hole
# =======================================
upload_teleporter_file() {
    local pi_name="$1"
    local pi_url="$2"
    local pi_sid="$3"
    local upload_url="${pi_url}/api/teleporter"
    log_message "UPLOAD" "Uploading Teleporter settings to $pi_name." "if_verbose"

    local import_settings_json
    import_settings_json=$(generate_import_json)
    local import_json_compact
    import_json_compact=$(echo "$import_settings_json" | jq -c .)

    local form_data=(-F "file=@$teleporter_file" -F "import=$import_json_compact")

    local upload_response
    upload_response=$(run_curl "POST" "$upload_url" "-H accept:application/json -H sid:$pi_sid" "" "" "${form_data[@]}")

    if [ -s "$curl_error_log" ]; then
        handle_error "CURL error during upload to $pi_name."
    fi

    if ! echo "$upload_response" | jq . >/dev/null 2>&1; then
        handle_error "Teleporter upload failed. Invalid JSON returned from $pi_name. Confirm Pi-hole is running at  $pi_url."
    fi

    log_message "UPLOAD" "API Response: $(echo "$upload_response" | jq -c .)" "if_verbose"

    if echo "$upload_response" | jq -e '.error' >/dev/null 2>&1; then
      handle_error "$(echo "$upload_response" | jq -r '.error.message')"
    fi

    log_message "UPLOAD" "Teleporter file uploaded to $pi_name." "always"
    log_message "INFO" "$primary_name and $pi_name settings synchronized!" "always" "green"
}

################################################################################
#         NEW: On-demand Pi-hole Validation if .env changes (Checksums)
################################################################################

ENV_CHECKSUM_FILE="${env_file}.sha256"

compute_env_checksum() {
  sha256sum "$env_file" 2>/dev/null | awk '{print $1}'
}

test_pihole_auth() {
  local name="$1"
  local pass="$2"
  local url="$3"

  # Minimal "auth" check
  local response
  response="$(curl -s -k -S -X POST "$url/api/auth" \
    -H "Content-Type: application/json" \
    --data "{\"password\":\"$pass\"}" 2>/dev/null || true)"

  if [[ -z "$response" ]]; then
    handle_error "No response from $name at $url. Possibly wrong URL or Pi-hole not reachable."
  fi

  # Check if response is valid JSON
  if ! echo "$response" | jq . >/dev/null 2>&1; then
    handle_error "Response from $name is not valid JSON. Possibly a 404 or old Pi-hole version. ($url)"
  fi

  # Check if we see "valid":true
  if ! echo "$response" | grep -q '"valid":true'; then
    handle_error "Validation failed for $name. $(mask_sensitive_data "$response")"
  fi

  log_message "ENV" "$name validated successfully via test auth." "always"
}

validate_piholes_after_env_changes() {
  # 1) Validate Primary
  log_message "ENV" "Testing connectivity for PRIMARY: $primary_name at $primary_url" "always"
  test_pihole_auth "$primary_name" "$primary_pass" "$primary_url"

  # 2) Validate each Secondary
  for i in "${!secondary_names[@]}"; do
    local s_name="${secondary_names[$i]}"
    local s_url="${secondary_urls[$i]}"
    local s_pass="${secondary_passes[$i]}"

    log_message "ENV" "Testing connectivity for SECONDARY: $s_name at $s_url" "always"
    test_pihole_auth "$s_name" "$s_pass" "$s_url"
  done

  log_message "ENV" "Extended Pi-hole validation passed for all instances." "always"
}

check_env_changes() {
  # If .env does not exist, just skip
  if [[ ! -f "$env_file" ]]; then
    return
  fi

  local current_hash
  current_hash="$(compute_env_checksum)"
  if [[ -z "$current_hash" ]]; then
    return
  fi

  if [[ -f "$ENV_CHECKSUM_FILE" ]]; then
    local old_hash
    old_hash="$(cat "$ENV_CHECKSUM_FILE" 2>/dev/null || true)"

    if [[ "$current_hash" != "$old_hash" ]]; then
      log_message "ENV" "Detected changes in $env_file. Running extended Pi-hole validation..." "always"
      validate_piholes_after_env_changes
      echo "$current_hash" > "$ENV_CHECKSUM_FILE"
    else
      log_message "ENV" "No changes in $env_file since last run. Skipping extended Pi-hole validation." "if_verbose"
    fi
  else
    log_message "ENV" "No previous checksum found for $env_file. Running extended Pi-hole validation..." "always"
    validate_piholes_after_env_changes
    echo "$current_hash" > "$ENV_CHECKSUM_FILE"
  fi
}

################################################################################
#                          MAIN SCRIPT EXECUTION FLOW
################################################################################

load_env           # 1) Load environment variables from .env file
check_env_changes  # 2) If .env changed, do extended Pi-hole connectivity checks
validate_env       # 3) Validate environment variables and paths
check_dependencies # 4) Ensure required commands are available
ssl_verification   # 5) Log SSL verification status

# Apply Import Settings Overrides AFTER loading .env
if [ -n "$import_settings_file" ]; then
  if [ -f "$import_settings_file" ]; then
    override_import_settings=$(cat "$import_settings_file")
  else
    log_message "ERROR" "Import settings file '$import_settings_file' not found." "always" "red"
    exit 1
  fi
fi

# Authenticate with the primary Pi-hole
primary_session_file="$temp_files_path/primary-session.json"
authenticate "$primary_name" "$primary_pass" "$primary_url" "$primary_session_file" "primary_sid"

# Download the Teleporter file from the primary Pi-hole
download_teleporter_file

# Loop over all secondary Pi-holes to synchronize the Teleporter file
for i in "${!secondary_names[@]}"; do
    secondary_name="${secondary_names[$i]}"
    secondary_url="${secondary_urls[$i]}"
    secondary_pass="${secondary_passes[$i]}"

    # Create a unique session file for each secondary Pi-hole
    secondary_session_file="${temp_files_path}/secondary-session_$i.json"

    # Authenticate with the secondary Pi-hole
    authenticate "$secondary_name" "$secondary_pass" "$secondary_url" "$secondary_session_file" "secondary_sid"

    # Upload the Teleporter file to the secondary Pi-hole
    upload_teleporter_file "$secondary_name" "$secondary_url" "$secondary_sid"
done
