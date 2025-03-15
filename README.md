<h2 align="center">Synchronize data and settings from a primary Pi-hole® to multiple secondary Pi-hole® instances via the Pi-hole v6 REST API.</h2>

<div align="center">
  <img src="https://github.com/TheMegamind/sync-holes/blob/main/assets/synchronize.png" alt="readme header image" width="300">
</div>
  
<h6 align="center">**NOTE**: This project is independently-maintained. The maintainer is not affiliated with the Official Pi-hole® Project at https://github.com/pi-hole in any way. Pi-hole® and the Pi-hole logo are registered trademarks of Pi-hole LLC. </h6>

---

[![GitHub release (latest SemVer)](https://img.shields.io/github/v/release/TheMegamind/sync-holes)](https://github.com/TheMegamind/sync-holes/releases) 
[![GitHub last commit](https://img.shields.io/github/last-commit/TheMegamind/sync-holes)](https://github.com/TheMegamind/sync-holes/commits/)
[![Pi-hole v6](https://img.shields.io/badge/Pi--hole®-v6%20Required-brightgreen)](https://github.com/pi-hole/pi-hole) 
[![Docker Build](https://img.shields.io/badge/docker-PENDING-lightgrey)](https://hub.docker.com/r/TheMegamind/sync-holes) 
[![!#/bin/bash](https://img.shields.io/badge/-%23!%2Fbin%2Fbash-ebebeb.svg?style=flat&logo=gnu%20bash)](https://www.gnu.org/software/bash/) 

---

## Table of Contents

- [Features](#features)
- [Prerequisites](#prerequisites)
  - [Software Dependencies](#software-dependencies)
- [Installation](#installation)
  - [Use the Automated Installer (Recommended!)](#use-the-automated-installer-recommended)
  - [Optional Advanced Installation](#optional-advanced-installation)
  - [Simulation Mode](#simulation-mode)
  - [After Installation](#after-installation)
  - [Manual Installation (Advanced Users Only)](#manual-installation-advanced-users-only)
- [Configuration](#configuration)
  - [Primary Pi-hole (Source)](#primary-pihole-source)
  - [Secondary Pi-holes (Targets)](#secondary-pi-holes-targets)
  - [Optional Settings](#optional-settings)
  - [Import Settings](#import-settings)
- [Usage](#usage)
  - [Basic Syntax](#basic-syntax)
  - [Options](#options)
  - [Examples](#examples)
- [Logging](#logging)
- [Troubleshooting](#troubleshooting)
- [License](#license)

---

## Features
- Easy, automated script-based installation for macOS and Linux
- **Optional** Docker Installation (*Pending*)
- Environment-based configuration via a `.env` file.
- Intelligent session management (re-authenticates only when needed).
- Configurable SSL support for self‑signed certificates.
- Command‑line options to control console output and sensitive data masking.
- Command-line options to override default import configuration settings
- Detailed logging with configurable size, rotation, and optional data masking.

---

## Prerequisites

### Software Dependencies
- **Pi-hole® v6** (required for API compatibility)
- **jq** – for JSON parsing
- **curl** – for API requests
- **Bash 4 (or later)** – to properly handle arrays

The installer script will check for the required dependencies and prompt the user to install or update them as needed.  

---

## Installation

### Use the Automated Installer (Recommended!)
- Clone or Download the Repository
   ```bash
   git clone https://github.com/TheMegamind/sync-holes.git
   cd sync-holes

- Run the Installer 
   ```bash
   ./sync-install.sh

**Note**: If the above command produces a “Permission denied” error, run `bash sync-install.sh` instead.

Running `./sync-install.sh` performs a standard installation, automatically placing sync-holes.sh in `/usr/local/bin`, copying the .env file to `/usr/local/etc`, and creating a `/usr/local/bin/sync-holes` symlink.

The script checks for required dependencies, verifies Pi-hole v6, and offers to set up a cron job for automatic synchronization. If you need assistance creating a cron schedule string, visit [Crontab.guru](https://crontab.guru).


### Optional Advanced Installation
- If you want to change install directories or skip the auto-symlink, run:
   ```bash
   ./sync-install.sh --advanced
   
- Advanced mode prompts you for:
    - Custom script directory (instead of `/usr/local/bin`).
    - Custom .env directory (instead of `/usr/local/etc`).
    - Whether to create a symlink or not.
    - Cron job setup.

**Note**: If you pick a non-default `.env` directory during advanced installation, the script automatically creates a symlink at `/usr/local/etc/sync-holes.env` so that the main `sync-holes.sh` script can still find it.

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

- If you did not configure a cron job during install, you can re-run sync-install.sh or manually set one up.
- **Re-running the Installer**: If you run sync-install.sh again and choose not to reconfigure your Pi-hole instances, your existing .env data remains intact.

### Manual Installation (Advanced Users Only)
- Download sync-holes.sh and sync-holes.env
   ```bash
   git clone https://github.com/TheMegamind/sync-holes.git
   cd sync-holes
   cp sync-holes.sh /usr/local/bin/
   cp sync-holes.env /usr/local/etc/
   chmod +x /usr/local/bin/sync-holes.sh

- Edit the .env File and configure the environment variables (primary/secondary Pi-hole details, etc.) in `/usr/local/etc/sync-holes.env`.
- Note: The user may need to address log directory permissions if they want logs in /var/log/

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

---

## Configuration

- While the installation script will help you configure the required options, there are additional options (described further below) that you can modify to suit your preferences in the configuration file, `synch-holes.env` By default this file is located at `/usr/local/etc/sync-holes.env`. Simply use your favorite editor to make any modifications, for example:
   ```bash
  sudo nano /usr/local/etc/sync-holes.env

- **Note 1**: If you used the advanced installer option and elected to change the default directory for the configuration file, you may still use the above command, as that directory contains a symlink to the actual file.
- **Note 2**: The installer inserts secondary arrays below the comment line: `** DO NOT REMOVE OR MODIFY THIS LINE — INSTALL SCRIPT INSERTS DATA BELOW **` Do not modify that line if you wish to re-run the installer and manage secondaries.

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

**Note**: By default, 'import_config' and 'import_dhcp_leases are initially set to false in `sync-holes.env`, thereby limiting the synchronization to gravity databases only.

---

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

2. **Run with verbose output**
   ```bash
   ./sync-holes.sh -v

3. **Run without masking sensitive data**
   ```bash
   ./sync-holes.sh -u

4. **Run with import settings overridden inline via JSON**
   ```bash
   ./sync-holes.sh -I '{"config": false,"dhcp_leases": false,"gravity": {"group": true,"adlist": false,"adlist_by_group": true,"domainlist": true,"domainlist_by_group": true,"client": true,"client_by_group": false}}'

6. **Run with import settings overridden by a JSON file**
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

---

## Logging

Logs are written to the file specified in log_file with:

- Maximum size: 1 MB (default)
- Rotation: 1 old log retained

These defaults may be modified in the .env file

## Troubleshooting

- Most errors that were reported in beta were the result of syntax or other errors in the user's `sync-holes.env`. Please review entries carefully. 
- Errors during execution are logged and displayed, sometimes with a suggested fix. You can review any errors by:
  - Checking the log file, or 
  - Running `sync-holes -v` to output the log to the screen.
  - Running `sync-holes -v -u` will log to the screen and unmask any sensitive data
- Any curl errors are printed to the screen and included in the log. The `curl_error.log` that is deleted during cleanup is a placeholder and *does not contain any information that hasn't already been logged*.
- If you encounter an error and need help, please create an issue in the repository and **include a complete verbose log** of the session where the error occurred. 

---
 
#### License

<sub>This project is licensed under the MIT License. </sub>

<sub> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: </sub>

<sub>• The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.</sub>

<sub>• THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.</sub>

<sub>(c) 2025 by Megamind</sub>
