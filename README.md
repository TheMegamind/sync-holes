# sync-holes.sh README

## Overview

`sync-holes.sh` synchronizes the Teleporter settings from a primary Pi-hole to multiple secondary Pi-hole instances via the Pi-hole REST API. 

**Features:**
- Easy, automated installation
- Environment-based configuration via a `.env` file.
- Intelligent session management (re-authenticates only when needed).
- Configurable SSL support for self‑signed certificates.
- Command‑line options to control console output and sensitive data masking.
- Command-line options to override default import configuration settings
- Detailed logging with configurable size, rotation, and optional data masking.
- Optional Docker Installation (*Pending*)

**History:**
- **01-05-2025** → Initial Beta Release  
- **01-19-2025** → 0.9.1 Fix Log Rotation  
- **02-22-2025** → 0.9.2 Fix Import Options Handling  
- **03-03-2025** → 0.9.3 Synchronize > 2 Pi-holes  
  - *Requires updated sync-holes.env*  
  - *Note: Default for import_config changed to false*  
- **03-05-2025** → 0.9.5 Added Command-Line Override for Import Settings 
- **03-06-2025** → Initial Release of Automated Installer   

## Prerequisites

### Software Dependencies
- **Pi-hole 6** (required for API compatibility)
- **jq** – for JSON parsing
- **curl** – for API requests
- **Bash 4 (or later)** – to properly handle arrays

## Installation

### Recommended: Use the Automated Installer
- Clone or Download the Repository
   ```bash
   git clone https://github.com/TheMegamind/sync-holes.git
   cd sync-holes

- Make the Installer Executable
   ```bash
   chmod +x sync-install.sh

- Run the Installer 
   ```bash
   ./sync-install.sh

This performs a standard installation, automatically placing sync-holes.sh in `/usr/local/bin`, copying the .env file to `/usr/local/etc`, and creating a `/usr/local/bin/sync-holes` symlink.

The script checks for required dependencies, verifies Pi-hole v6, and offers to set up a cron job for automatic synchronization.

### Optional Advanced Installation
- If you want to change install directories or skip the auto-symlink, run:
   ```bash
   ./sync-install.sh --advanced
   
- Advanced mode prompts you for:
    - Custom script directory (instead of `/usr/local/bin`).
    - Custom .env directory (instead of `/usr/local/etc`).
    - Whether to create a symlink or not.
    - Cron job setup.

### Simulation Mode
- If you want to see what would happen without making changes, use:
   ```bash
   ./sync-install.sh --simulate

- or combine with --advanced for a full preview:
   ```bash
   ./sync-install.sh --simulate --advanced

### After Installation

- You can run the script at any time via:
   ```bash
   sync-holes

- or, if you didn’t create a symlink in advanced mode:
   ```bash
   /usr/local/bin/sync-holes.sh

- The installer backs up any existing .env file before copying a new one. If you wish to edit it further, run:
   ```bash
   sudo nano /usr/local/etc/sync-holes.env

(Or whichever directory you chose in advanced mode.)

- If you did not configure a cron job during install, you can re-run sync-install.sh or manually set one up

### Manual Installation (Advanced Users Only)
- Download sync-holes.sh and sync-holes.env
   ```bash
   git clone https://github.com/TheMegamind/sync-holes.git
   cd sync-holes
   cp sync-holes.sh /usr/local/bin/
   cp sync-holes.env /usr/local/etc/
   chmod +x /usr/local/bin/sync-holes.sh

- Edit the .env File and configure the environment variables (primary/secondary Pi-hole details, etc.) in `/usr/local/etc/sync-holes.env`.
- *Note: The user should also handle log directory permissions if they want logs in /var/log/*

- (Optional) Create a Symlink
   ```bash
   ln -s /usr/local/bin/sync-holes.sh /usr/local/bin/sync-holes

- Run the Script
   ```bash
   /usr/local/bin/sync-holes.sh

- or, if you created the symlink:
   ```bash
   sync-holes

Any of these methods will achieve the same result. The automated script is recommended for ease of setup, automatic backups, Pi-hole version checks, and optional cron configuration.

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

`import_config`, `import_dhcp_leases`, `import_gravity_group`, `import_gravity_adlist`, `import_gravity_adlist_by_group`, `import_gravity_domainlist`, `import_gravity_domainlist_by_group`, `import_gravity_client`, `import_gravity_client_by_group`

**Note**: By default, 'import_config' is initially set to false in `sync-holes.env`. Synchronizing configuration setting may cause issues with some installations (for example, if one Pi-hole uses Ethernet and the other Wi-Fi).

## Usage

### Basic Syntax
   `./sync-holes.sh [options]`

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
### Reminder:
- Depending on your system configuration, you may need to run the script with sudo to access protected directories. For example:
   ```bash
    sudo ./sync-holes.sh           # Run the script normally using sudo
    sudo ./sync-holes.sh -v        # Run with verbose output using sudo
   
##### Note:
- Any import settings keys omitted from the override JSON will assume their default values from the .env file.
- For example, if you override only `"dhcp_leases": false` in your JSON, only that key will change while all others remain unchanged.

## Logging

Logs are written to the file specified in log_file with:

- Maximum size: 1 MB (default)
- Rotation: 1 old log retained

These defaults may be modified in the .env file

## Troubleshooting

- Most errors that have been reported to date have been the result of syntax or other errors in the user's `sync-holes.env`. Please review entries carefully. 
- Errors during execution are logged and displayed, sometimes with a suggested fix. You can review any errors by:
  - Checking the log file, or 
  - Running `sync-holes -v` to output the log to the screen.
  - Running `sync-holes -v -u` will log to the screen and unmask any sensitive data
- Any curl errors are printed to the screen and included in the log. The `curl_error.log` that is deleted during cleanup is a placeholder and *does not contain any information that hasn't already been logged*.
 
## License

This project is licensed under the MIT License. See the script header for details.

## Disclaimer

**Pi-hole®**  and the Pi-hole logo are registered trademarks of **Pi-hole LLC**.

This project is independently-maintained. The maintainer is not affiliated with the [Official Pi-hole Project](https://github.com/pi-hole) in any way.
