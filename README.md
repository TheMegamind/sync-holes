# sync-holes.sh README

## Overview

`sync-holes.sh` synchronizes the Teleporter settings from a primary Pi-hole to multiple secondary Pi-hole instances via the Pi-hole REST API.

**Features:**
- Synchronizes settings using the `/api/teleporter` endpoint.
- Environment-based configuration via a `.env` file.
- Intelligent session management (re-authenticates only when needed).
- Configurable SSL support for self‑signed certificates.
- Command‑line options to control console output and sensitive data masking.
- Detailed logging with configurable size, rotation, and optional data masking.
- **Pending**
    - Install Script for Simplified Installation  
    - Option to Create/Set Cron
    - Optional Docker Installation

**History:**
- **01-05-2025** → Initial Beta Release  
- **01-19-2025** → 0.9.1 Fix Log Rotation  
- **02-22-2025** → 0.9.2 Fix Import Options Handling  
- **03-03-2025** → 0.9.3 Synchronize > 2 Pi-holes  
  - *Requires updated sync-holes.env*  
  - *Note: Default for import_config changed to false*  
- **03-05-2025** → 0.9.5 Modify Import Settings via Command Line  

## Prerequisites

### Software Dependencies
- **Pi-hole 6** (required for API compatibility)
- **jq** – for JSON parsing
- **curl** – for API requests
- **Bash 4 (or later)** – to properly handle arrays

### Permissions
- The script may require `sudo` privileges to access certain files or directories.

## Installation

1. **Download the Script**  
   Place `sync-holes.sh` and the `.env` configuration file in your desired directory.

2. **Make the Script Executable**  
   ```bash
   chmod +x sync-holes.sh

3. **Edit the .env File**
    Configure the environment variables in sync-holes.env (see below for details).

## Configuration: `.env` File

The `.env` file contains the following configuration variables. Update these to match your Pi-hole instances.

### Primary Pi-hole (Source)
- `primary_name`: Friendly name for the primary Pi-hole.
- `primary_url`: URL or IP address of the primary Pi-hole.
- `primary_pass`: Password for the primary Pi-hole (if any).

### Secondary Pi-holes (Targets)

- `secondary_names`: An array of friendly names for the secondary Pi-holes.
- `secondary_urls`: An array of URLs or IP addresses for the secondary instances.
- `secondary_passes`: An array of passwords for the secondary instances (if any).

### Optional Settings

- `log_file`: Log file location (default: /var/log/sync-holes.log).
- `log_size_limit`: Maximum log file size in MB (default: 1).
- `max_old_logs`: Number of old logs to retain (default: 1).
- `temp_files_path`: Directory for temporary files (default: /tmp).
- `verify_ssl`: Enable SSL verification (1 = true, 0 = false; default: 0).
- `mask_sensitive`: Mask sensitive data in logs (1 = true, 0 = false; default: 1).

### Import Settings
These variables control which settings are imported by default. Set each to true or false as needed:

- `import_config`, `import_dhcp_leases`, `import_gravity_group`, `import_gravity_adlist`, `import_gravity_adlist_by_group`, `import_gravity_domainlist`, `import_gravity_domainlist_by_group, import_gravity_client`, `import_gravity_client_by_group`
- Note: 'import_config' is set to false by default in the `.env` , as synchronizing configuration setting mays cause issues with some installations. 

## Usage

### Basic Syntax

    ./sync-holes.sh [options]

### Options

- `-v`: Enable verbose mode.
- `-h`: Display this help message.
- `-u`: Unmask sensitive data in logs.
- `-I`: inline_json : Override import settings with an inline JSON string.
- `-F`: json_file : Override import settings by specifying a JSON file.

### Examples

1. **Run the script normally**
   ```bash
   ./sync-holes.sh

3. **Run with verbose output**
   ```bash
    ./sync-holes.sh -v

4. **Run without masking sensitive data**
   ```bash
    ./sync-holes.sh -u

5. **Run with import settings overridden inline via JSON**
   ```bash
   ./sync-holes.sh -I '{"config": false,"dhcp_leases": false,"gravity": {"group": true,"adlist": false,"adlist_by_group": true,"domainlist": true,"domainlist_by_group": true,"client": true,"client_by_group": false}}'

7. **Run with import settings overridden by a JSON file**
   ```bash
    ./sync-holes.sh -F /path/to/import_settings.json

##### Note:
- Any import settings keys omitted from the override JSON will assume their default values from the .env file.
- For example, if you override only "dhcp_leases": false in your JSON, only that key will change while all others remain unchanged.

### Reminder:
- Depending on your system configuration, you may need to run the script with sudo to access protected directories. For example:
   ```bash
    sudo ./sync-holes.sh           # Run the script normally using sudo
    sudo ./sync-holes.sh -v        # Run with verbose output using sudo

## Logging

Logs are written to the file specified in log_file with:

- Maximum size: 1 MB (default)
- Rotation: 1 old log retained

These defaults may be modified in the .env file

## Error Handling

Errors during execution are logged and displayed. Check the log file for detailed diagnostics.

## Troubleshooting

- Ensure `jq` and `curl` are installed.
- Verify that the `.env` file is correctly configured.
- Check permissions on directories for logs and temporary files.

## License

This project is licensed under the MIT License. See the script header for details.

## Disclaimer

**Pi-hole®**  and the Pi-hole logo are registered trademarks of **Pi-hole LLC**.

This project is independently-maintained. The maintainer is not affiliated with the [Official Pi-hole Project](https://github.com/pi-hole) in any way.
