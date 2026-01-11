# ClaudeBox 🐳

[![Docker](https://img.shields.io/badge/Docker-Required-blue.svg)](https://www.docker.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![GitHub](https://img.shields.io/badge/GitHub-RchGrav%2Fclaudebox-blue.svg)](https://github.com/RchGrav/claudebox)

The Ultimate Claude Code Docker Development Environment - Run Claude AI's coding assistant in a fully containerized, reproducible environment with pre-configured development profiles and MCP servers.

```
 ██████╗██╗      █████╗ ██╗   ██╗██████╗ ███████╗
██╔════╝██║     ██╔══██╗██║   ██║██╔══██╗██╔════╝
██║     ██║     ███████║██║   ██║██║  ██║█████╗
██║     ██║     ██╔══██║██║   ██║██║  ██║██╔══╝
╚██████╗███████╗██║  ██║╚██████╔╝██████╔╝███████╗
 ╚═════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝

██████╗  ██████╗ ██╗  ██╗
██╔══██╗██╔═══██╗╚██╗██╔╝
██████╔╝██║   ██║ ╚███╔╝ 
██╔══██╗██║   ██║ ██╔██╗ 
██████╔╝╚██████╔╝██╔╝ ██╗
╚═════╝  ╚═════╝ ╚═╝  ╚═╝
```

## 🚀 What's New in Latest Update

- **Named Profiles**: `claudebox profile create <name>` - Run multiple named Claude sessions per project
- **Project-Local State**: All profile data stored in `$PROJECT/.claudebox/profiles/` for better isolation
- **Security Enhancement**: Global config (`~/.claudebox/`) is now mounted read-only in container
- **Migration System**: `claudebox migrate` automatically converts old global structure to new local profiles
- **Subcommand Routers**: `claudebox env <cmd>` and `claudebox profile <cmd>` for better organization
- **Backward Compatibility**: Old commands (`slots`, `create`, `slot N`) still work with deprecation warnings
- **Enhanced UI/UX**: Improved menu alignment and comprehensive info display
- **Firewall Management**: New `allowlist` command to view/edit network allowlists
- **Per-Project Isolation**: Separate Docker images, auth state, history, and configs
- **Smart Profile Dependencies**: Automatic dependency resolution (e.g., C includes build-tools)

## ✨ Features

- **Containerized Environment**: Run Claude Code in an isolated Docker container
- **Development Profiles**: Pre-configured language stacks (C/C++, Python, Rust, Go, etc.)
- **Project Isolation**: Complete separation of images, settings, and data between projects
- **Persistent Configuration**: Settings and data persist between sessions
- **Multi-Instance Support**: Work on multiple projects simultaneously
- **Package Management**: Easy installation of additional development tools
- **Auto-Setup**: Handles Docker installation and configuration automatically
- **Security Features**: Network isolation with project-specific firewall allowlists
- **Developer Experience**: GitHub CLI, Delta, fzf, and zsh with oh-my-zsh powerline
- **Python Virtual Environments**: Automatic per-project venv creation with uv
- **Cross-Platform**: Works on Ubuntu, Debian, Fedora, Arch, and more
- **Shell Experience**: Powerline zsh with syntax highlighting and autosuggestions
- **Tmux Integration**: Seamless tmux socket mounting for multi-pane workflows

## 📋 Prerequisites

- Linux or macOS (WSL2 for Windows)
- Bash shell
- Docker (will be installed automatically if missing)

## 🛠️ Installation

ClaudeBox v2.0.0 offers two installation methods:

### Method 1: Self-Extracting Installer (Recommended)

The self-extracting installer is ideal for automated setups and quick installation:

```bash
# Download the latest release
wget https://github.com/RchGrav/claudebox/releases/latest/download/claudebox.run
chmod +x claudebox.run
./claudebox.run
```

This will:
- Extract ClaudeBox to `~/.claudebox/source/`
- Create a symlink at `~/.local/bin/claudebox` (you may need to add `~/.local/bin` to your PATH)
- Show setup instructions if PATH configuration is needed

### Method 2: Archive Installation

For manual installation or custom locations, use the archive:

```bash
# Download the archive
wget https://github.com/RchGrav/claudebox/releases/latest/download/claudebox-2.0.0.tar.gz

# Extract to your preferred location
mkdir -p ~/my-tools/claudebox
tar -xzf claudebox-2.0.0.tar.gz -C ~/my-tools/claudebox

# Run main.sh to create symlink
cd ~/my-tools/claudebox
./main.sh

# Or create your own symlink
ln -s ~/my-tools/claudebox/main.sh ~/.local/bin/claudebox
```

### Development Installation

For development or testing the latest changes:
```bash
# Clone the repository
git clone https://github.com/RchGrav/claudebox.git
cd claudebox

# Build the installer
bash .builder/build.sh

# Run the installer
./claudebox.run
```

### PATH Configuration

If `claudebox` command is not found after installation, add `~/.local/bin` to your PATH:

```bash
# For Bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# For Zsh (macOS default)
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

The installer will:
- ✅ Extract ClaudeBox to `~/.claudebox/source/`
- ✅ Create symlink at `~/.local/bin/claudebox`
- ✅ Check for Docker (install if needed on first run)
- ✅ Configure Docker for non-root usage (on first run)


## 📚 Usage

### Basic Usage

```bash
# Launch Claude Code CLI
claudebox

# Pass arguments to Claude
claudebox --model opus -c

# Save your arguments so you don't need to type them every time
claudebox --model opus -c

# View the Claudebox info screen
claudebox info

# Get help
claudebox --help        # Shows Claude help with ClaudeBox additions
```

### Multi-Instance Support

ClaudeBox supports running multiple named profiles in the same project:

```bash
# Terminal 1 - Default profile
cd ~/projects/myapp
claudebox

# Terminal 2 - Create and run frontend profile
cd ~/projects/myapp
claudebox profile create frontend
claudebox profile run frontend

# Terminal 3 - Create and run backend profile
cd ~/projects/myapp
claudebox profile create backend
claudebox profile run backend
```

Each profile maintains its own:
- Authentication state (`.claude/`)
- Tool configurations (`.config/`)
- Python virtual environment (`.venv/`)
- Claude settings (`.claude.json`)

Each project also maintains:
- Docker image (`claudebox-<project-name>`)
- Development environment profiles (python, rust, etc.)
- Firewall allowlist (global)

### Development Environments

ClaudeBox includes 15+ pre-configured development environments:

```bash
# List all available development environments
claudebox env list

# Add development environments to your project
claudebox env add python ml       # Python + Machine Learning
claudebox env add c openwrt       # C/C++ + OpenWRT
claudebox env add rust go         # Rust + Go

# Remove environments
claudebox env remove rust

# Install additional apt packages
claudebox env install htop vim
```

#### Available Environments:

**Core:**
- **core** - Core Development Utilities (compilers, VCS, shell tools)
- **build-tools** - Build Tools (CMake, autotools, Ninja)
- **shell** - Optional Shell Tools (fzf, SSH, man, rsync, file)
- **networking** - Network Tools (IP stack, DNS, route tools)

**Languages:**
- **c** - C/C++ Development (debuggers, analyzers, Boost, ncurses, cmocka)
- **rust** - Rust Development (installed via rustup)
- **python** - Python Development (managed via uv)
- **go** - Go Development (installed from upstream archive)
- **flutter** - Flutter Framework (installed using fvm, use FLUTTER_SDK_VERSION to set different version)
- **javascript** - JavaScript/TypeScript (Node installed via nvm)
- **java** - Java Development (Latest LTS via SDKMan, Maven, Gradle, Ant)
- **ruby** - Ruby Development (gems, native deps, XML/YAML)
- **php** - PHP Development (PHP + extensions + Composer)

**Specialized:**
- **openwrt** - OpenWRT Development (cross toolchain, QEMU, distro tools)
- **database** - Database Tools (clients for major databases)
- **devops** - DevOps Tools (Docker, Kubernetes, Terraform, etc.)
- **web** - Web Dev Tools (nginx, HTTP test clients)
- **embedded** - Embedded Dev (ARM toolchain, serial debuggers)
- **datascience** - Data Science (Python, Jupyter, R)
- **security** - Security Tools (scanners, crackers, packet tools)
- **ml** - Machine Learning (build layer only; Python via uv)

### Container Profiles

Manage multiple authenticated Claude sessions per project:

```bash
# List all profiles for the current project
claudebox profile list

# Create profiles (defaults to 'default' if no name given)
claudebox profile create           # Creates 'default' profile
claudebox profile create frontend  # Creates 'frontend' profile
claudebox profile create backend   # Creates 'backend' profile

# Run a profile (defaults to 'default' if no name given)
claudebox profile run              # Run 'default' profile
claudebox profile run frontend     # Run 'frontend' profile

# Remove profiles
claudebox profile remove frontend  # Remove specific profile
claudebox profile remove all       # Remove all profiles

# Kill running containers
claudebox profile kill             # Show running containers
claudebox profile kill frontend    # Kill specific container
claudebox profile kill all         # Kill all containers for this project
```

### Default Flags Management

Save your preferred security flags to avoid typing them every time:

```bash
# Save default flags
claudebox save --enable-sudo --disable-firewall

# Clear saved flags
claudebox save

# Now all claudebox commands will use your saved flags automatically
claudebox  # Will run with sudo and firewall disabled
```

### Project Information

View comprehensive information about your ClaudeBox setup:

```bash
# Show detailed project and system information
claudebox info
```

The info command displays:
- **Current Project**: Path, ID, and data directory
- **ClaudeBox Installation**: Script location and symlink
- **Saved CLI Flags**: Your default flags configuration
- **Claude Commands**: Global and project-specific custom commands
- **Project Profiles**: Installed profiles, packages, and available options
- **Docker Status**: Image status, creation date, layers, running containers
- **All Projects Summary**: Total projects, images, and Docker system usage

### Package Management

```bash
# Install additional apt packages
claudebox env install htop vim tmux

# Open a powerline zsh shell in the container
claudebox shell

# Update Claude CLI
claudebox update

# View/edit firewall allowlist
claudebox allowlist

# View/edit custom volume mounts
claudebox mount
```

### Tmux Integration

ClaudeBox provides tmux support for multi-pane workflows:

```bash
# Launch ClaudeBox with tmux support
claudebox tmux

# If you're already in a tmux session, the socket will be automatically mounted
# Otherwise, tmux will be available inside the container

# Use tmux commands inside the container:
# - Create new panes: Ctrl+b % (vertical) or Ctrl+b " (horizontal)
# - Switch panes: Ctrl+b arrow-keys  
# - Create new windows: Ctrl+b c
# - Switch windows: Ctrl+b n/p or Ctrl+b 0-9
```

ClaudeBox automatically detects and mounts existing tmux sockets from the host, or provides tmux functionality inside the container for powerful multi-context workflows.

### Task Engine

ClaudeBox contains a compact task engine for reliable code generation tasks:

```bash
# In Claude, use the task command
/task

# This provides a systematic approach to:
# - Breaking down complex tasks
# - Implementing with quality checks
# - Iterating until specifications are met
```

### Security Options

```bash
# Run with sudo enabled (use with caution)
claudebox --enable-sudo

# Disable network firewall (allows all network access)
claudebox --disable-firewall

# Skip permission checks
claudebox --dangerously-skip-permissions
```

### Maintenance

```bash
# Interactive clean menu
claudebox clean

# Project-specific cleanup options
claudebox clean --project          # Shows submenu with options:
  # profiles - Remove profile configuration (*.ini file)
  # data     - Remove project data (auth, history, configs, firewall)
  # docker   - Remove project Docker image
  # all      - Remove everything for this project

# Global cleanup options
claudebox clean --containers       # Remove ClaudeBox containers
claudebox clean --image           # Remove containers and current project image
claudebox clean --cache           # Remove Docker build cache
claudebox clean --volumes         # Remove ClaudeBox volumes
claudebox clean --all             # Complete Docker cleanup

# Rebuild the image from scratch
claudebox rebuild
```

## 🔧 Configuration

ClaudeBox uses a secure two-tier configuration model:

### Global Configuration (`~/.claudebox/`)
Mounted **read-only** in the container for security:
- `mounts` - Custom volume mount definitions
- `allowlist` - Network firewall allowlist
- `profiles.ini` - Development environment profiles (python, rust, etc.)
- `common.sh` - Shared utilities

### Project-Local Profiles (`$PROJECT/.claudebox/profiles/`)
Each project stores its runtime state locally with named profiles:
```
$PROJECT/.claudebox/profiles/
├── default/                # First profile (auto-created)
│   ├── .claude/            # Claude auth state & config
│   ├── .config/            # Tool configurations
│   ├── .cache/             # Cache data
│   └── .venv/              # Python venv (if python profile)
├── frontend/               # Additional named profile
│   └── ...                 # Each profile is fully isolated
└── backend/
    └── ...
```

**Important:** Add `.claudebox/` to your project's `.gitignore` to prevent committing auth state and cache:
```bash
# Add to your project's .gitignore
echo ".claudebox/" >> .gitignore
```

### Other Locations
- `~/.claude/` - Global Claude configuration (mounted read-only)
- Current directory mounted as `/workspace` in container

### Project-Specific Features

Each project automatically gets:
- **Docker Image**: `claudebox-<project-name>` with installed dev environments
- **Named Profiles**: Run multiple authenticated Claude sessions in parallel
- **Python Virtual Environment**: Profile-specific `.venv` with uv
- **Firewall Allowlist**: Customizable network access rules (global)
- **Claude Configuration**: Profile-specific `.claude.json` settings

### Environment Variables

- `ANTHROPIC_API_KEY` - Your Anthropic API key
- `NODE_ENV` - Node environment (default: production)

## 🏗️ Architecture

ClaudeBox creates a per-project Debian-based Docker image with:
- Node.js (via NVM for version flexibility)
- Claude Code CLI (@anthropic-ai/claude-code)
- User account matching host UID/GID
- Network firewall (project-specific allowlists)
- Volume mounts for workspace and configuration
- GitHub CLI (gh) for repository operations
- Delta for enhanced git diffs (version 0.17.0)
- uv for fast Python package management
- Nala for improved apt package management
- fzf for fuzzy finding
- zsh with oh-my-zsh and powerline theme
- Profile-specific development tools with intelligent layer caching
- Persistent project state (auth, history, configs)

## 🔍 Shell Script Linting

ClaudeBox shell scripts are linted with ShellCheck. Here's the workflow for fixing linting issues:

### Quick Check

```bash
# Run the same check CI uses
shellcheck -x --severity=warning main.sh lib/*.sh

# Check a single file with all warnings (including info level)
shellcheck -x lib/commands.sh
```

### Recommended Tools

Install these tools for comprehensive shell script maintenance:

```bash
# macOS
brew install shellcheck shfmt shellharden

# Ubuntu/Debian
sudo apt-get install shellcheck
# shfmt: download from https://github.com/mvdan/sh/releases
# shellharden: cargo install shellharden
```

| Tool | Purpose | When to Use |
|------|---------|-------------|
| **shellcheck** | Linter - finds bugs and issues | Always run first |
| **shfmt** | Formatter - fixes indentation/whitespace | Before other fixes |
| **shellharden** | Auto-fixes quoting issues | After fixing word-splitting patterns |

### Fixing Common Issues

#### SC2155: Declare and assign separately

```bash
# Bad - masks return value
local foo=$(some_command)

# Good - preserves exit code
local foo
foo=$(some_command)
```

**Exception**: `readonly` variables cannot be split (must use directive):
```bash
# shellcheck disable=SC2155 # readonly vars must be assigned at declaration
readonly SCRIPT_PATH="$(get_script_path)"
```

#### SC2034: Unused variable (false positives)

Variables used dynamically (via `eval`, indirect reference, or exported for subshells) trigger false positives:
```bash
# shellcheck disable=SC2034 # Used via indirect reference
local config_value="$1"
```

#### Word-Splitting Patterns

Before running `shellharden`, refactor intentional word-splitting:

```bash
# Bad - relies on word splitting (shellharden will break this)
for item in $(get_items); do

# Good - explicit line-by-line reading
while IFS= read -r item; do
    # ...
done < <(get_items)

# Or use readarray for bash 4+
readarray -t items < <(get_items)
```

### Recommended Workflow

```bash
# 1. Format first (4-space indent, case statement indent)
shfmt -i 4 -ci -w lib/*.sh main.sh

# 2. Fix word-splitting patterns manually (see above)

# 3. Apply shellharden quoting fixes (safe after step 2)
shellharden --replace lib/*.sh main.sh

# 4. Fix SC2155 (we have a script for this)
python scripts/fix_sc2155.py lib/*.sh main.sh

# 5. Add directives for remaining false positives
# Use line-level directives with explanatory comments
```

### Directive Placement

Directives must be on the line they apply to:

```bash
# For single-line declarations:
# shellcheck disable=SC2034 # Reason here
local unused_var="value"

# For split declaration/assignment, put on the ASSIGNMENT line:
local my_var
# shellcheck disable=SC2034 # Reason here
my_var=$(some_command)
```

### CI Configuration

CI uses `--severity=warning` to skip info-level suggestions:
- **error/warning**: Real issues that should be fixed
- **info**: Suggestions like "use find instead of ls" - often too pedantic

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🐛 Troubleshooting

### Docker Permission Issues
ClaudeBox automatically handles Docker setup, but if you encounter issues:
1. The script will add you to the docker group
2. You may need to log out/in or run `newgrp docker`
3. Run `claudebox` again

### Profile Installation Failed
```bash
# Clean and rebuild for current project
claudebox clean --project
claudebox rebuild
claudebox profile <name>
```

### Profile Changes Not Taking Effect
ClaudeBox automatically detects profile changes and rebuilds when needed. If you're having issues:
```bash
# Force rebuild
claudebox rebuild
```

### Python Virtual Environment Issues
ClaudeBox automatically creates a venv when Python profile is active:
```bash
# The venv is created at ~/.claudebox/<project>/.venv
# It's automatically activated in the container
claudebox shell
which python  # Should show the venv python
```

### Can't Find Command
Ensure the symlink was created:
```bash
ls -la ~/.local/bin/claudebox
# Or manually create it
ln -s /path/to/claudebox ~/.local/bin/claudebox
```

### Multiple Instance Conflicts
Each project has its own Docker image and is fully isolated. To check status:
```bash
# Check all ClaudeBox images and containers
claudebox info

# Clean project-specific data
claudebox clean --project
```

### Build Cache Issues
If builds are slow or failing:
```bash
# Clear Docker build cache
claudebox clean --cache

# Complete cleanup and rebuild
claudebox clean --all
claudebox
```

## 🎉 Acknowledgments

- [Anthropic](https://www.anthropic.com/) for Claude AI
- [Model Context Protocol](https://github.com/anthropics/model-context-protocol) for MCP servers
- Docker community for containerization tools
- All the open-source projects included in the profiles

---

Made with ❤️ for developers who love clean, reproducible environments

## Contact

**Author/Maintainer:** RchGrav  
**GitHub:** [@RchGrav](https://github.com/RchGrav)
