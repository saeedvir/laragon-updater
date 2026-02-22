## What Is The Laragon?
Laragon is a game-changer for local web development. With its easy setup, fast performance, and extensive features, it's a real time-saver for developers.

# Laragon Updater

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)](https://github.com/PowerShell/PowerShell)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![GitHub](https://img.shields.io/badge/GitHub-saeedvir-lightgrey.svg)](https://github.com/saeedvir)

Automatically update development tools in your **Laragon** installation to their latest versions. This script fetches the latest versions of popular development tools and updates them directly in your Laragon `bin` directory.

## Features

- 🚀 **Automatic Updates** - Fetches latest versions from official sources
- 🔍 **Version Detection** - Compares current vs. latest versions
- ⚡ **Smart Downloads** - Skips tools that are already up-to-date
- 🛑 **Process Management** - Auto-stops running services before updating
- ✅ **VC++ Redistributable Check** - Ensures required runtime is installed
- 📋 **Dry Run Mode** - Preview what would be updated without downloading
- 🎯 **Force Mode** - Force re-download even if version is current
- 🔇 **Silent Mode** - Skip confirmation prompts with `-NoConfirm`


## Virus Total Scan Result
> [!NOTE]  
> ```https://www.virustotal.com/gui/file/68792387b77d05e26732b239f71c9da658741c1cc87b5c7760746f6669947347/detection```

## Supported Tools

| Tool | Type | Source |
|------|------|--------|
| Apache | Web Server | [ApacheLounge](https://www.apachelounge.com/) |
| Nginx | Web Server | [nginx.org](https://nginx.org/) |
| PHP | Language | [windows.php.net](https://windows.php.net/download/) |
| MySQL | Database | [mysql.com](https://dev.mysql.com/downloads/) |
| Node.js | Runtime | [nodejs.org](https://nodejs.org/) |
| Composer | Dependency Manager | [getcomposer.org](https://getcomposer.org/) |
| HeidiSQL | Database Client | [GitHub](https://github.com/HeidiSQL/HeidiSQL) |
| Notepad++ | Text Editor | [GitHub](https://github.com/notepad-plus-plus/notepad-plus-plus) |
| Python | Language | [python.org](https://www.python.org/) |
| DB Browser for SQLite | Database Tool | [GitHub](https://github.com/sqlitebrowser/sqlitebrowser) |

## Requirements

- **Windows** 10/11 (64-bit recommended)
- **PowerShell** 5.1 or higher
- **Laragon** installed (Full or Premium edition)
- **Administrator** privileges (recommended)
- **VC++ Redistributable 2015-2022** (script will offer to install if missing)

## Installation

> [!NOTE]  
> This Is Beta Version !


1. Clone or download this repository:
   ```bash
   git clone https://github.com/saeedvir/Laragon-updater.git
   ```

2. Copy the scripts to your Laragon `bin` directory:
   ```
   C:\laragon\bin\
   ```

3. (Optional) Add to Windows Context Menu by adding this registry entry:
   ```reg
   Windows Registry Editor Version 5.00

   [HKEY_CLASSES_ROOT\Directory\shell\LaragonUpdater]
   @="Update Laragon Tools"
   "Icon"="powershell.exe"

   [HKEY_CLASSES_ROOT\Directory\shell\LaragonUpdater\command]
   @="powershell.exe -ExecutionPolicy Bypass -File \"C:\\laragon\\bin\\laragon-updater.ps1\""
   ```

## Usage

### Quick Start (Double-Click)

Simply double-click `laragon-updater.bat` to run with default settings.

### PowerShell Commands

Open PowerShell as Administrator and navigate to `C:\laragon\bin`, then run:

```powershell
# Normal update (with confirmations)
.\laragon-updater.ps1

# Dry run - see what would be updated without downloading
.\laragon-updater.ps1 -DryRun

# Force update all tools (even if up-to-date)
.\laragon-updater.ps1 -Force

# Auto-close running processes without prompting
.\laragon-updater.ps1 -NoConfirm

# Skip VC++ Redistributable check
.\laragon-updater.ps1 -SkipVCRedist

# Combine multiple options
.\laragon-updater.ps1 -Force -NoConfirm -SkipVCRedist
```

### Parameters

| Parameter | Description |
|-----------|-------------|
| `-DryRun` | Show what would be updated without actually downloading |
| `-Force` | Force update even if version is current |
| `-NoConfirm` | Skip confirmation prompts for closing running processes |
| `-SkipVCRedist` | Skip VC++ Redistributable check and download |

## How It Works

1. **VC++ Check** - Verifies Microsoft Visual C++ 2015-2022 Redistributable is installed
2. **Laragon Status** - Checks if Laragon/MySQL/Apache are running
3. **Process Stop** - Offers to stop running services (or auto-stops with `-NoConfirm`)
4. **Version Check** - Compares installed version with latest available
5. **Download** - Fetches latest version from official sources
6. **Extract** - Extracts/installs to the appropriate Laragon `bin` subdirectory
7. **Alert** - Warns if any services are still running after update

## Folder Structure

```
C:\laragon\bin\
├── laragon-updater.bat      # Batch launcher (double-click to run)
├── laragon-updater.ps1      # PowerShell update script
├── apache\                  # Apache installations
├── nginx\                   # Nginx installations
├── php\                     # PHP installations
├── mysql\                   # MySQL installations
├── nodejs\                  # Node.js installations
├── composer\                # Composer PHAR
├── heidisql\                # HeidiSQL
├── notepad++\               # Notepad++
├── python\                  # Python
└── SQLiteDatabaseBrowserPortable\  # DB Browser for SQLite
```

## Troubleshooting

### "Access Denied" Errors
Run the script as Administrator (right-click → Run as Administrator).

### "VC++ Redistributable is NOT installed"
The script will offer to download and install it. Accept or install manually from:
[Microsoft Visual C++ Redistributable](https://aka.ms/vs/17/release/vc_redist.x64.exe)

### Download Failures
- Check your internet connection
- Some sources may be temporarily unavailable
- Try running again later or download manually

### Extraction Failures
- Ensure no processes are using the tool files
- Close Laragon completely before updating
- Run with `-Force -NoConfirm` to override

### Version Detection Issues
Some tools may not detect versions correctly. Use `-Force` to re-download.

## Notes

- **Apache** updates use direct download links from ApacheLounge (VS18 builds)
- **PHP** downloads the Non-Thread-Safe (NTS) x64 version
- **MySQL** uses archived version 9.5.0 (latest stable)
- **Python** downloads the installer (manual installation may be required)
- **Composer** downloads the PHAR file directly
- Tools with **GitHub** source use the GitHub API for version detection

## Security

- All downloads are from official sources
- No data is collected or transmitted
- Script runs locally on your machine
- Review the script before running if concerned

## Contributing

Feel free to submit issues or pull requests for:
- Adding new tools
- Updating download URLs
- Improving version detection
- Bug fixes and optimizations

## License

This project is licensed under the [MIT License](LICENSE).

## Author

- **GitHub:** [@saeedvir](https://github.com/saeedvir)
- **Email:** saeed.es91@gmail.com

## Disclaimer

This script is provided as-is. Always backup your Laragon installation before running updates. The author is not responsible for any data loss or system issues that may occur.

---

**Happy Coding!** 🚀
