# Windows Hotkey Daemon (whkd) Setup - Agent Guidelines

## Project Goal
Set up whkd (Windows Hotkey Daemon) on Windows 11 for keyboard-driven window management.

## What is whkd?
whkd is a simple Windows hotkey daemon that reads a configuration file and executes commands when hotkeys are pressed. It's commonly used alongside komorebi (a tiling window manager for Windows).

## Project Structure
```
C:\Users\faadz\Documents\whkd_setup/
├── AGENTS.md          # This file - project context for agents
├── FLIGHT_LOG.org     # Running log of lessons learned and best practices
├── whkdrc             # whkd configuration file (to be created)
└── README.md          # Setup instructions (optional)
```

## Key Requirements
- Windows 11 compatibility
- Maintainable configuration
- Clear documentation

## References
- whkd repository: https://github.com/LGUG2Z/whkd
- whkd documentation: https://lgug2z.github.io/whkd/

## Notes for Agents
- This is a Windows-specific setup
- Configuration files typically go in `~/.config/whkd/` or `C:\Users\<username>\.config\whkd\`
- The main config file is named `whkdrc`

## Configuration Files (DRY Principle)

| Config File | Purpose | Location |
|-------------|---------|----------|
| `projects.json` | Project path mappings for `proj` command | `tools/workflows/projects.json` |
| `zshrc` | Modern Zsh configuration (PS7-like experience) | `tools/shell/zshrc` |
| `install_zsh_modern.sh` | One-command Zsh setup script | `tools/shell/install_zsh_modern.sh` |

### Modern Shell Configuration

**Zsh with PowerShell 7-like features:**
- Located in `tools/shell/`
- Features: autosuggestions, syntax highlighting, fzf fuzzy finder, visual tab completion
- See: `documentation/zsh_modern_terminal_guide.md`

**Quick setup on Ubuntu/WSL:**
```bash
cd /mnt/c/Users/<USERNAME>/Documents/whkd_setup/tools/shell
./install_zsh_modern.sh
```

### projects.json
JSON file containing project name → path mappings. Used by:
- `Load-WorkflowProfile.ps1` (the `proj` function in your PowerShell profile)
- `Go-ToProject.ps1` (standalone script)

To add/modify projects, edit `tools/workflows/projects.json` - changes apply everywhere automatically.

#### Project Types

**Windows Projects:**
```json
"whkd": {
  "path": "~\\Documents\\whkd_setup",
  "description": "Windows project"
}
```

**WSL Projects:**
```json
"ssm": {
  "path": "/home/<USERNAME>/Documents/GeranPenyelidikanPembangunanSSM",
  "type": "wsl",
  "distro": "Ubuntu",
  "description": "WSL project"
}
```

WSL projects are auto-detected by paths starting with `/` or `~`. The `proj` command handles conversion:
- `-e` flag: Opens `\\wsl.localhost\<distro>\<path>` in Explorer
- `-t` flag: Opens Terminal at UNC path
- `-w` or no flag: Opens WSL directly at the Linux path
- `-m` flag: Opens Emacs directly (no shell window)

## PowerShell Environment Notes

### PowerShell 5.1 vs PowerShell 7+
- **PowerShell 5.1**: Legacy version built into Windows, lacks modern operators like `&&`
- **PowerShell 7+**: Modern, cross-platform, better performance, supports `&&`, `||`, etc.
- **Recommendation**: Install PowerShell 7 with `winget install Microsoft.PowerShell`

### $PROFILE Path Differences
PowerShell 5.1 and 7+ use **different** profile locations.

**** Standard Paths (without OneDrive)
| Version | Profile Path |
|---------|--------------|
| PowerShell 5.1 | `~\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1` |
| PowerShell 7+ | `~\Documents\PowerShell\Microsoft.PowerShell_profile.ps1` |

**** This Environment (OneDrive redirect) ✓ CONFIRMED
| Version | Profile Path |
|---------|--------------|
| PowerShell 5.1 | `C:\Users\faadz\OneDrive\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1` |
| PowerShell 7+ | `C:\Users\faadz\OneDrive\Documents\PowerShell\Microsoft.PowerShell_profile.ps1` |

**Important**: 
- Changes to one profile do NOT automatically apply to the other. Copy or source accordingly.
- Always verify with `$PROFILE` variable as OneDrive may redirect Documents folder.

## Dependencies

### Required PowerShell Modules

| Module | Purpose | Used In |
|--------|---------|---------|
| `Get-ChildItemColor` | Colorized directory listings (like `ls --color`) | `proj` command in Load-WorkflowProfile.ps1, Go-ToProject.ps1 |
| `PSReadLine` | Modern terminal experience (predictions, syntax highlighting) | PowerShell 7+ (pre-installed) |

**Install if missing:**
```powershell
# Get-ChildItemColor for colorized ls
Install-Module -Name Get-ChildItemColor -Scope CurrentUser

# PSReadLine (usually pre-installed with PS7)
Install-Module -Name PSReadLine -Force -Scope CurrentUser
```

### PowerShell 7 Enhancements

PowerShell 7+ comes with **PSReadLine 2.2+** providing modern terminal features:

- **Predictive IntelliSense** - Gray ghost text suggestions as you type
- **ListView** - Colorful dropdown menu of predictions
- **Enhanced History Search** - Interactive `Ctrl+R` like bash/zsh
- **Dynamic Help** - Inline command help with `F1`
- **Syntax Highlighting** - Real-time color-coded commands

See full guide: `documentation/ps7_psreadline_guide.org`

## PowerShell Environment Notes

### PowerShell 5.1 vs PowerShell 7+
- **PowerShell 5.1**: Legacy version built into Windows, lacks modern operators like `&&`
- **PowerShell 7+**: Modern, cross-platform, better performance, supports `&&`, `||`, etc.
- **Recommendation**: Install PowerShell 7 with `winget install Microsoft.PowerShell`

### $PROFILE Path Differences
PowerShell 5.1 and 7+ use **different** profile locations.

**** Standard Paths (without OneDrive)
| Version | Profile Path |
|---------|--------------|
| PowerShell 5.1 | `~\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1` |
| PowerShell 7+ | `~\Documents\PowerShell\Microsoft.PowerShell_profile.ps1` |

**** This Environment (OneDrive redirect) ✓ CONFIRMED
| Version | Profile Path |
|---------|--------------|
| PowerShell 5.1 | `C:\Users\faadz\OneDrive\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1` |
| PowerShell 7+ | `C:\Users\faadz\OneDrive\Documents\PowerShell\Microsoft.PowerShell_profile.ps1` |

**Important**: 
- Changes to one profile do NOT automatically apply to the other. Copy or source accordingly.
- Always verify with `$PROFILE` variable as OneDrive may redirect Documents folder.

### PowerShell 5.1 Compatibility
When writing scripts for this project:
- Avoid `&&` and `||` operators (PowerShell 7+ only)
- Use `if` statements or `sh -c "... && ..."` for WSL commands
- Test in PowerShell 5.1 if compatibility is required
