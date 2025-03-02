# `sync-holes.sh` README

## Overview

`sync-holes.sh` is designed to synchronize the configuration settings of two Pi-hole 6 instances using the Pi-hole REST API. It supports seamless transfer of settings from a primary instance (`pi1`) to a secondary instance (`pi2`).

**Features**:
- Synchronization of Pi-hole settings (using API /teleporter method).
- Environment-based configuration, including optional parameters.
- Session management re-authenticates only when needed, so as to not create concurrent sessions.
- Configurable SSL support to simplify use with self-signed certificates
- Command-line options to control console output
- Detailed logging with configurable size and rotation, and optional masking of sensitive data
- Docker compatible (in pre-Beta testing)

## Prerequisites

### Software Dependencies
- **Pi-hole 6** (required for API compatibility).
- **jq**: Used for JSON parsing.
- **curl**: Used for API requests.

### Permissions
- Depending on installation and configuration, the script may require `sudo` privileges to access certain files or directories.

## Installation

1. **Download the Script**  
   Place `sync-holes.sh` and the `.env` configuration file in the desired directory.

2. **Make the Script Executable**  
   ```bash
   chmod +x sync-holes.sh

3. **Edit the `.env` File**  
   Configure the environment variables in `sync-holes.env` (see below for details).

## Configuration: `.env` File

The `.env` file contains the following configuration variables. Update these to match your Pi-hole instances.

### Pi-hole 1 (Primary Instance)
- `pi1_name`: Friendly name for Pi-hole 1.
- `pi1_url`: URL or IP address (e.g., `https://192.168.1.10:443`).
- `pi1_pass`: Password for Pi-hole 1 (leave blank if none).

### Pi-hole 2 (Secondary Instance)
- `pi2_name`: Friendly name for Pi-hole 2.
- `pi2_url`: URL or IP address (e.g., `https://192.168.1.12:443`).
- `pi2_pass`: Password for Pi-hole 2 (leave blank if none).

### Optional Settings
- `log_file`: Log file location (default: `/var/log/sync-holes.log`).
- `log_size_limit`: Maximum log file size in MB (default: `1` MB).
- `max_old_logs`: Number of old logs to retain (default: `1`).
- `temp_files_path`: Directory for temporary files (default: `/tmp`).
- `verify_ssl`: Enable SSL verification (`1` = true, `0` = false, default: `0`).
- `mask_sensitive`: Mask sensitive data in logs (`1` = true, `0` = false, default: `1`).

### Import Settings
Use the following variables to enable or disable importing specific settings. Set to `true` or `false`.

- `import_config`, `import_dhcp_leases`, `import_gravity_group`, etc.

## Usage

### Basic Syntax    
       ./sync-holes.sh [options]

   
### Options
- `-v`: Enable verbose mode.
- `-u`: Unmask sensitive data in logs.
- `-h`: Display usage instructions.

### Examples
1. **Basic Execution**
   ```bash
   ./sync-holes.sh

2. **Verbose Output**
   ```bash
   ./sync-holes.sh -v

3. **Unmasked Sensitive Data**
   ```bash
   ./sync-holes.sh -u

4. **Combined Options**
   ```bash
   ./sync-holes.sh -v -u

## Logging

Logs are written to the file specified in `log_file`. Default settings:
- Maximum size: 1 MB.
- Rotation: 1 old log retained.

## Error Handling

Errors during execution are logged and displayed. Check the log file for detailed diagnostics.

## Troubleshooting

- Ensure `jq` and `curl` are installed.
- Verify that the `.env` file is correctly configured.
- Check permissions on directories for logs and temporary files.

## Future Enhancements 
**Currently Planned or Under Consideration**
- Ability to synchronize more than two Pi-holes
- Ability to chose import options via command-line
- Optional Docker Installation 

## License

This project is licensed under the MIT License. See the script header for details.

## Disclaimer

**Pi-hole®**  and the Pi-hole logo are registered trademarks of **Pi-hole LLC**.

This project is independently-maintained. The maintainer is not affiliated with the [Official Pi-hole Project](https://github.com/pi-hole) in any way.







