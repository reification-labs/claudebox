#!/usr/bin/env bash
# Command Module Loader and Reference
# ============================================================================
# This is the central command management system for ClaudeBox.
# All command implementations are organized into logical modules below.

# ============================================================================
# CORE COMMANDS - Essential ClaudeBox operations
# ============================================================================
# Commands: help, shell, update
# - help: Shows ClaudeBox help and Claude CLI help
# - shell: Opens an interactive shell in the container
# - update: Updates Claude CLI and optionally ClaudeBox itself
# shellcheck source=commands.core.sh  # Dynamic path, file exists at runtime
source "${LIB_DIR}/commands.core.sh"

# ============================================================================
# ENV COMMANDS - Development environment management
# ============================================================================
# Router: claudebox env <subcommand>
# Subcommands: list, add, remove, install
# - list: Lists all available development environments
# - add: Adds development environments to the project
# - remove: Removes environments from the project
# - install: Installs additional apt packages
# shellcheck source=commands.env.sh
source "${LIB_DIR}/commands.env.sh"

# ============================================================================
# PROFILE COMMANDS - Container profile management
# ============================================================================
# Router: claudebox profile <subcommand>
# Subcommands: list, create, run, remove, kill
# - list: Lists all container profiles for the project
# - create: Creates a new container profile for parallel instances
# - run: Launches a specific numbered profile
# - remove: Removes container profiles
# - kill: Kills running containers
# shellcheck source=commands.profile.sh
source "${LIB_DIR}/commands.profile.sh"

# ============================================================================
# INFO COMMANDS - Information display
# ============================================================================
# Commands: info, projects, allowlist
# - info: Shows comprehensive project and system information
# - projects: Lists all ClaudeBox projects system-wide
# - allowlist: Shows/manages the firewall allowlist
# - mount: Shows/manages custom volume mounts
# shellcheck source=commands.info.sh
source "${LIB_DIR}/commands.info.sh"

# ============================================================================
# CLEAN COMMANDS - Cleanup and maintenance
# ============================================================================
# Commands: clean, undo, redo
# - clean: Various cleanup operations (containers, images, cache, etc.)
# - undo: Restores the oldest backup of claudebox script
# - redo: Restores the newest backup of claudebox script
# shellcheck source=commands.clean.sh
source "${LIB_DIR}/commands.clean.sh"

# ============================================================================
# SYSTEM COMMANDS - System utilities and special features
# ============================================================================
# Commands: save, unlink, rebuild, tmux, project
# - save: Saves default command-line flags
# - unlink: Removes the claudebox symlink
# - rebuild: Forces a Docker image rebuild
# - tmux: Launches ClaudeBox with tmux support
# - project: Opens a project by name from anywhere
# shellcheck source=commands.system.sh
source "${LIB_DIR}/commands.system.sh"

# ============================================================================
# MIGRATION - Migrate from old global to new project-local structure
# ============================================================================
# Commands: migrate
# - migrate: Migrate old ~/.claudebox/projects/ to $PROJECT/.claudebox/profiles/
# shellcheck source=migrate.sh
source "${LIB_DIR}/migrate.sh"

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Show menu when no profiles exist
show_no_slots_menu() {
    logo_small
    echo
    cecho "No available profiles found" "$YELLOW"
    echo
    printf "To continue, you'll need an available container profile.\n"
    echo
    printf "  ${CYAN}claudebox profile create${NC}  - Create a new profile\n"
    printf "  ${CYAN}claudebox profile list${NC}    - View existing profiles\n"
    echo
    printf "  ${DIM}Hint: Create multiple profiles to run parallel authenticated${NC}\n"
    printf "  ${DIM}Claude sessions in the same project.${NC}\n"
    echo
    exit 1
}

# Show menu when no ready profiles are available
show_no_ready_slots_menu() {
    logo_small
    printf '\n'
    cecho "No ready profiles available!" "$YELLOW"
    printf '\n'
    printf '%s\n' "You must have at least one profile that is authenticated and inactive."
    printf '\n'
    printf '%s\n' "Run 'claudebox profile list' to check your profiles"
    printf '%s\n' "Run 'claudebox profile create' to create a new profile"
    printf '\n'
    printf '%s\n' "To use a specific profile: claudebox profile run <number>"
    printf '\n'
}

# Show help function
# shellcheck disable=SC2120 # Parameters are optional, callers may omit them
show_help() {
    # Optional parameters
    local message="${1:-}"
    local footer="${2:-}"

    # ClaudeBox specific commands
    local our_commands="  env list                        List available development environments
  env add <envs...>               Add development environments
  env remove <envs...>            Remove development environments
  env install <packages>          Install apt packages
  profile list                    List all container profiles
  profile create [name]           Create a profile (default: 'default')
  profile run [name]              Run a profile (default: 'default')
  profile remove <name>           Remove a profile by name
  profile kill [name|all]         Kill running container(s)
  projects                        List all projects with paths
  import                          Import commands from host to project
  save [flags...]                 Save default flags
  shell                           Open transient shell
  shell admin                     Open admin shell (sudo enabled)
  allowlist                       Show/edit firewall allowlist
  mount                           Show/edit custom volume mounts
  info                            Show comprehensive project info
  clean                           Menu of cleanup tasks
  project <name>                  Open project by name/hash from anywhere
  tmux                            Launch ClaudeBox with tmux support enabled"

    # Check if we're in a project directory
    local project_folder_name
    project_folder_name=$(get_project_folder_name "$PROJECT_DIR" 2>/dev/null || echo "NONE")

    if [[ "$project_folder_name" != "NONE" ]] && [[ -n "${IMAGE_NAME:-}" ]] && docker image inspect "$IMAGE_NAME" &>/dev/null; then
        # In project directory with Docker image - show brief ClaudeBox help and note about Claude commands
        echo
        logo_small
        echo
        echo "Usage: claudebox [OPTIONS] [COMMAND]"
        echo
        echo "Docker Environment for Claude CLI"
        echo
        echo "Options:"
        echo "  -h, --help                      Display help for command"
        echo "  --verbose                        Show detailed output"
        echo "  --enable-sudo                    Enable sudo without password"
        echo "  --disable-firewall               Disable network restrictions"
        echo
        echo "ClaudeBox Commands:"
        echo "$our_commands"
        echo
        cecho "For Claude CLI commands, run:" "$CYAN"
        cecho "  claudebox help claude" "$CYAN"
        echo
        cecho "For full command reference, run:" "$CYAN"
        cecho "  claudebox help full" "$CYAN"
        echo
    else
        # No Docker image - show compact menu
        echo
        logo_small
        echo
        echo "Usage: claudebox [OPTIONS] [COMMAND]"
        echo
        if [[ -n "$message" ]]; then
            echo "$message"
        else
            echo "Docker Environment for Claude CLI"
        fi
        echo
        echo "Options:"
        echo "  -h, --help                      Display help for command"
        echo "  --verbose                        Show detailed output"
        echo "  --enable-sudo                    Enable sudo without password"
        echo "  --disable-firewall               Disable network restrictions"
        echo
        echo "Commands:"
        echo "$our_commands"
        echo
        if [[ -n "$footer" ]]; then
            cecho "$footer" "$YELLOW"
            echo
        fi
    fi
}

# Show Claude help (runs Claude's help in container)
show_claude_help() {
    if [[ -n "${IMAGE_NAME:-}" ]] && docker image inspect "$IMAGE_NAME" &>/dev/null; then
        # Get Claude's help and just change claude to claudebox in the header
        local claude_help
        claude_help=$(docker run --rm "$IMAGE_NAME" claude --help 2>&1 | grep -v "iptables")

        # Just change claude to claudebox in the first line
        local processed_help
        processed_help=$(echo "$claude_help" | sed '1s/claude/claudebox/g')

        # Output everything at once
        echo
        logo_small
        echo
        echo "$processed_help"
    else
        error "No Docker image found for this project. Run 'claudebox' first to build the image."
    fi
}

# Show full combined help
show_full_help() {
    if [[ -n "${IMAGE_NAME:-}" ]] && docker image inspect "$IMAGE_NAME" &>/dev/null; then
        # Get Claude's help and blend our additions
        local claude_help
        claude_help=$(docker run --rm "$IMAGE_NAME" claude --help 2>&1 | grep -v "iptables")

        # Process and combine everything in memory
        local full_help
        full_help=$(echo "$claude_help" |
            sed '1s/claude/claudebox/g' |
            sed '/^Commands:/i\
  --verbose                        Show detailed output\
  --enable-sudo                    Enable sudo without password\
  --disable-firewall               Disable network restrictions\
' |
            sed '$ a\
  env list                        List available development environments\
  env add <envs...>               Add development environments\
  env remove <envs...>            Remove development environments\
  env install <packages>          Install apt packages\
  profile list                    List all container profiles\
  profile create [name]           Create a profile (default: "default")\
  profile run [name]              Run a profile (default: "default")\
  profile remove <name>           Remove a profile by name\
  profile kill [name|all]         Kill running container(s)\
  projects                        List all projects with paths\
  import                          Import commands from host to project\
  save [flags...]                 Save default flags\
  shell                           Open transient shell\
  shell admin                     Open admin shell (sudo enabled)\
  allowlist                       Show/edit firewall allowlist\
  mount                           Show/edit custom volume mounts\
  info                            Show comprehensive project info\
  clean                           Menu of cleanup tasks\
  project <name>                  Open project by name/hash from anywhere\
  tmux                            Launch ClaudeBox with tmux support enabled')

        # Output everything at once
        echo
        logo_small
        echo
        echo "$full_help"
    else
        # No Docker image - show compact menu (same as show_help)
        show_help
    fi
}

# Forward unknown commands to container
_forward_to_container() {
    run_claudebox_container "" "interactive" "$@"
}

# ============================================================================
# MAIN DISPATCHER
# ============================================================================
# Routes commands to their handlers based on the parsed CLI_SCRIPT_COMMAND
dispatch_command() {
    local cmd="${1:-}"
    shift || true
    if [[ "$VERBOSE" == "true" ]]; then
        echo "[DEBUG] dispatch_command called with: cmd='$cmd' remaining args='$*'" >&2
    fi

    case "$cmd" in
        # Core commands
        help | -h | --help) _cmd_help "$@" ;;
        shell) _cmd_shell "$@" ;;
        update) _cmd_update "$@" ;;

        # Env router (development environments)
        env) _cmd_env "$@" ;;

        # Profile router (container profiles)
        profile) _cmd_profile "$@" ;;

        # Info commands
        projects) _cmd_projects "$@" ;;
        allowlist) _cmd_allowlist "$@" ;;
        mount) _cmd_mount "$@" ;;
        info) _cmd_info "$@" ;;

        # Clean commands
        clean) _cmd_clean "$@" ;;
        undo) _cmd_undo "$@" ;;
        redo) _cmd_redo "$@" ;;

        # System commands
        save) _cmd_save "$@" ;;
        unlink) _cmd_unlink "$@" ;;
        rebuild) _cmd_rebuild "$@" ;;
        tmux) _cmd_tmux "$@" ;;
        project) _cmd_project "$@" ;;
        import) _cmd_import "$@" ;;

        # Migration
        migrate) _cmd_migrate "$@" ;;

        # Backward compatibility aliases (deprecated slot commands)
        slots)
            warn "Note: 'claudebox slots' is deprecated. Use 'claudebox profile list' instead."
            _cmd_profile list "$@"
            ;;
        slot)
            warn "Note: 'claudebox slot' is deprecated. Use 'claudebox profile run' instead."
            _cmd_profile run "$@"
            ;;
        create)
            warn "Note: 'claudebox create' is deprecated. Use 'claudebox profile create' instead."
            _cmd_profile create "$@"
            ;;
        revoke)
            warn "Note: 'claudebox revoke' is deprecated. Use 'claudebox profile remove' instead."
            _cmd_profile remove "$@"
            ;;
        kill)
            warn "Note: 'claudebox kill' is deprecated. Use 'claudebox profile kill' instead."
            _cmd_profile kill "$@"
            ;;

        # Backward compatibility aliases (deprecated dev profile commands)
        profiles)
            warn "Note: 'claudebox profiles' is deprecated. Use 'claudebox env list' instead."
            _cmd_env list "$@"
            ;;
        add)
            warn "Note: 'claudebox add' is deprecated. Use 'claudebox env add' instead."
            _cmd_env add "$@"
            ;;
        remove)
            warn "Note: 'claudebox remove' is deprecated. Use 'claudebox env remove' instead."
            _cmd_env remove "$@"
            ;;
        install)
            warn "Note: 'claudebox install' is deprecated. Use 'claudebox env install' instead."
            _cmd_env install "$@"
            ;;

        # Special commands that modify container
        config | mcp | migrate-installer)
            _cmd_special "$cmd" "$@"
            ;;

        # Unknown command - forward to Claude in container
        *) _forward_to_container "$cmd" "$@" ;;
    esac

    local exit_code=$?
    if [[ "$VERBOSE" == "true" ]]; then
        echo "[DEBUG] dispatch_command returning with exit code: $exit_code" >&2
    fi
    return "$exit_code"
}

# Export all public functions
export -f dispatch_command show_help show_claude_help show_full_help show_no_slots_menu show_no_ready_slots_menu _forward_to_container
