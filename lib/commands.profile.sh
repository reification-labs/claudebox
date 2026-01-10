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
    list_project_slots "$PROJECT_DIR"
    return 0
}

_profile_create() {
    # Debug: Check counter before creation
    local parent_dir
    parent_dir=$(get_parent_dir "$PROJECT_DIR")
    local counter_before
    counter_before=$(read_counter "$parent_dir")
    if [[ "$VERBOSE" == "true" ]]; then
        echo "[DEBUG] Counter before creation: $counter_before" >&2
    fi

    # Create a new profile
    local profile_name
    profile_name=$(create_container "$PROJECT_DIR")
    local profile_dir="$parent_dir/$profile_name"

    # Debug: Check counter after creation
    local counter_after
    counter_after=$(read_counter "$parent_dir")
    if [[ "$VERBOSE" == "true" ]]; then
        echo "[DEBUG] Counter after creation: $counter_after" >&2
        echo "[DEBUG] Created profile name: $profile_name" >&2
        echo "[DEBUG] Profile directory: $profile_dir" >&2
    fi

    # Show updated profiles list directly
    list_project_slots "$PROJECT_DIR"

    return 0
}

_profile_run() {
    # Extract profile number - it should be the first argument
    local profile_num="${1:-}"
    shift || true # Remove profile number from arguments

    # Validate profile number
    if [[ ! "$profile_num" =~ ^[0-9]+$ ]]; then
        error "Usage: claudebox profile run <number> [claude arguments...]"
    fi

    # Get the profile directory
    local profile_dir
    profile_dir=$(get_slot_dir "$PROJECT_DIR" "$profile_num")
    local profile_name
    profile_name=$(basename "$profile_dir")

    # Check if profile exists
    if [[ ! -d "$profile_dir" ]]; then
        error "Profile $profile_num does not exist. Run 'claudebox profile list' to see available profiles."
    fi

    # Set up environment for this specific profile
    local parent_dir
    parent_dir=$(get_parent_dir "$PROJECT_DIR")
    export PROJECT_SLOT_DIR="$profile_dir"
    export PROJECT_PARENT_DIR="$parent_dir"
    IMAGE_NAME=$(get_image_name)
    export IMAGE_NAME
    export CLAUDEBOX_SLOT_NUMBER="$profile_num"

    info "Using profile $profile_num: $profile_name"

    # Sync commands before launching container
    sync_commands_to_project "$parent_dir"

    # Now we need to run the container with the profile selected
    # Get parent folder name for container naming
    local parent_folder_name
    parent_folder_name=$(generate_parent_folder_name "$PROJECT_DIR")
    local container_name="claudebox-${parent_folder_name}-${profile_name}"

    # If we're in tmux, get the pane ID and pass it through
    local tmux_pane_id=""
    if [[ -n "${TMUX:-}" ]]; then
        tmux_pane_id=$(tmux display-message -p '#{pane_id}')
        export CLAUDEBOX_TMUX_PANE="$tmux_pane_id"
    fi

    # Run container with remaining arguments passed to claude
    run_claudebox_container "$container_name" "interactive" "$@"
}

_profile_remove() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo "[DEBUG] Starting _profile_remove with PROJECT_DIR=$PROJECT_DIR" >&2
    fi
    local parent
    parent=$(get_parent_dir "$PROJECT_DIR")
    if [[ "$VERBOSE" == "true" ]]; then
        echo "[DEBUG] parent=$parent" >&2
    fi
    local max
    max=$(read_counter "$parent")
    if [[ "$VERBOSE" == "true" ]]; then
        echo "[DEBUG] max=$max" >&2
    fi

    if [ "$max" -eq 0 ]; then
        echo "No profiles to remove"
        return 0
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        echo "[DEBUG] Checking argument: ${1:-}" >&2
    fi

    # Check for "all" argument
    if [ "${1:-}" = "all" ]; then
        if [[ "$VERBOSE" == "true" ]]; then
            echo "[DEBUG] Processing remove all" >&2
        fi
        local removed_count=0
        local existing_count=0

        # First count how many profiles actually exist
        if [[ "$VERBOSE" == "true" ]]; then
            echo "[DEBUG] Starting count loop, max=$max" >&2
        fi
        for ((idx = 1; idx <= max; idx++)); do
            if [[ "$VERBOSE" == "true" ]]; then
                echo "[DEBUG] Count loop idx=$idx" >&2
            fi
            local name
            name=$(generate_container_name "$PROJECT_DIR" "$idx")
            if [[ "$VERBOSE" == "true" ]]; then
                echo "[DEBUG] Generated name=$name" >&2
            fi
            local dir="$parent/$name"
            if [ -d "$dir" ]; then
                ((existing_count++)) || true
            fi
        done

        if [[ "$VERBOSE" == "true" ]]; then
            echo "[DEBUG] Finished count loop, existing_count=$existing_count, max=$max" >&2
        fi

        # Now remove them
        if [[ "$VERBOSE" == "true" ]]; then
            echo "[DEBUG] Starting removal loop" >&2
        fi
        for ((idx = max; idx >= 1; idx--)); do
            local name
            name=$(generate_container_name "$PROJECT_DIR" "$idx")
            local dir="$parent/$name"

            if [ -d "$dir" ]; then
                # Check if container is running
                if docker ps --format "{{.Names}}" | grep -q "^claudebox-.*-${name}$"; then
                    info "Profile $idx is in use, skipping"
                else
                    if [[ "$VERBOSE" == "true" ]]; then
                        echo "[DEBUG] Removing profile $idx: $dir" >&2
                    fi
                    if rm -rf "$dir"; then
                        ((removed_count++)) || true
                    else
                        error "Failed to remove profile $idx: $dir"
                    fi
                fi
            else
                if [[ "$VERBOSE" == "true" ]]; then
                    echo "[DEBUG] Profile $idx not found: $dir" >&2
                fi
            fi
        done

        # If we removed all existing profiles, set counter to 0
        if [[ "$VERBOSE" == "true" ]]; then
            echo "[DEBUG] removed_count=$removed_count, existing_count=$existing_count" >&2
        fi
        if [ "$removed_count" -eq "$existing_count" ]; then
            if [[ "$VERBOSE" == "true" ]]; then
                echo "[DEBUG] Setting counter to 0" >&2
            fi
            write_counter "$parent" 0
        else
            # Otherwise prune the counter
            if [[ "$VERBOSE" == "true" ]]; then
                echo "[DEBUG] Pruning counter" >&2
            fi
            prune_slot_counter "$PROJECT_DIR"
        fi

        # Show updated profiles list
        list_project_slots "$PROJECT_DIR"
    else
        # Remove highest profile only
        local name
        name=$(generate_container_name "$PROJECT_DIR" "$max")
        local dir="$parent/$name"

        if [ ! -d "$dir" ]; then
            # Profile doesn't exist, just prune the counter
            prune_slot_counter "$PROJECT_DIR"
            local new_max
            new_max=$(read_counter "$parent")
            info "Profile $max doesn't exist. Counter adjusted to $new_max"
        else
            # Check if container is running
            if docker ps --format "{{.Names}}" | grep -q "^claudebox-.*-${name}$"; then
                error "Cannot remove profile $max - it is currently in use"
            fi

            # Remove the profile
            rm -rf "$dir"
            write_counter "$parent" $((max - 1))
        fi

        # Show updated profiles list
        if [[ "$VERBOSE" == "true" ]]; then
            echo "[DEBUG] About to call list_project_slots" >&2
        fi
        list_project_slots "$PROJECT_DIR"
        if [[ "$VERBOSE" == "true" ]]; then
            echo "[DEBUG] list_project_slots returned" >&2
        fi
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        echo "[DEBUG] Exiting _profile_remove" >&2
    fi
    return 0
}

_profile_kill() {
    local target="${1:-}"

    # If no argument, show help
    if [[ -z "$target" ]]; then
        logo_small
        echo
        cecho "Kill running ClaudeBox containers:" "$CYAN"
        echo
        cecho "WARNING: This forcefully terminates containers!" "$YELLOW"
        echo

        # Show running containers with their profile hashes
        local found=false
        local parent
        parent=$(get_parent_dir "$PROJECT_DIR")
        local max
        max=$(read_counter "$parent")

        echo "Running containers in this project:"
        echo
        for ((idx = 1; idx <= max; idx++)); do
            local name
            name=$(generate_container_name "$PROJECT_DIR" "$idx")
            local full_container
            full_container="claudebox-$(basename "$parent")-${name}"

            if docker ps --format "{{.Names}}" | grep -q "^${full_container}$"; then
                printf "  Profile %d: %s\n" "$idx" "$name"
                found=true
            fi
        done

        if [[ "$found" == "false" ]]; then
            info "No running containers found"
        else
            echo
            cecho "Usage:" "$YELLOW"
            echo "  claudebox profile kill <profile-hash>  # Kill specific container"
            echo "  claudebox profile kill all             # Kill all containers"
            echo
            cecho "Example:" "$DIM"
            echo "  claudebox profile kill 337503c6    # Kill container by profile hash"
            echo "  claudebox profile kill all         # Kill all running containers"
        fi
        echo
        return 0
    fi

    # Kill all containers
    if [[ "$target" == "all" ]]; then
        local parent
        parent=$(get_parent_dir "$PROJECT_DIR")
        local project_name
        project_name=$(basename "$parent")
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

    # Kill specific container by profile hash
    local parent
    parent=$(get_parent_dir "$PROJECT_DIR")
    local project_name
    project_name=$(basename "$parent")
    local full_container="claudebox-${project_name}-${target}"

    if docker ps --format "{{.Names}}" | grep -q "^${full_container}$"; then
        warn "Killing container: $full_container"
        docker kill "$full_container" >/dev/null 2>&1 || error "Failed to kill container"
        success "Container killed"
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
    echo -e "  ${GREEN}claudebox profile list${NC}            Show all container profiles"
    echo -e "  ${GREEN}claudebox profile create${NC}          Create a new profile"
    echo -e "  ${GREEN}claudebox profile run <num>${NC}       Run a specific profile"
    echo -e "  ${GREEN}claudebox profile remove [all]${NC}    Remove profile(s)"
    echo -e "  ${GREEN}claudebox profile kill [all]${NC}      Kill running container(s)"
    echo
    cecho "Examples:" "$YELLOW"
    echo "  claudebox profile list           # See all profiles"
    echo "  claudebox profile create         # Create new profile"
    echo "  claudebox profile run 1          # Run profile #1"
    echo "  claudebox profile remove         # Remove highest profile"
    echo "  claudebox profile remove all     # Remove all profiles"
    echo "  claudebox profile kill all       # Kill all running containers"
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
