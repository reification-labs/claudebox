#!/usr/bin/env bash
# Profile Commands - Container profile management
# ============================================================================
# Router: claudebox profile <subcommand>
# Subcommands: list, create, run, remove, kill
# Manages named container instances per project

# ----------------------------------------------------------------------------
# SUBCOMMANDS
# ----------------------------------------------------------------------------

_profile_list() {
    local profiles_dir="$PROJECT_DIR/.claudebox/profiles"

    if [[ ! -d "$profiles_dir" ]]; then
        info "No profiles found. Run 'claudebox profile create' to create one."
        return 0
    fi

    local profiles
    profiles=$(find "$profiles_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)

    if [[ -z "$profiles" ]]; then
        info "No profiles found. Run 'claudebox profile create' to create one."
        return 0
    fi

    echo
    cecho "Container Profiles for $(basename "$PROJECT_DIR"):" "$CYAN"
    echo

    while IFS= read -r profile_path; do
        local name
        name=$(basename "$profile_path")
        local status="ready"

        # Check if container is running for this profile
        local container_name
        container_name="claudebox-$(basename "$PROJECT_DIR")-${name}"
        if docker ps --format "{{.Names}}" 2>/dev/null | grep -q "^${container_name}$"; then
            status="running"
        fi

        if [[ "$status" == "running" ]]; then
            printf "  ${GREEN}●${NC} %-20s ${DIM}(running)${NC}\n" "$name"
        else
            printf "  ${NC}○${NC} %-20s\n" "$name"
        fi
    done <<<"$profiles"

    echo
    return 0
}

_profile_create() {
    local name="${1:-default}"

    # Validate profile name (alphanumeric, hyphen, underscore only)
    if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        error "Invalid profile name: '$name'. Use only letters, numbers, hyphens, and underscores."
    fi

    local profile_dir
    profile_dir=$(get_profile_dir "$name")

    # Check if profile already exists
    if [[ -d "$profile_dir" ]]; then
        info "Profile '$name' already exists at: $profile_dir"
        return 0
    fi

    # Create the profile
    init_profile_dir "$name"

    if [[ "$VERBOSE" == "true" ]]; then
        echo "[DEBUG] Created profile: $name" >&2
        echo "[DEBUG] Profile directory: $profile_dir" >&2
    fi

    success "Created profile: $name"

    # Show updated profiles list
    _profile_list

    return 0
}

_profile_run() {
    local name="${1:-default}"
    shift || true # Remove profile name from arguments

    # Get the profile directory
    local profile_dir
    profile_dir=$(get_profile_dir "$name")

    # Check if profile exists
    if [[ ! -d "$profile_dir" ]]; then
        error "Profile '$name' does not exist. Run 'claudebox profile list' to see available profiles."
    fi

    # Set up environment for this specific profile
    export PROJECT_SLOT_DIR="$profile_dir"
    export PROJECT_PARENT_DIR="$PROJECT_DIR/.claudebox"
    export PROFILE_NAME="$name"
    IMAGE_NAME=$(get_image_name)
    export IMAGE_NAME

    info "Using profile: $name"

    # Sync commands before launching container
    if declare -f sync_commands_to_project >/dev/null 2>&1; then
        sync_commands_to_project "$PROJECT_DIR/.claudebox"
    fi

    # Container name uses project name + profile name
    local project_name
    project_name=$(basename "$PROJECT_DIR")
    local container_name="claudebox-${project_name}-${name}"

    # If we're in tmux, get the pane ID and pass it through
    if [[ -n "${TMUX:-}" ]]; then
        local tmux_pane_id
        tmux_pane_id=$(tmux display-message -p '#{pane_id}')
        export CLAUDEBOX_TMUX_PANE="$tmux_pane_id"
    fi

    # Run container with remaining arguments passed to claude
    run_claudebox_container "$container_name" "interactive" "$@"
}

_profile_remove() {
    local target="${1:-}"
    local profiles_dir="$PROJECT_DIR/.claudebox/profiles"
    local project_name
    project_name=$(basename "$PROJECT_DIR")

    # Check if profiles directory exists
    if [[ ! -d "$profiles_dir" ]]; then
        info "No profiles to remove"
        return 0
    fi

    # Check for "all" argument
    if [[ "$target" == "all" ]]; then
        local removed_count=0

        while IFS= read -r profile_path; do
            local name
            name=$(basename "$profile_path")
            local container_name="claudebox-${project_name}-${name}"

            # Check if container is running
            if docker ps --format "{{.Names}}" 2>/dev/null | grep -q "^${container_name}$"; then
                warn "Profile '$name' is in use, skipping"
            else
                if rm -rf "$profile_path"; then
                    success "Removed profile: $name"
                    ((removed_count++)) || true
                else
                    error "Failed to remove profile: $name"
                fi
            fi
        done < <(find "$profiles_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)

        if [[ $removed_count -eq 0 ]]; then
            info "No profiles were removed"
        fi
    elif [[ -z "$target" ]]; then
        # No argument - show help
        echo
        cecho "Remove a profile:" "$CYAN"
        echo
        echo "Usage:"
        echo "  claudebox profile remove <name>    # Remove specific profile"
        echo "  claudebox profile remove all       # Remove all profiles"
        echo
        _profile_list
        return 0
    else
        # Remove specific profile by name
        local profile_dir
        profile_dir=$(get_profile_dir "$target")

        if [[ ! -d "$profile_dir" ]]; then
            error "Profile '$target' does not exist"
        fi

        local container_name="claudebox-${project_name}-${target}"

        # Check if container is running
        if docker ps --format "{{.Names}}" 2>/dev/null | grep -q "^${container_name}$"; then
            error "Cannot remove profile '$target' - it is currently in use"
        fi

        # Remove the profile
        if rm -rf "$profile_dir"; then
            success "Removed profile: $target"
        else
            error "Failed to remove profile: $target"
        fi
    fi

    # Show updated profiles list
    _profile_list
    return 0
}

_profile_kill() {
    local target="${1:-}"
    local project_name
    project_name=$(basename "$PROJECT_DIR")
    local profiles_dir="$PROJECT_DIR/.claudebox/profiles"

    # If no argument, show running containers
    if [[ -z "$target" ]]; then
        logo_small
        echo
        cecho "Kill running ClaudeBox containers:" "$CYAN"
        echo
        cecho "WARNING: This forcefully terminates containers!" "$YELLOW"
        echo

        # Show running containers
        local found=false
        echo "Running containers in this project:"
        echo

        if [[ -d "$profiles_dir" ]]; then
            while IFS= read -r profile_path; do
                local name
                name=$(basename "$profile_path")
                local container_name="claudebox-${project_name}-${name}"

                if docker ps --format "{{.Names}}" 2>/dev/null | grep -q "^${container_name}$"; then
                    printf "  ${GREEN}●${NC} %s\n" "$name"
                    found=true
                fi
            done < <(find "$profiles_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
        fi

        if [[ "$found" == "false" ]]; then
            info "No running containers found"
        else
            echo
            cecho "Usage:" "$YELLOW"
            echo "  claudebox profile kill <name>    # Kill specific container"
            echo "  claudebox profile kill all       # Kill all containers"
        fi
        echo
        return 0
    fi

    # Kill all containers
    if [[ "$target" == "all" ]]; then
        local containers
        containers=$(docker ps --format "{{.Names}}" | grep "^claudebox-${project_name}-" || true)

        if [[ -z "$containers" ]]; then
            info "No running containers to kill"
            echo
            return 0
        fi

        warn "Killing all containers for this project..."
        echo "$containers" | while IFS= read -r container; do
            echo "  Killing: $container"
            docker kill "$container" >/dev/null 2>&1 || true
        done
        success "All containers killed"
        echo
        return 0
    fi

    # Kill specific container by profile name
    local full_container="claudebox-${project_name}-${target}"

    if docker ps --format "{{.Names}}" 2>/dev/null | grep -q "^${full_container}$"; then
        warn "Killing container: $full_container"
        docker kill "$full_container" >/dev/null 2>&1 || error "Failed to kill container"
        success "Container killed: $target"
    else
        error "Container not found: $target"
        echo "Run 'claudebox profile kill' to see running containers"
    fi
    echo
}

_profile_help() {
    logo_small
    echo
    cecho "ClaudeBox Profile Management:" "$CYAN"
    echo
    echo -e "  ${GREEN}claudebox profile list${NC}              Show all container profiles"
    echo -e "  ${GREEN}claudebox profile create [name]${NC}     Create a new profile (default: 'default')"
    echo -e "  ${GREEN}claudebox profile run [name]${NC}        Run a specific profile (default: 'default')"
    echo -e "  ${GREEN}claudebox profile remove <name>${NC}     Remove a profile by name"
    echo -e "  ${GREEN}claudebox profile remove all${NC}        Remove all profiles"
    echo -e "  ${GREEN}claudebox profile kill [name|all]${NC}   Kill running container(s)"
    echo
    cecho "Examples:" "$YELLOW"
    echo "  claudebox profile list             # See all profiles"
    echo "  claudebox profile create           # Create 'default' profile"
    echo "  claudebox profile create frontend  # Create 'frontend' profile"
    echo "  claudebox profile run              # Run 'default' profile"
    echo "  claudebox profile run backend      # Run 'backend' profile"
    echo "  claudebox profile remove frontend  # Remove 'frontend' profile"
    echo "  claudebox profile remove all       # Remove all profiles"
    echo "  claudebox profile kill all         # Kill all running containers"
    echo
}

# ----------------------------------------------------------------------------
# ROUTER
# ----------------------------------------------------------------------------

_cmd_profile() {
    local subcmd="${1:-}"
    shift || true

    case "$subcmd" in
        list) _profile_list "$@" ;;
        create) _profile_create "$@" ;;
        run) _profile_run "$@" ;;
        remove) _profile_remove "$@" ;;
        kill) _profile_kill "$@" ;;
        help | --help | -h | "")
            _profile_help
            ;;
        *)
            error "Unknown subcommand: $subcmd\nRun 'claudebox profile help' for usage"
            ;;
    esac
}

export -f _cmd_profile _profile_list _profile_create _profile_run _profile_remove _profile_kill _profile_help
