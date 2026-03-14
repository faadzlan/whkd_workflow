#!/bin/bash
# ============================================================================
# Install Modern Zsh Terminal Experience
# PowerShell 7-like features on Ubuntu/WSL
# ============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Modern Zsh Terminal Setup${NC}"
echo -e "${BLUE}  PowerShell 7-like Experience${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# ----------------------------------------------------------------------------
# 1. CHECK IF RUNNING IN WSL
# ----------------------------------------------------------------------------
IS_WSL=false
if [[ -n "$WSL_DISTRO_NAME" ]] || grep -q Microsoft /proc/version 2>/dev/null; then
    IS_WSL=true
    echo -e "${GREEN}WSL detected: $WSL_DISTRO_NAME${NC}"
fi

# ----------------------------------------------------------------------------
# 2. UPDATE PACKAGES
# ----------------------------------------------------------------------------
echo -e "${YELLOW}Updating package lists...${NC}"
sudo apt-get update -qq

# ----------------------------------------------------------------------------
# 3. INSTALL ZSH
# ----------------------------------------------------------------------------
echo -e "${YELLOW}Installing Zsh...${NC}"
if ! command -v zsh &> /dev/null; then
    sudo apt-get install -y -qq zsh
    echo -e "${GREEN}Zsh installed: $(zsh --version)${NC}"
else
    echo -e "${GREEN}Zsh already installed: $(zsh --version)${NC}"
fi

# ----------------------------------------------------------------------------
# 4. INSTALL DEPENDENCIES
# ----------------------------------------------------------------------------
echo -e "${YELLOW}Installing dependencies...${NC}"

# Essential packages
sudo apt-get install -y -qq git curl wget

# fzf - fuzzy finder
if ! command -v fzf &> /dev/null; then
    echo -e "${YELLOW}Installing fzf...${NC}"
    sudo apt-get install -y -qq fzf
fi

# bat - syntax-highlighted cat
if ! command -v bat &> /dev/null && ! command -v batcat &> /dev/null; then
    echo -e "${YELLOW}Installing bat...${NC}"
    sudo apt-get install -y -qq bat
    # Create alias if batcat exists
    if command -v batcat &> /dev/null && ! command -v bat &> /dev/null; then
        sudo ln -sf /usr/bin/batcat /usr/local/bin/bat
    fi
fi

# eza - modern ls replacement
if ! command -v eza &> /dev/null; then
    echo -e "${YELLOW}Installing eza...${NC}"
    # Try apt first (Ubuntu 24.04+ has it)
    if ! sudo apt-get install -y -qq eza 2>/dev/null; then
        # Fallback: install from GitHub releases
        echo -e "${YELLOW}Installing eza from GitHub...${NC}"
        EZA_VERSION=$(curl -s https://api.github.com/repos/eza-community/eza/releases/latest | grep -oP '"tag_name": "\K[^"]+')
        wget -q "https://github.com/eza-community/eza/releases/download/${EZA_VERSION}/eza_x86_64-unknown-linux-gnu.tar.gz" -O /tmp/eza.tar.gz
        tar -xzf /tmp/eza.tar.gz -C /tmp
        sudo mv /tmp/eza /usr/local/bin/
        rm /tmp/eza.tar.gz
    fi
fi

# zoxide - smart cd
if ! command -v zoxide &> /dev/null; then
    echo -e "${YELLOW}Installing zoxide...${NC}"
    curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
fi

# fd - faster find (optional but recommended for fzf)
if ! command -v fd &> /dev/null && ! command -v fdfind &> /dev/null; then
    echo -e "${YELLOW}Installing fd...${NC}"
    sudo apt-get install -y -qq fd-find
    if command -v fdfind &> /dev/null && ! command -v fd &> /dev/null; then
        sudo ln -sf $(which fdfind) /usr/local/bin/fd
    fi
fi

# delta - syntax-highlighted git diff (optional)
if ! command -v delta &> /dev/null; then
    echo -e "${YELLOW}Installing delta...${NC}"
    sudo apt-get install -y -qq git-delta 2>/dev/null || true
fi

# xclip for clipboard integration
sudo apt-get install -y -qq xclip 2>/dev/null || true

echo -e "${GREEN}Dependencies installed!${NC}"

# ----------------------------------------------------------------------------
# 5. INSTALL ZINIT
# ----------------------------------------------------------------------------
echo -e "${YELLOW}Installing Zinit plugin manager...${NC}"
ZINIT_HOME="${HOME}/.local/share/zinit/zinit.git"
if [[ ! -d $ZINIT_HOME ]]; then
    mkdir -p "$(dirname $ZINIT_HOME)"
    git clone --depth 1 https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
    echo -e "${GREEN}Zinit installed!${NC}"
else
    echo -e "${GREEN}Zinit already installed${NC}"
fi

# ----------------------------------------------------------------------------
# 6. BACKUP AND INSTALL ZSHRC
# ----------------------------------------------------------------------------
echo -e "${YELLOW}Setting up Zsh configuration...${NC}"

# Backup existing .zshrc
if [[ -f ~/.zshrc ]]; then
    BACKUP_FILE="~/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
    cp ~/.zshrc "$BACKUP_FILE"
    echo -e "${GREEN}Backed up existing .zshrc to $BACKUP_FILE${NC}"
fi

# Copy new configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/zshrc" ]]; then
    cp "$SCRIPT_DIR/zshrc" ~/.zshrc
else
    echo -e "${RED}Warning: zshrc not found in script directory${NC}"
    echo -e "${YELLOW}Please manually copy zshrc to ~/.zshrc${NC}"
fi

echo -e "${GREEN}Zsh configuration installed!${NC}"

# ----------------------------------------------------------------------------
# 7. SET DEFAULT SHELL
# ----------------------------------------------------------------------------
echo ""
echo -e "${YELLOW}Setting Zsh as default shell...${NC}"
CURRENT_SHELL=$(basename "$SHELL")
if [[ "$CURRENT_SHELL" != "zsh" ]]; then
    chsh -s $(which zsh)
    echo -e "${GREEN}Default shell changed to Zsh${NC}"
    echo -e "${YELLOW}NOTE: You need to log out and back in for this to take effect${NC}"
else
    echo -e "${GREEN}Zsh is already the default shell${NC}"
fi

# ----------------------------------------------------------------------------
# 8. SUMMARY
# ----------------------------------------------------------------------------
echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Installation Complete!${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo -e "${GREEN}Installed tools:${NC}"
echo "  - Zsh $(zsh --version 2>/dev/null | head -1)"
echo "  - fzf (fuzzy finder)"
echo "  - bat (syntax-highlighted cat)"
echo "  - eza (modern ls)"
echo "  - zoxide (smart cd)"
command -v fd &> /dev/null && echo "  - fd (fast find)"
command -v delta &> /dev/null && echo "  - delta (syntax-highlighted diff)"
echo ""
echo -e "${GREEN}Zsh plugins configured:${NC}"
echo "  - powerlevel10k (fast prompt theme)"
echo "  - fast-syntax-highlighting (real-time syntax highlighting)"
echo "  - zsh-autosuggestions (gray ghost text like PS7)"
echo "  - fzf-tab (visual tab completion menu)"
echo "  - zsh-completions (additional completions)"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Start a new terminal or run: zsh"
echo "  2. On first run, p10k configure will start - customize your prompt"
echo "  3. Try these key bindings:"
echo "     - Type 'git st' then press Right Arrow to accept suggestion"
echo "     - Press Ctrl+R for fuzzy history search"
echo "     - Press Ctrl+T for fuzzy file finder"
echo "     - Press Tab for visual completion menu"
echo "     - Type 'z doc' to jump to Documents"
echo ""
echo -e "${BLUE}Enjoy your modern terminal!${NC}"
