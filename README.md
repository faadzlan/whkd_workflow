# Windows Hotkey Daemon (whkd) Setup

Automated work environment setup for Windows 11 with keyboard-driven window management.

## Overview

This repository contains PowerShell scripts and configuration for:
- **Virtual desktop management** - Automated window placement across desktops
- **Project workflow** - One-command setup for daily work environment
- **Window tiling** - Automatic resizing and positioning of applications
- **WSL integration** - Seamless Windows/Linux workflow

## Quick Start

### Prerequisites
- Windows 11
- PowerShell 5.1 or 7+
- [VirtualDesktop PowerShell module](https://github.com/MScholtes/PSVirtualDesktop)
- Windows Terminal (optional but recommended)
- WSL with Emacs (optional)

### Installation

1. Clone this repository:
```powershell
git clone https://github.com/<your-username>/whkd-setup.git
cd whkd-setup
```

2. Load the workflow profile in PowerShell:
```powershell
. .\tools\workflows\Load-WorkflowProfile.ps1
```

Or add to your PowerShell profile for auto-load:
```powershell
notepad $PROFILE
# Add this line:
. C:\Users\<USERNAME>\Documents\whkd_setup\tools\workflows\Load-WorkflowProfile.ps1
```

3. Configure your projects in `tools/workflows/projects.json`:
```json
{
  "projects": {
    "myproject": {
      "path": "~\\Documents\\MyProject",
      "description": "My awesome project"
    }
  }
}
```

> **Note:** Use `~` to refer to your home directory. It will be resolved at runtime.

## Usage

### Start Work Environment
```powershell
work                    # Open default project
work "C:\Some\Path"     # Open specific path
```

This will:
- Switch to Desktop 2
- Open two File Explorers (stacked left)
- Open Windows Terminal (right half)
- Switch to Desktop 3
- Open Emacs at project root
- Return to Desktop 2

### Project Navigation
```powershell
proj myproject     # Jump to project
proj myproject -e  # Open in Explorer
proj myproject -t  # Open in Terminal
proj myproject -m  # Open in Emacs (WSL)
```

### Other Commands
```powershell
bye         # Close all windows
clean-dl    # Archive old Downloads
syshealth   # System health dashboard
bt          # Bluetooth settings
vol         # Volume settings
wifi        # WiFi settings
```

## Project Structure

```
whkd_setup/
├── tools/
│   ├── workflows/          # PowerShell workflow scripts
│   │   ├── Load-WorkflowProfile.ps1
│   │   ├── Start-WorkEnvironment.ps1
│   │   ├── Go-ToProject.ps1
│   │   └── projects.json   # Your project paths
│   └── shell/              # Shell configuration
│       ├── zshrc
│       └── install_zsh_modern.sh
├── documentation/          # Guides and references
└── README.md
```

## How It Works

### Window Positioning
The `Start-WorkEnvironment.ps1` script uses Windows APIs to:
1. Track existing windows before opening new ones
2. Identify newly opened windows by handle comparison
3. Resize and position them using `MoveWindow` API

### Path Resolution
- `~` in `projects.json` resolves to `$env:USERPROFILE` at runtime
- Windows paths are automatically converted to WSL paths (`C:\` → `/mnt/c/`)

## Customization

### Change Default Project
Edit `tools/workflows/projects.json`:
```json
{
  "projects": {
    "default": {
      "path": "~\\Documents\\MyDefaultProject"
    }
  }
}
```

### Adjust Window Layout
Edit `Calculate-Layout` function in `Start-WorkEnvironment.ps1`:
```powershell
function Calculate-Layout {
    param($Screen)
    return @{
        Terminal = @{ X = ...; Y = ...; Width = ...; Height = ... }
        ExplorerTop = @{ ... }
        ExplorerBottom = @{ ... }
    }
}
```

## Troubleshooting

### "Desktop X not found"
Create virtual desktops first using `Win + Ctrl + D` or your whkd hotkeys.

### Windows not resizing
Ensure you have the VirtualDesktop module installed:
```powershell
Install-Module -Name VirtualDesktop -Scope CurrentUser
```

### Emacs not opening
Verify WSL is installed and Emacs is available:
```powershell
wsl which emacs
```

## License

MIT License - Feel free to use and modify for your own workflow.

## Acknowledgments

- [VirtualDesktop PowerShell Module](https://github.com/MScholtes/PSVirtualDesktop) by MScholtes
- [whkd](https://github.com/LGUG2Z/whkd) by LGUG2Z
