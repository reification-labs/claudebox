#!/usr/bin/env bash
# Environment Commands - Development environment management
# ============================================================================
# Router: claudebox env <subcommand>
# Subcommands: list, add, remove, install
# Manages development tools and packages in containers

# ----------------------------------------------------------------------------
# SUBCOMMANDS
# ----------------------------------------------------------------------------

_env_list() {
    # Get current envs (still uses profile functions internally)
    local current_envs=()
    readarray -t current_envs < <(get_current_profiles)

    # Show logo first
    logo_small
    printf '\n'

    # Show commands at the top
    printf '%s\n' "Commands:"
    printf "  ${CYAN}claudebox env add <envs...>${NC}    - Add development environments\n"
    printf "  ${CYAN}claudebox env remove <envs...>${NC} - Remove environments\n"
    printf '\n'

    # Show currently enabled envs
    if [[ ${#current_envs[@]} -gt 0 ]]; then
        cecho "Currently enabled:" "$YELLOW"
        printf "  %s\n" "${current_envs[*]}"
        printf '\n'
    fi

    # Show available envs
    cecho "Available environments:" "$CYAN"
    printf '\n'
    while IFS= read -r env; do
        local desc
        desc=$(get_profile_description "$env")
        local is_enabled=false
        # Check if env is currently enabled
        for enabled in "${current_envs[@]}"; do
            if [[ "$enabled" == "$env" ]]; then
                is_enabled=true
                break
            fi
        done
        printf "  ${GREEN}%-15s${NC} " "$env"
        if [[ "$is_enabled" == "true" ]]; then
            printf "${GREEN}✓${NC} "
        else
            printf "  "
        fi
        printf "%s\n" "$desc"
    done < <(get_all_profile_names | tr ' ' '\n' | sort)
    printf '\n'
}

_env_add() {
    # Environment management doesn't need a profile, just the parent directory
    init_project_dir "$PROJECT_DIR"
    local profile_file
    profile_file=$(get_profile_file_path)

    # Check for special subcommands
    case "${1:-}" in
        status | --status | -s)
            cecho "Project: $PROJECT_DIR" "$CYAN"
            echo
            if [[ -f "$profile_file" ]]; then
                local current_envs=()
                while IFS= read -r line; do
                    [[ -n "$line" ]] && current_envs+=("$line")
                done < <(read_profile_section "$profile_file" "profiles")
                if [[ ${#current_envs[@]} -gt 0 ]]; then
                    cecho "Active environments: ${current_envs[*]}" "$GREEN"
                else
                    cecho "No environments installed" "$YELLOW"
                fi

                local current_packages=()
                while IFS= read -r line; do
                    [[ -n "$line" ]] && current_packages+=("$line")
                done < <(read_profile_section "$profile_file" "packages")
                if [[ ${#current_packages[@]} -gt 0 ]]; then
                    echo "Extra packages: ${current_packages[*]}"
                fi
            else
                cecho "No environments configured for this project" "$YELLOW"
            fi
            return 0
            ;;
    esac

    # Process environment names (still uses profile_exists internally)
    local selected=() remaining=()
    while [[ $# -gt 0 ]]; do
        # Stop processing if we hit a flag (starts with -)
        if [[ "$1" == -* ]]; then
            remaining=("$@")
            break
        fi

        if profile_exists "$1"; then
            selected+=("$1")
            shift
        else
            remaining=("$@")
            break
        fi
    done

    [[ ${#selected[@]} -eq 0 ]] && error "No valid environments specified\nRun 'claudebox env list' to see available environments"

    update_profile_section "$profile_file" "profiles" "${selected[@]}"

    local all_envs=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && all_envs+=("$line")
    done < <(read_profile_section "$profile_file" "profiles")

    cecho "Project: $PROJECT_DIR" "$CYAN"
    cecho "Adding environments: ${selected[*]}" "$PURPLE"
    if [[ ${#all_envs[@]} -gt 0 ]]; then
        cecho "All active environments: ${all_envs[*]}" "$GREEN"
    fi
    echo

    # Check if any Python-related envs were added
    local python_envs_added=false
    for env in "${selected[@]}"; do
        if [[ "$env" == "python" ]] || [[ "$env" == "ml" ]] || [[ "$env" == "datascience" ]]; then
            python_envs_added=true
            break
        fi
    done

    # If Python envs were added, remove the pydev flag to trigger reinstall
    if [[ "$python_envs_added" == "true" ]]; then
        local parent_dir
        parent_dir=$(get_parent_dir "$PROJECT_DIR")
        if [[ -f "$parent_dir/.pydev_flag" ]]; then
            rm -f "$parent_dir/.pydev_flag"
            info "Python packages will be updated on next run"
        fi
    fi

    # Only show rebuild message for non-Python envs
    local needs_rebuild=false
    for env in "${selected[@]}"; do
        if [[ "$env" != "python" ]] && [[ "$env" != "ml" ]] && [[ "$env" != "datascience" ]]; then
            needs_rebuild=true
            break
        fi
    done

    if [[ "$needs_rebuild" == "true" ]]; then
        warn "The Docker image will be rebuilt with new environments on next run."
    fi
    echo

    if [[ ${#remaining[@]} -gt 0 ]]; then
        set -- "${remaining[@]}"
    fi
}

_env_remove() {
    # Environment management doesn't need a profile, just the parent directory
    init_project_dir "$PROJECT_DIR"
    local profile_file
    profile_file=$(get_profile_file_path)

    # Read current envs
    local current_envs=()
    if [[ -f "$profile_file" ]]; then
        while IFS= read -r line; do
            [[ -n "$line" ]] && current_envs+=("$line")
        done < <(read_profile_section "$profile_file" "profiles")
    fi

    # Show currently enabled envs if no arguments
    if [[ $# -eq 0 ]]; then
        if [[ ${#current_envs[@]} -gt 0 ]]; then
            cecho "Currently Enabled Environments:" "$YELLOW"
            echo -e "  ${current_envs[*]}"
            echo
            echo "Usage: claudebox env remove <env1> [env2] ..."
        else
            echo "No environments currently enabled."
        fi
        return 1
    fi

    # Get list of envs to remove
    local to_remove=()
    while [[ $# -gt 0 ]]; do
        # Stop processing if we hit a flag (starts with -)
        if [[ "$1" == -* ]]; then
            break
        fi

        if profile_exists "$1"; then
            to_remove+=("$1")
            shift
        else
            # Also stop if we hit an unknown env
            # This prevents consuming Claude args as env names
            break
        fi
    done

    [[ ${#to_remove[@]} -eq 0 ]] && error "No valid environments specified to remove"

    # Remove specified envs
    local new_envs=()
    local python_envs_removed=false
    for env in "${current_envs[@]}"; do
        local keep=true
        for remove in "${to_remove[@]}"; do
            if [[ "$env" == "$remove" ]]; then
                keep=false
                # Check if we're removing a Python-related env
                if [[ "$env" == "python" ]] || [[ "$env" == "ml" ]] || [[ "$env" == "datascience" ]]; then
                    python_envs_removed=true
                fi
                break
            fi
        done
        [[ "$keep" == "true" ]] && new_envs+=("$env")
    done

    # Check if any Python-related envs remain
    local has_python_envs=false
    for env in "${new_envs[@]}"; do
        if [[ "$env" == "python" ]] || [[ "$env" == "ml" ]] || [[ "$env" == "datascience" ]]; then
            has_python_envs=true
            break
        fi
    done

    # If we removed Python envs and no Python envs remain, clean up Python flags
    if [[ "$python_envs_removed" == "true" ]] && [[ "$has_python_envs" == "false" ]]; then
        init_project_dir "$PROJECT_DIR"
        PROJECT_PARENT_DIR=$(get_parent_dir "$PROJECT_DIR")

        # Remove Python flags and venv folder if they exist
        if [[ -f "$PROJECT_PARENT_DIR/.venv_flag" ]]; then
            rm -f "$PROJECT_PARENT_DIR/.venv_flag"
        fi
        if [[ -f "$PROJECT_PARENT_DIR/.pydev_flag" ]]; then
            rm -f "$PROJECT_PARENT_DIR/.pydev_flag"
        fi
        if [[ -d "$PROJECT_PARENT_DIR/.venv" ]]; then
            rm -rf "$PROJECT_PARENT_DIR/.venv"
        fi

        cecho "Cleaned up Python environment flags and venv folder" "$YELLOW"
    fi

    # Write back the filtered envs
    {
        echo "[profiles]"
        for env in "${new_envs[@]}"; do
            echo "$env"
        done
        echo ""

        # Preserve packages section if it exists
        if [[ -f "$profile_file" ]] && grep -q "^\[packages\]" "$profile_file"; then
            echo "[packages]"
            while IFS= read -r line; do
                echo "$line"
            done < <(read_profile_section "$profile_file" "packages")
        fi
    } >"${profile_file}.tmp" && mv "${profile_file}.tmp" "$profile_file"

    cecho "Project: $PROJECT_DIR" "$CYAN"
    cecho "Removed environments: ${to_remove[*]}" "$PURPLE"
    if [[ ${#new_envs[@]} -gt 0 ]]; then
        cecho "Remaining environments: ${new_envs[*]}" "$GREEN"
    else
        cecho "No environments remaining" "$YELLOW"
    fi
    echo
    warn "The Docker image will be rebuilt with updated environments on next run."
    echo
}

_env_install() {
    [[ $# -eq 0 ]] && error "No packages specified. Usage: claudebox env install <package1> <package2> ..."

    local profile_file
    profile_file=$(get_profile_file_path)

    update_profile_section "$profile_file" "packages" "$@"

    local all_packages=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && all_packages+=("$line")
    done < <(read_profile_section "$profile_file" "packages")

    cecho "Project: $PROJECT_DIR" "$CYAN"
    cecho "Installing packages: $*" "$PURPLE"
    if [[ ${#all_packages[@]} -gt 0 ]]; then
        cecho "All packages: ${all_packages[*]}" "$GREEN"
    fi
    echo
}

_env_help() {
    logo_small
    echo
    cecho "ClaudeBox Environment Management:" "$CYAN"
    echo
    echo -e "  ${GREEN}claudebox env list${NC}              Show all available environments"
    echo -e "  ${GREEN}claudebox env add <names...>${NC}    Add development environments"
    echo -e "  ${GREEN}claudebox env remove <names...>${NC} Remove development environments"
    echo -e "  ${GREEN}claudebox env install <pkgs...>${NC} Install apt packages"
    echo -e "  ${GREEN}claudebox env add status${NC}        Show current project's environments"
    echo
    cecho "Examples:" "$YELLOW"
    echo "  claudebox env list              # See all available environments"
    echo "  claudebox env add python rust   # Add Python and Rust environments"
    echo "  claudebox env remove rust       # Remove Rust environment"
    echo "  claudebox env install vim htop  # Install apt packages"
    echo
}

# ----------------------------------------------------------------------------
# ROUTER
# ----------------------------------------------------------------------------

_cmd_env() {
    local subcmd="${1:-}"
    shift || true

    case "$subcmd" in
        list) _env_list "$@" ;;
        add) _env_add "$@" ;;
        remove) _env_remove "$@" ;;
        install) _env_install "$@" ;;
        help | --help | -h | "")
            _env_help
            ;;
        *)
            error "Unknown subcommand: $subcmd\nRun 'claudebox env help' for usage"
            ;;
    esac
}

export -f _cmd_env _env_list _env_add _env_remove _env_install _env_help
