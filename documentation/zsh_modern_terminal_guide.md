# Modern Zsh Terminal Setup Guide

A PowerShell 7-like experience for Zsh using Zinit (fast, modern plugin manager).

## Features

| PS7 Feature | Zsh Equivalent | Plugin |
|-------------|----------------|--------|
| Gray ghost text suggestions | Autosuggestions | zsh-autosuggestions |
| Syntax highlighting | Real-time highlighting | fast-syntax-highlighting |
| Enhanced Ctrl+R | Fuzzy history search | fzf |
| ListView dropdown | FZF completion menu | fzf-tab |
| MenuComplete | Visual tab completion | Built-in + fzf-tab |
| Colorized output | ls colors, git status | eza, zsh-git-prompt |

## Installation

### Step 1: Install Zsh

```bash
sudo apt update && sudo apt install -y zsh
chsh -s $(which zsh)  # Set as default shell (logout/login required)
```

### Step 2: Install Dependencies

```bash
# fzf - fuzzy finder
sudo apt install -y fzf

# eza - modern ls replacement (formerly exa)
sudo apt install -y eza  # If not available, use: cargo install eza

# zoxide - smart cd (like z/jump)
curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash

# bat - syntax-highlighted cat
sudo apt install -y bat
```

### Step 3: Install Zinit

```bash
bash -c "$(curl --fail --show-error --silent --location https://raw.githubusercontent.com/zdharma-continuum/zinit/HEAD/scripts/install.sh)"
```

### Step 4: Use the Configuration

Copy the provided `.zshrc` to your home directory:

```bash
cp /mnt/c/Users/<USERNAME>/Documents/whkd_workflow/tools/shell/zshrc ~/.zshrc
```

Restart your terminal or run `zsh`.

## Key Bindings

| Key | Action |
|-----|--------|
| `→` (Right Arrow) | Accept entire autosuggestion |
| `Ctrl + F` | Accept one word at a time |
| `Ctrl + R` | Fuzzy history search (fzf) |
| `Tab` | Visual completion menu (fzf-tab) |
| `Shift + Tab` | Navigate completion menu up |
| `Ctrl + T` | Fuzzy file finder |
| `Alt + C` | Fuzzy cd to directory |

## Plugin Details

### zsh-autosuggestions
- Gray ghost text like PS7
- Suggests from history and completions
- Configurable color (dim gray by default)

### fast-syntax-highlighting
- Real-time syntax highlighting
- Faster than zsh-syntax-highlighting
- Better error detection

### fzf + fzf-tab
- Replaces default completion with fuzzy searchable menu
- Preview window for files, git branches, etc.
- Much better than plain zsh tab completion

### eza
- Modern `ls` replacement with colors and icons
- Git integration (shows modified files)
- Better defaults than `ls --color`

### zoxide
- Smart directory jumping (`z` command)
- Remembers frequently used directories
- Fuzzy matching: `z doc` → `~/Documents`

## Customization

### Change Autosuggestion Color

```zsh
# In ~/.zshrc, after loading zsh-autosuggestions
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=240'  # 240 = dark gray
```

### Change Key Bindings

```zsh
# Accept entire suggestion with Ctrl+Space
bindkey '^ ' autosuggest-accept

# Accept word with Ctrl+Right
bindkey '^[[1;5C' forward-word
```

### FZF Theme (match PS7 dark theme)

```zsh
export FZF_DEFAULT_OPTS="
  --height 40%
  --layout=reverse
  --border
  --color=bg+:#302D41,bg:#1E1E2E,spinner:#F8BD96,hl:#F28FAD
  --color=fg:#D9E0EE,header:#F28FAD,info:#DDB6F2,pointer:#F8BD96
  --color=marker:#ABE9B3,fg+:#D9E0EE,prompt:#96CDFB,hl+:#F28FAD
"
```

## Troubleshooting

### Slow startup?
Check with: `time zsh -i -c exit`
- Should be < 100ms with this config
- If slow: some plugins may need to be loaded with `zinit ice wait"0"`

### Autosuggestions not showing?
```zsh
# Check if plugin loaded
which _zsh_autosuggest_strategy_history

# Test with minimal config
zsh -f  # No config
source ~/.zinit/bin/zinit.zsh
zinit load zsh-users/zsh-autosuggestions
```

### fzf not found?
Make sure fzf is in PATH:
```zsh
which fzf || echo "Install fzf first"
```

## Comparison to PS7

| PS7 | Zsh Equivalent | Experience |
|-----|----------------|------------|
| `PredictionSource` | zsh-autosuggestions | Identical ghost text |
| `ListView` | fzf-tab completion | Actually better - fuzzy search |
| `Ctrl+R` history | fzf history | Identical fuzzy search |
| `MenuComplete` | fzf-tab | More visual, with previews |
| Syntax highlighting | fast-syntax-highlighting | More detailed than PS7 |
| `F1` Dynamic Help | `man` or tldr | Use `tldr <command>` instead |

## Resources

- [Zinit Documentation](https://zdharma-continuum.github.io/zinit/wiki/)
- [fzf](https://github.com/junegunn/fzf)
- [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)
- [eza](https://github.com/eza-community/eza)
- [zoxide](https://github.com/ajeetdsouza/zoxide)
