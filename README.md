<h2 align="center">Easily synchronize data and settings from a primary Pi-hole® to multiple secondary Pi-hole® instances via the Pi-hole v6 REST API.</h2>

<div align="center">
  <img src="https://github.com/TheMegamind/sync-holes/blob/main/assets/synchronize.png" alt="readme header image" width="300">
</div>
  
<h6 align="center"><br>Pi-hole® and the Pi-hole logo are registered trademarks of Pi-hole LLC.<br><br>This project is independently-maintained. The maintainer is not affiliated with the Official Pi-hole® Project at https://github.com/pi-hole in any way.</h6>

---

[![Pi-hole v6](https://img.shields.io/badge/Pi--hole®-v6%20Required-brightgreen)](https://github.com/pi-hole/pi-hole)
[![GitHub release (latest SemVer)](https://img.shields.io/github/v/release/TheMegamind/sync-holes)](https://github.com/TheMegamind/sync-holes/releases) 
[![GitHub last commit](https://img.shields.io/github/last-commit/TheMegamind/sync-holes)](https://github.com/TheMegamind/sync-holes/commits/)
[![!#/bin/bash](https://img.shields.io/badge/-%23!%2Fbin%2Fbash-ebebeb.svg?style=flat&logo=gnu%20bash)](https://www.gnu.org/software/bash/) 
[![Debian](https://img.shields.io/badge/Debian-A81D33?logo=debian&logoColor=fff)](#)
[![Fedora](https://img.shields.io/badge/Fedora-51A2DA?logo=fedora&logoColor=fff)](#)
[![macOS](https://img.shields.io/badge/macOS-000000?logo=apple&logoColor=F0F0F0)](#)

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
  - [Primary Pi-hole (Source)](#primary-pi-hole-source)
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
- Easy, automated script-based installation for Linux and macOS
- Additional environment-based configuration via a `.env` file
- Intelligent session management (re-authenticates only when needed)
- Configurable SSL support for self‑signed certificates
- Command‑line options to control console output and sensitive data masking
- Command-line options to override default import configuration settings
- Detailed logging with configurable size, rotation, and optional data masking

---

## Prerequisites

### Software Dependencies
- **Pi-hole® v6** (required for API compatibility)
- **jq** – for JSON parsing
- **curl** – for API requests
- **Bash 4 (or later)** – to properly handle arrays

**Note**: The installer automatically checks for and will attempt to install any missing dependencies.

---

## Installation

### Use the Automated Installer (Recommended!)
- **Clone or Download** the Repository
   ```bash
   git clone https://github.com/TheMegamind/sync-holes.git
   cd sync-holes
   ```

- **Run the Installer** 
   ```bash
   ./sync-install.sh
   ```
  - If you see a “Permission denied” error, run `bash sync-install.sh`.

Running `./sync-install.sh` performs a standard installation, which:
  - Checks for required dependencies (and attempts to install any that are missing)
  - Verifies the user is running Pi-hole v6
  - Configures **and** validates all Pi-hole instances
  - Offers retries for invalid user entries
  - Installs `sync-holes.sh` in `/usr/local/bin`
  - Copies the `.env` file to `/usr/local/etc`
  - Creates a `/usr/local/bin/sync-holes` symlink
  - Offers to set up a cron job for automatic synchronization

**Note**: Pi-hole addresses **must** be entered in the form of `protocol://ipAddress:port`, e.g., `https://198.168.15:443`.
  - For **https**, use `https://ip_address:443` 
  - For **http** try `http://ip_address:80` or, if that doesn't work, `http://ip_address:8080`.
  - _Note: If `webserver.port` has been modified from the defaults in the expert settings, use the values entered there._

### Optional Advanced Installation
- If you want to change install directories or skip the auto-symlink, run:
   ```bash
   ./sync-install.sh --advanced
   ```
- Advanced mode prompts you for:
    - Custom script directory (instead of `/usr/local/bin`)
    - Custom `.env` directory (instead of `/usr/local/etc`)
    - Whether to create a symlink
    - Cron job setup

**Note**: If you pick a non-default `.env` directory, the script automatically creates a symlink at `/usr/local/etc/sync-holes.env` so that the main `sync-holes.sh` script can still find it.

### Simulation Mode
- If you want to see what would happen without making changes, use:
   ```bash
   ./sync-install.sh --simulate
   ```
- or combine with `--advanced` for a full preview:
   ```bash
   ./sync-install.sh --simulate --advanced
   ```

### After Installation
- **Run** the script at any time:
   ```bash
   sync-holes
   ```
- or, if you didn’t create a symlink in advanced mode:
   ```bash
   /usr/local/bin/sync-holes.sh
   ```
- The installer **backs up** any existing `.env` file before copying a new one.  
- If you wish to edit it further:
   ```bash
   sudo nano /usr/local/etc/sync-holes.env
   ```
  (Or whichever directory you chose in advanced mode.)

- If you **did not** configure a cron job during install, you can re-run `sync-install.sh` or manually set one up.  
- **Re-running the Installer**: If you run `sync-install.sh` again and choose not to reconfigure your Pi-hole instances, your existing `.env` data remains intact.

### Manual Installation (Advanced Users Only)
- Download `sync-holes.sh` and `sync-holes.env`:
   ```bash
   git clone https://github.com/TheMegamind/sync-holes.git
   cd sync-holes
   cp sync-holes.sh /usr/local/bin/
   cp sync-holes.env /usr/local/etc/
   chmod +x /usr/local/bin/sync-holes.sh
   ```
- Edit the `.env` File and configure the environment variables (primary/secondary Pi-hole details, etc.) in `/usr/local/etc/sync-holes.env`.
- (Optional) Create a Symlink:
   ```bash
   ln -s /usr/local/bin/sync-holes.sh /usr/local/bin/sync-holes
   ```
- **Run** the script:
   ```bash
   /usr/local/bin/sync-holes.sh
   ```
  or, if you created the symlink:
   ```bash
   sync-holes
   ```
Any of these methods achieve the same result. The automated script is recommended for ease of setup, automatic backups, Pi-hole version checks, and optional cron configuration.

---

## Configuration

- The **installation script** can help configure the `.env` file, but you can also edit it manually afterward.  
- By default, `.env` is at `/usr/local/etc/sync-holes.env` (or symlinked there).  
- The **secondary arrays** get inserted below the comment line:  
  `** DO NOT REMOVE OR MODIFY THIS LINE — INSTALL SCRIPT INSERTS DATA BELOW **`  
  Do **not** remove that line if you want to re-run the installer to manage secondaries.

### Primary Pi-hole (Source)
- `primary_name`: Friendly name for the primary Pi-hole.
- `primary_url`: URL or IP address of the primary Pi-hole.
- `primary_pass`: Password for the primary Pi-hole (if any).

### Secondary Pi-holes (Targets)
- `secondary_names`: An array of friendly names for the secondary Pi-holes.
- `secondary_urls`: An array of URLs or IP addresses for the secondary Pi-holes.
- `secondary_passes`: An array of passwords for the secondary Pi-holes (if any).

### Optional Settings
- `log_file`: Log file location (default: `/var/log/sync-holes.log`)
- `log_size_limit`: Maximum log file size in MB (default: 1)
- `max_old_logs`: Number of old logs to retain (default: 1)
- `temp_files_path`: Directory for temporary files (default: `/tmp`)
- `verify_ssl`: Enable SSL verification (1 = true, 0 = false; default: 0)
- `mask_sensitive`: Mask sensitive data in logs (1 = true, 0 = false; default: 1)

### Import Settings
Variables that control which components are imported. Set each to `true` or `false`:
- `import_config`, `import_dhcp_leases`, `import_gravity_group`, `import_gravity_adlist`, `import_gravity_adlist_by_group`, `import_gravity_domainlist`, `import_gravity_domainlist_by_group`, `import_gravity_client`, `import_gravity_client_by_group`

**Note**: By default, `import_config=false` and `import_dhcp_leases=false`, so only gravity data is synchronized unless you explicitly enable them.

---

## Usage

### Basic Syntax
```bash
./sync-holes.sh [options]
```

### Options
- `-v`: Enable verbose mode
- `-h`: Display help
- `-u`: Unmask sensitive data in logs
- `-I inline_json`: Override import settings with an inline JSON string
- `-F json_file`: Override import settings by specifying a JSON file

### Examples
1. **Run normally**  
   ```bash
   ./sync-holes.sh
   ```
2. **Verbose output**  
   ```bash
   ./sync-holes.sh -v
   ```
3. **Unmask sensitive data**  
   ```bash
   ./sync-holes.sh -u
   ```
4. **Override import settings inline**  
   ```bash
   ./sync-holes.sh -I '{"dhcp_leases":false,"gravity":{"group":true,"adlist":false}}'
   ```
5. **Override import settings from a JSON file**  
   ```bash
   ./sync-holes.sh -F /path/to/import_settings.json
   ```

**Reminder**: Depending on your system configuration, you may need `sudo` to access protected directories:
```bash
sudo ./sync-holes.sh
sudo ./sync-holes.sh -v
```

**Note**: If you only override one key (e.g., `"dhcp_leases": false`), all other keys retain their default `.env` values.

---

## Logging
- By default, logs go to `/var/log/sync-holes.log`
- Maximum size is 1 MB, and only 1 old log is kept
- You can adjust these settings in `.env`

---

## Troubleshooting
- The most common errors are the result and configuration, in particular the use of an invalid combination of combination(s) of `protocol://ipAddress:port`. Pi-hole addresses **must be entered** in the form of `protocol://ipAddress:port`, e.g., https://198.168.15:443.
  - For **https**, use `https://ip_address:443` 
  - For **http** try `http://ip_address:80` or, if that doesn't work, `http://ip_address:8080`.
- If an error occurs during installation, review the install log in the directory where `sync-install.sh` is located.
- If an error occurs while running `sync-holes.sh`, the script prints a message to the console and logs details to `/var/log/sync-holes.log` (or your chosen log location).  
  - Run `sync-holes.sh -v` to display the verbose logs on the terminal. Run `sync-holes.sh -v -u` to unmask sensitive data.   
- **If you still have issues**, please open a GitHub issue with a **complete, verbose log** of the run. Also include your OS (Debian, Fedora or macOS) and the specific hardware the script is runnning on.   

---

## License

<sub>This project is licensed under the MIT License. See the script header for details.</sub>

---

<sub>© 2025 by Megamind</sub>
