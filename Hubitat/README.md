# Pi-hole 6 Blocking Control - Hubitat Driver

## Overview

The **Pi-hole6 Blocking Control** driver allows you to control DNS blocking on one or two Pi-hole v6.x instances from your Hubitat Elevation hub. It includes support for voice assistants, auto-refresh of blocking states, and session management via the Pi-hole REST API. 

### Key Features

- **Enable/Disable DNS Blocking:** Manage DNS blocking for one or two Pi-hole instances.
- **Voice Assistant Compatibility:** Alternate `on`/`off` commands for integration with voice assistants.
- **Auto-Refresh:** Periodically refresh blocking status to reflect external changes.
- **Session Management:** Tracks session expiration, reuses active sessions, and authenticates as needed.
- **SSL Handling:** Option to ignore SSL issues (e.g., self-signed certificates).
- **Customizable Options:** Set default blocking duration, refresh intervals, and logging preferences.

## Installation

1. Open your Hubitat Elevation hub's web interface.
2. Navigate to **Drivers Code** > **New Driver**.
3. Copy and paste the driver code from the repository.
4. Click **Save**.

## Configuration

After installation, create a new virtual device using this driver. Configure the following preferences:

### Required Fields
- **Pi-hole 1 URL:** URL of the first Pi-hole instance (e.g., `https://192.168.1.11:443`).

### Optional Fields
- **Pi-hole 1 Password:** Password for the first Pi-hole (leave blank if not required).
- **Pi-hole 2 URL:** URL of the second Pi-hole instance (e.g., `https://192.168.1.12:443`).
- **Pi-hole 2 Password:** Password for the second Pi-hole (leave blank if not required).
- **Default Blocking Time:** Default duration for disabling blocking (in seconds, default is 300).
- **Auto-Refresh Interval:** Period (in minutes) to refresh Pi-hole blocking states (0 to disable).
- **Ignore SSL Issues:** Option to bypass SSL validation for HTTP requests.
- **Enable Info Logging:** Enable informational logs.
- **Enable Debug Logging:** Enable detailed debug logs (automatically disables after 30 minutes).

## Commands and Attributes

### Commands

- **`enable`:** Enables DNS blocking.
- **`disable (timer)`:** Disables DNS blocking for a specified duration (in seconds).
- **`on`:** Enables DNS blocking (equivalent to `enable`).
- **`off`:** Disables DNS blocking (equivalent to `disable,`but uses the default blocking time.
- **`refresh`:** Refreshes the blocking status for all configured Pi-hole instances.

### Attributes
- **`pi1BlockingStatus`:** Current blocking status of Pi-hole 1 (`enabled`, `disabled`, or `error`).
- **`pi2BlockingStatus`:** Current blocking status of Pi-hole 2 (`enabled`, `disabled`, or `error`).

## Logging

- **Info Logging:** Provides general information about the driver's operation. Can be disabled.
- **Debug Logging:** Offers detailed logs for troubleshooting. Auto-disables after 30 minutes.

## Notes

- Ensure Pi-hole URLs use HTTPS and are valid.
- SSL issues (e.g., self-signed certificates) can be ignored using the relevant setting.
- Default blocking time and refresh interval can be customized in the preferences.

## License

This driver is licensed under the [Apache License 2.0](http://www.apache.org/licenses/LICENSE-2.0).

## Changelog

### Version 0.9.0 (Beta)
- 01-05-2025 - Initial beta release.

## Disclaimer

**Pi-hole®**  and the Pi-hole logo are registered trademarks of **Pi-hole LLC**.

**This project is independently-maintained. The maintainer is not affiliated with the [Official Pi-hole Project](https://github.com/pi-hole) or Hubitat in any way.**
