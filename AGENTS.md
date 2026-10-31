# Windows Hotkey Daemon (whkd) Setup - Agent Guidelines

## Project Goal
Set up whkd (Windows Hotkey Daemon) on Windows 11 for keyboard-driven window management.

Start by reading `* Handoff` in `PROJECT_LOG.org`; follow its Session Protocol at session end. Open tasks: `TODO.org`.

## What is whkd?
whkd is a simple Windows hotkey daemon that reads a configuration file and executes commands when hotkeys are pressed. It's commonly used alongside komorebi (a tiling window manager for Windows).

## Project Structure
```
C:\Users\faadz\Projects\whkd_workflow/
├── AGENTS.md              # This file - project context for agents
├── PROJECT_LOG.org        # Handoff + session log (gitignored, local-only)
├── TODO.org               # Backlog (gitignored, local-only)
├── config/
│   ├── whkdrc             # Versioned copy of the live whkd config
│   └── start_whkd.vbs     # Versioned copy of the whkd auto-start wrapper
├── tools/
│   ├── Install-WhkdConfig.ps1  # Deploys config/ to ~/.config/whkdrc and ~/.config/whkd/
│   └── workflows/         # PowerShell automation scripts (see below)
└── documentation/         # Org-mode docs, one per script plus reference guides
```

The files that actually govern the running daemon
(`~/.config/whkdrc`, `~/.config/whkd/start_whkd.vbs`) live outside this
repo, on the machine. `config/` holds the versioned copies;
`tools/Install-WhkdConfig.ps1` copies them into place (backing up
whatever is there first). Since whkd itself doesn't reload `whkdrc`
until restarted, edit `config/whkdrc`, run the install script, then
restart whkd (`alt + o`) to pick up the change - see FINDING 2 in
`documentation/workflow-audit-2026-07.org`.

## Key Requirements
- Windows 11 compatibility
- Maintainable configuration
- Clear documentation

## References
- whkd repository: https://github.com/LGUG2Z/whkd
- whkd documentation: https://lgug2z.github.io/whkd/

## Why whkd, and the Boundary with AutoHotkey
whkd was adopted for one specific reason: to bind a key to the PowerShell
`Switch-Desktop` cmdlet (from the VirtualDesktop module), because AutoHotkey
has no access to the virtual-desktop COM API and can only fake it with
`Ctrl+Win+Left/Right` keystrokes - relative, not absolute, and prone to
dropping repeated presses.

This machine also runs a separate AutoHotkey project
(`keyboardRemapping.ahk`, at `G:\My Drive\Peribadi\autohotkeyScripts\my_autohotkey_scripts\`,
its own repo with its own `AGENTS.md`/`PROJECT_LOG.org`). The division of
labor is intentional and disjoint: **AutoHotkey owns text expansion and
application automation** (hotstrings, templates, CapsLock remapping);
**whkd owns virtual desktops**. Neither should grow into the other's
territory.

That project also owns `restart-whkd.ps1` and `restart-whkd.bat`, two of
the mechanisms that can restart the whkd daemon - see FINDING 3 in
`documentation/workflow-audit-2026-07.org` before changing whkd's restart
logic.

**Shared namespace**: AHK binds bare `!n` / `!p` (Alt+letter), which is
otherwise whkd's namespace. Today's whkdrc only uses `alt + o` at the
bare-Alt level, so there's no collision, but any new bare `alt + <letter>`
binding in whkdrc must avoid `n` and `p`.

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
cd /mnt/c/Users/<USERNAME>/Projects/whkd_workflow/tools/shell
./install_zsh_modern.sh
```

### projects.json
JSON file containing project name → path mappings. Used by:
- `Go-ToProject.ps1` (standalone script)

The `proj` profile function was removed on 2026-10-31 (unused since zoxide took over); see `documentation/load-workflow-profile.org`.

To add/modify projects, edit `tools/workflows/projects.json` - changes apply everywhere automatically.

#### Project Types

**Windows Projects:**
```json
"whkd": {
  "path": "~\\Projects\\whkd_workflow",
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
| `Get-ChildItemColor` | Colorized directory listings (like `ls --color`) | Go-ToProject.ps1 |
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

### PowerShell 5.1 Compatibility
When writing scripts for this project:
- Avoid `&&` and `||` operators (PowerShell 7+ only)
- Use `if` statements or `sh -c "... && ..."` for WSL commands
- Test in PowerShell 5.1 if compatibility is required
