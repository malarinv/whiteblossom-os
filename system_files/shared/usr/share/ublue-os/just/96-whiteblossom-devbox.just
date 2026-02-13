# vim: set ft=make :

# Setup Devbox developer environment (Nix-backed, replaces distrobox for dev tools)
[group("developer")]
setup-devbox ACTION="":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh 2>/dev/null || true
    OPTION="{{ ACTION }}"

    # ── helpers ──────────────────────────────────────────────────────────
    nix_installed()  { command -v nix  &>/dev/null; }
    devbox_installed() { command -v devbox &>/dev/null; }

    show_status() {
        echo ""
        echo "Devbox Developer Environment Status"
        echo "===================================="
        if nix_installed; then
            echo "Nix:    $(nix --version)"
        else
            echo "Nix:    not installed"
        fi
        if devbox_installed; then
            echo "Devbox: $(devbox version 2>/dev/null || echo 'installed')"
            echo ""
            echo "Global packages:"
            devbox global list 2>/dev/null || echo "  (none)"
        else
            echo "Devbox: not installed"
        fi

        # Check shell integration
        SHELL_RC=""
        if [ -n "${ZSH_VERSION:-}" ] || [ "$(basename "${SHELL:-}")" = "zsh" ]; then
            SHELL_RC="$HOME/.zshrc"
        else
            SHELL_RC="$HOME/.bashrc"
        fi
        if [ -f "$SHELL_RC" ] && grep -q "devbox global shellenv" "$SHELL_RC" 2>/dev/null; then
            echo ""
            echo "Shell integration: enabled ($SHELL_RC)"
        else
            echo ""
            echo "Shell integration: not configured"
        fi
        echo ""
    }

    do_install() {
        echo ""
        echo "Setting up Devbox Developer Environment"
        echo "========================================"
        echo ""
        echo "This will install:"
        echo "  1. Nix package manager (via Determinate Nix Installer)"
        echo "  2. Devbox (Nix-backed dev environment manager)"
        echo "  3. Shell integration (devbox global shellenv)"
        echo "  4. Recommended global packages (nodejs, python, uv, etc.)"
        echo ""

        # Step 1: Install Nix
        if nix_installed; then
            echo "Nix is already installed: $(nix --version)"
        else
            echo "Installing Nix via Determinate Nix Installer..."
            echo "(This handles immutable OS filesystems automatically)"
            echo ""
            curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
            # Source nix for current session
            if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
                . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
            fi
            echo ""
            echo "Nix installed successfully."
        fi

        # Step 2: Install Devbox
        if devbox_installed; then
            echo "Devbox is already installed: $(devbox version 2>/dev/null)"
        else
            echo ""
            echo "Installing Devbox..."
            curl -fsSL https://get.jetify.com/devbox | bash -s -- -f
            echo "Devbox installed successfully."
        fi

        # Step 3: Shell integration
        SHELL_RC=""
        if [ -n "${ZSH_VERSION:-}" ] || [ "$(basename "${SHELL:-}")" = "zsh" ]; then
            SHELL_RC="$HOME/.zshrc"
        else
            SHELL_RC="$HOME/.bashrc"
        fi

        if [ -n "$SHELL_RC" ]; then
            if ! grep -q "devbox global shellenv" "$SHELL_RC" 2>/dev/null; then
                echo "" >> "$SHELL_RC"
                echo "# Devbox global packages (managed by ujust setup-devbox)" >> "$SHELL_RC"
                echo 'eval "$(devbox global shellenv)"' >> "$SHELL_RC"
                echo ""
                echo "Added devbox global shellenv to $SHELL_RC"
            else
                echo "Shell integration already configured in $SHELL_RC"
            fi
        fi

        # Source for current session
        eval "$(devbox global shellenv)" 2>/dev/null || true

        # Step 4: Install recommended global packages
        echo ""
        echo "Installing recommended global packages..."
        echo ""
        devbox global add \
            nodejs@22 \
            python@3.12 \
            uv@latest \
            ripgrep@latest \
            fd@latest \
            jq@latest \
            just@latest \
            shellcheck@latest \
            shfmt@latest

        echo ""
        echo "===================================="
        echo "Devbox setup complete!"
        echo "===================================="
        echo ""
        echo "What was installed:"
        echo "  - Nix package manager"
        echo "  - Devbox (dev environment manager)"
        echo "  - nodejs@22 (default Node.js -- replaces nvm)"
        echo "  - python@3.12, uv (Python toolchain -- replaces pip/distrobox)"
        echo "  - ripgrep, fd, jq (search/utility tools)"
        echo "  - just, shellcheck, shfmt (build/lint tools)"
        echo ""
        echo "Next steps:"
        echo "  - Open a new terminal (or run: source $SHELL_RC)"
        echo "  - Run 'ujust setup-ai-tools' to install AI coding CLI tools"
        echo "  - Per-project: add a devbox.json for project-specific tool versions"
        echo ""
    }

    do_uninstall() {
        echo ""
        echo "Uninstalling Devbox Developer Environment"
        echo "=========================================="
        echo ""
        echo "This will remove:"
        echo "  - Devbox and all global packages"
        echo "  - Nix package manager and /nix directory"
        echo "  - Shell integration from your rc file"
        echo ""

        CONFIRM="Cancel"
        if type Choose &>/dev/null; then
            CONFIRM=$(Choose "Continue" "Cancel")
        else
            read -rp "Continue? (y/N) " yn
            [[ "$yn" =~ ^[Yy] ]] && CONFIRM="Continue"
        fi

        if [ "$CONFIRM" != "Continue" ]; then
            echo "Uninstall cancelled."
            return 0
        fi

        # Remove shell integration
        SHELL_RC=""
        if [ -n "${ZSH_VERSION:-}" ] || [ "$(basename "${SHELL:-}")" = "zsh" ]; then
            SHELL_RC="$HOME/.zshrc"
        else
            SHELL_RC="$HOME/.bashrc"
        fi
        if [ -n "$SHELL_RC" ] && [ -f "$SHELL_RC" ]; then
            sed -i '/# Devbox global packages/d' "$SHELL_RC"
            sed -i '/devbox global shellenv/d' "$SHELL_RC"
            echo "Removed shell integration from $SHELL_RC"
        fi

        # Uninstall Nix (which removes everything in /nix including devbox packages)
        if [ -x /nix/nix-installer ]; then
            /nix/nix-installer uninstall --no-confirm
            echo "Nix and Devbox uninstalled."
        elif nix_installed; then
            echo "Could not find nix-installer. Manual removal may be needed."
            echo "See: https://github.com/DeterminateSystems/nix-installer#uninstalling"
        else
            echo "Nix is not installed."
        fi

        echo ""
        echo "Uninstall complete. Open a new terminal to apply changes."
    }

    # ── main ─────────────────────────────────────────────────────────────
    if [ "$OPTION" == "help" ]; then
        echo "Usage: ujust setup-devbox <option>"
        echo "  <option>: Specify the quick option to skip the prompt"
        echo "  Use 'install' to install Devbox developer environment"
        echo "  Use 'status' to check installation status"
        echo "  Use 'uninstall' to remove Devbox and Nix"
        exit 0
    elif [ "$OPTION" == "" ]; then
        echo "${bold:-}Devbox Developer Environment Setup${normal:-}"
        echo ""
        echo "Devbox provides native developer tools (Node.js, Python, uv, etc.)"
        echo "without containers or symlinks -- clean paths that AI tools understand."
        echo ""
        if type Choose &>/dev/null; then
            OPTION=$(Choose \
                "Install Devbox" \
                "Check Status" \
                "Uninstall Devbox" \
            )
        else
            echo "Options: install, status, uninstall"
            read -rp "Choice: " OPTION
        fi
    fi

    if [[ "${OPTION,,}" =~ (^install|^install[[:space:]]devbox) ]]; then
        do_install
    elif [[ "${OPTION,,}" =~ (^status|^check) ]]; then
        show_status
    elif [[ "${OPTION,,}" =~ (^uninstall) ]]; then
        do_uninstall
    fi

# Setup AI coding CLI tools (Gemini CLI, Claude Code, OpenCode)
[group("developer")]
setup-ai-tools ACTION="":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh 2>/dev/null || true
    OPTION="{{ ACTION }}"

    # ── preflight ────────────────────────────────────────────────────────
    check_devbox() {
        if ! command -v devbox &>/dev/null; then
            echo "Error: Devbox is not installed."
            echo "Please run 'ujust setup-devbox install' first."
            exit 1
        fi
        if ! command -v node &>/dev/null; then
            echo "Error: Node.js is not available."
            echo "Please run 'ujust setup-devbox install' first to get Node.js via Devbox."
            exit 1
        fi
    }

    # ── tool installers ──────────────────────────────────────────────────
    install_gemini() {
        echo "Installing Gemini CLI..."
        npm install -g @google/gemini-cli
        echo "Gemini CLI installed. Run 'gemini' to start."
        echo "  Setup: Sign in with your Google account on first run."
    }

    install_claude() {
        echo "Installing Claude Code..."
        npm install -g @anthropic-ai/claude-code
        echo "Claude Code installed. Run 'claude' to start."
        echo "  Setup: Set ANTHROPIC_API_KEY or sign in on first run."
    }

    install_opencode() {
        echo "Installing OpenCode..."
        curl -fsSL https://opencode.sh/install.sh | sh
        echo "OpenCode installed. Run 'opencode' to start."
        echo "  Setup: Configure your preferred AI model on first run."
    }

    install_openspec() {
        echo "Installing OpenSpec CLI..."
        npm install -g @fission-ai/openspec@latest
        echo "OpenSpec CLI installed. Run 'openspec' to start."
        echo "  Setup: Run 'openspec init' in your project directory."
    }

    update_tools() {
        echo "Updating installed AI CLI tools..."
        echo ""
        if command -v gemini &>/dev/null; then
            echo "Updating Gemini CLI..."
            npm update -g @google/gemini-cli
        fi
        if command -v claude &>/dev/null; then
            echo "Updating Claude Code..."
            npm update -g @anthropic-ai/claude-code
        fi
        if command -v opencode &>/dev/null; then
            echo "Updating OpenCode..."
            curl -fsSL https://opencode.sh/install.sh | sh
        fi
        if command -v openspec &>/dev/null; then
            echo "Updating OpenSpec CLI..."
            npm update -g @fission-ai/openspec
        fi
        echo ""
        echo "Update complete."
    }

    show_status() {
        echo ""
        echo "AI CLI Tools Status"
        echo "==================="
        if command -v gemini &>/dev/null; then
            echo "Gemini CLI:  installed ($(which gemini))"
        else
            echo "Gemini CLI:  not installed"
        fi
        if command -v claude &>/dev/null; then
            echo "Claude Code: installed ($(which claude))"
        else
            echo "Claude Code: not installed"
        fi
        if command -v opencode &>/dev/null; then
            echo "OpenCode:    installed ($(which opencode))"
        else
            echo "OpenCode:    not installed"
        fi
        if command -v openspec &>/dev/null; then
            echo "OpenSpec:    installed ($(which openspec))"
        else
            echo "OpenSpec:    not installed"
        fi
        echo ""
        echo "AI IDE Apps (installed in OS image):"
        if command -v antigravity &>/dev/null || [ -f /usr/bin/antigravity ]; then
            echo "Antigravity: installed"
        else
            echo "Antigravity: not found"
        fi
        if command -v code &>/dev/null; then
            echo "VSCode:      installed"
        else
            echo "VSCode:      not found"
        fi
        echo ""
    }

    # ── main ─────────────────────────────────────────────────────────────
    if [ "$OPTION" == "help" ]; then
        echo "Usage: ujust setup-ai-tools <option>"
        echo "  <option>: Specify the quick option to skip the prompt"
        echo "  Use 'all' to install all AI CLI tools"
        echo "  Use 'gemini' to install Gemini CLI"
        echo "  Use 'claude' to install Claude Code"
        echo "  Use 'opencode' to install OpenCode"
        echo "  Use 'openspec' to install OpenSpec CLI"
        echo "  Use 'status' to check which tools are installed"
        echo "  Use 'update' to update all installed tools"
        exit 0
    fi

    check_devbox

    if [ "$OPTION" == "" ]; then
        echo "${bold:-}AI CLI Tools Setup${normal:-}"
        echo ""
        echo "Install AI coding assistants for your terminal."
        echo "These use Node.js and runtimes from Devbox (native, no containers)."
        echo ""
        if type Choose &>/dev/null; then
            OPTION=$(Choose \
                "Install All" \
                "Install Gemini CLI" \
                "Install Claude Code" \
                "Install OpenCode" \
                "Install OpenSpec CLI" \
                "Check Status" \
                "Update All" \
            )
        else
            echo "Options: all, gemini, claude, opencode, openspec, status, update"
            read -rp "Choice: " OPTION
        fi
    fi

    if [[ "${OPTION,,}" =~ (^all|^install[[:space:]]all) ]]; then
        install_gemini
        echo ""
        install_claude
        echo ""
        install_opencode
        echo ""
        install_openspec
        echo ""
        echo "All AI CLI tools installed."
        echo "Note: Each tool requires API keys or sign-in on first use."
    elif [[ "${OPTION,,}" =~ gemini ]]; then
        install_gemini
    elif [[ "${OPTION,,}" =~ claude ]]; then
        install_claude
    elif [[ "${OPTION,,}" =~ opencode ]]; then
        install_opencode
    elif [[ "${OPTION,,}" =~ openspec ]]; then
        install_openspec
    elif [[ "${OPTION,,}" =~ (^status|^check) ]]; then
        show_status
    elif [[ "${OPTION,,}" =~ update ]]; then
        update_tools
    fi
