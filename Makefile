# ============================================================
#  macOS Developer Setup
#  Usage:
#    make help       — list all targets
#    make all        — run everything in order
#    make brew       — install Homebrew + CLI tools
#    make shell      — install oh-my-zsh + plugins + theme
#    make path       — wire path, env variables, and language runtimes into .zshrc (tools installed via Brewfile)
#    make apps       — install GUI apps via Homebrew Cask
# ============================================================

SHELL     := /bin/bash
BREWFILE  ?= $(HOME)/projects/dev-env/Brewfile
ZSH_CUSTOM ?= $(HOME)/.oh-my-zsh/custom

# Puts brew on PATH for one recipe line. Prefix every line that calls brew.
# Why: each recipe line is its own shell, make never reads ~/.zprofile, and GNU
# Make 3.81 (macOS) runs simple lines without a shell, so `export PATH` alone
# doesn't reach them. Apple Silicon installs to /opt/homebrew, Intel to /usr/local.
BREW_ENV := for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$$b" ] && eval "$$("$$b" shellenv)" && break; done;

.PHONY: help all brew shell path apps bundle

# ── Default target ───────────────────────────────────────────
help:
	@echo ""
	@echo "  macOS Developer Setup"
	@echo ""
	@echo "  Targets:"
	@echo "    make all        Run every target in order"
	@echo "    make brew       Install Homebrew, then run brew bundle"
	@echo "    make shell      oh-my-zsh, plugins, Powerlevel10k"
	@echo "    make path       Wire path, env variables, and language runtimes"
	@echo "    make apps       Alias for make brew (apps live in Brewfile)"
	@echo "    make bundle     Re-run brew bundle against the Brewfile"
	@echo ""
	@echo "    BREWFILE=$(BREWFILE)"
	@echo ""

# ── All ──────────────────────────────────────────────────────
all: brew shell path apps
	@echo ""
	@echo "✅  Setup complete! Restart your terminal (or run: source ~/.zshrc)"

# ── Homebrew + brew bundle ────────────────────────────────────
brew:
	@echo "==> Installing Homebrew..."
	@$(BREW_ENV) if ! command -v brew &>/dev/null; then \
		/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
	else \
		echo "    brew already installed — skipping"; \
	fi

	@echo "==> Adding brew to ~/.zprofile..."
	@$(BREW_ENV) grep -qF 'brew shellenv' $(HOME)/.zprofile 2>/dev/null || \
		printf '\neval "$$(%s/bin/brew shellenv)"\n' "$$(brew --prefix)" >> $(HOME)/.zprofile

	@echo "==> Updating Homebrew..."
	@$(BREW_ENV) brew update

	@$(MAKE) bundle

	@echo "==> Configuring fzf key bindings..."
	@$(BREW_ENV) "$$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc --no-bash --no-fish

	@echo "==> brew done ✓"

# ── brew bundle (re-run anytime to sync the Brewfile) ─────────
bundle:
	@echo "==> Running brew bundle ($(BREWFILE))..."
	@$(BREW_ENV) brew bundle --file="$(BREWFILE)"
	@echo "==> bundle done ✓"

# ── Shell: oh-my-zsh + plugins + theme ───────────────────────
shell:
	@echo "==> Installing oh-my-zsh..."
	@if [ ! -d "$(HOME)/.oh-my-zsh" ]; then \
		RUNZSH=no CHSH=no sh -c \
			"$$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"; \
	else \
		echo "    oh-my-zsh already installed — skipping"; \
	fi

	@echo "==> Installing zsh-autosuggestions..."
	@if [ ! -d "$(ZSH_CUSTOM)/plugins/zsh-autosuggestions" ]; then \
		git clone https://github.com/zsh-users/zsh-autosuggestions \
			$(ZSH_CUSTOM)/plugins/zsh-autosuggestions; \
	else \
		echo "    zsh-autosuggestions already present — skipping"; \
	fi

	@echo "==> Installing zsh-syntax-highlighting..."
	@if [ ! -d "$(ZSH_CUSTOM)/plugins/zsh-syntax-highlighting" ]; then \
		git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
			$(ZSH_CUSTOM)/plugins/zsh-syntax-highlighting; \
	else \
		echo "    zsh-syntax-highlighting already present — skipping"; \
	fi

	@echo "==> Installing zsh-completions..."
	@if [ ! -d "$(ZSH_CUSTOM)/plugins/zsh-completions" ]; then \
		git clone https://github.com/zsh-users/zsh-completions \
			$(ZSH_CUSTOM)/plugins/zsh-completions; \
	else \
		echo "    zsh-completions already present — skipping"; \
	fi

	@echo "==> Installing Powerlevel10k theme..."
	@if [ ! -d "$(ZSH_CUSTOM)/themes/powerlevel10k" ]; then \
		git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
			$(ZSH_CUSTOM)/themes/powerlevel10k; \
	else \
		echo "    Powerlevel10k already present — skipping"; \
	fi

	@echo "==> Patching .zshrc..."
	# Set ZSH_THEME
	@if grep -q '^ZSH_THEME=' $(HOME)/.zshrc; then \
		sed -i '' 's|^ZSH_THEME=.*|ZSH_THEME="powerlevel10k/powerlevel10k"|' $(HOME)/.zshrc; \
	else \
		echo 'ZSH_THEME="powerlevel10k/powerlevel10k"' >> $(HOME)/.zshrc; \
	fi
	# Enable plugins (idempotent — only patches if line looks like the default)
	@if grep -q '^plugins=(git)' $(HOME)/.zshrc; then \
		sed -i '' 's|^plugins=(git)|plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions fzf)|' \
			$(HOME)/.zshrc; \
	else \
		echo "    plugins line already customised — skipping (edit manually if needed)"; \
	fi

	@echo "==> shell done ✓"

# ── Language wiring (.zshrc hooks; tools installed via brew bundle) ──
path:
	@echo "==> Wiring .local/bin..."
	@grep -qF '.local/bin' $(HOME)/.zshrc || \
		printf '\n# go\nexport PATH="$$HOME/.local/bin:$$PATH"\n' >> $(HOME)/.zshrc

	@echo "==> Wiring nvm..."
	@grep -qF 'NVM_DIR' $(HOME)/.zshrc || \
		printf '\n# nvm\nexport NVM_DIR="$$HOME/.nvm"\n[ -s "$$(brew --prefix)/opt/nvm/nvm.sh" ] && . "$$(brew --prefix)/opt/nvm/nvm.sh"\n[ -s "$$(brew --prefix)/opt/nvm/etc/bash_completion.d/nvm" ] && . "$$(brew --prefix)/opt/nvm/etc/bash_completion.d/nvm"\n' >> $(HOME)/.zshrc
	@echo '  → Run: nvm install --lts && nvm use --lts'

	@echo "==> Wiring pyenv..."
	@grep -qF 'pyenv init' $(HOME)/.zshrc || \
		printf '\n# pyenv\nexport PYENV_ROOT="$$HOME/.pyenv"\nexport PATH="$$PYENV_ROOT/bin:$$PATH"\neval "$$(pyenv init -)"\neval "$$(pyenv virtualenv-init -)"\n' >> $(HOME)/.zshrc
	@echo '  → Run: pyenv install 3.12 && pyenv global 3.12'

	@echo "==> Wiring rbenv..."
	@grep -qF 'rbenv init' $(HOME)/.zshrc || \
		printf '\n# rbenv\neval "$$(rbenv init - zsh)"\n' >> $(HOME)/.zshrc
	@echo '  → Run: rbenv install 3.3.0 && rbenv global 3.3.0'

	@echo "==> Wiring Go..."
	@grep -qF 'go/bin' $(HOME)/.zshrc || \
		printf '\n# go\nexport PATH="$$HOME/go/bin:$$PATH"\n' >> $(HOME)/.zshrc

	@echo "==> Wiring KUBECONFIG..."
	@grep -qF 'KUBECONFIG' $(HOME)/.zshrc || \
		printf '\n# kubeconfig\nexport KUBECONFIG="$$HOME/.kube/kubeconfig.yaml"\n' >> $(HOME)/.zshrc
	@echo "==> Wiring rustup..."
	@$(BREW_ENV) grep -qE 'cargo/env|opt/rustup/bin' $(HOME)/.zshrc || \
		printf '\n# rust (Homebrew rustup is keg-only, so its bin is not linked)\nexport PATH="%s/opt/rustup/bin:$$HOME/.cargo/bin:$$PATH"\n' "$$(brew --prefix)" >> $(HOME)/.zshrc
	@echo "==> Installing default Rust toolchain..."
	@$(BREW_ENV) rustup="$$(brew --prefix)/opt/rustup/bin/rustup"; \
		if "$$rustup" show active-toolchain &>/dev/null; then \
			echo "    toolchain already set — skipping"; \
		else \
			"$$rustup" default stable; \
		fi
	@echo '  → Run: rustup update'

	@echo "==> path done ✓"

# ── Apps (alias — all apps now live in the Brewfile) ──────────
apps: bundle
	@echo "==> apps done ✓ (installed via Brewfile)"
