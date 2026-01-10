#!/usr/bin/env bash
# Info Commands - Information display
# ============================================================================
# Commands: info, projects, allowlist
# Shows system, project, and configuration information

_cmd_projects() {
    cecho "ClaudeBox Projects:" "$CYAN"
    echo
    printf "%10s  %s  %s\n" "Size" "🐳" "Path"
    printf "%10s  %s  %s\n" "----" "--" "----"

    if ! list_all_projects; then
        echo
        warn "No ClaudeBox projects found."
        echo
        cecho "Start a new project:" "$GREEN"
        echo "  cd /your/project/directory"
        echo "  claudebox"
    fi
    echo
    exit 0
}

_cmd_allowlist() {
    # Allowlist is stored in parent directory, not slot directory
    local allowlist_file="$PROJECT_PARENT_DIR/allowlist"

    cecho "🔒 ClaudeBox Firewall Allowlist" "$CYAN"
    echo
    cecho "Current Project: $PROJECT_DIR" "$WHITE"
    echo

    if [[ -f "$allowlist_file" ]]; then
        cecho "Allowlist file:" "$GREEN"
        echo "  $allowlist_file"
        echo
        cecho "Allowed domains:" "$CYAN"
        # Display allowlist contents
        while IFS= read -r line; do
            if [[ -n "$line" ]] && [[ ! "$line" =~ ^#.* ]]; then
                echo "  $line"
            fi
        done <"$allowlist_file"
        echo
    else
        cecho "Allowlist file:" "$YELLOW"
        echo "  Not yet created (will be created on first run)"
        echo "  Location: $allowlist_file"
    fi

    echo
    cecho "Default Allowed Domains:" "$CYAN"
    echo "  api.anthropic.com, console.anthropic.com, statsig.anthropic.com, sentry.io"
    echo
    cecho "To edit allowlist:" "$YELLOW"
    echo "  \$EDITOR $allowlist_file"
    echo
    cecho "Note:" "$WHITE"
    echo "  Changes take effect on next container start"
    echo "  Use --disable-firewall flag to bypass all restrictions"

    exit 0
}

_cmd_info() {
    # Compute project folder name early for paths
    local project_folder_name
    project_folder_name=$(get_project_folder_name "$PROJECT_DIR")
    IMAGE_NAME="claudebox-${project_folder_name}"
    PROJECT_SLOT_DIR="$HOME/.claudebox/projects/$project_folder_name"

    cecho "╔═══════════════════════════════════════════════════════════════════╗" "$CYAN"
    cecho "║                    ClaudeBox Information Panel                    ║" "$CYAN"
    cecho "╚═══════════════════════════════════════════════════════════════════╝" "$CYAN"
    echo

    # Current Project Info
    cecho "📁 Current Project" "$WHITE"
    echo "   Path:       $PROJECT_DIR"
    echo "   Project ID: $project_folder_name"
    echo "   Data Dir:   $PROJECT_SLOT_DIR"
    echo

    # ClaudeBox Installation
    cecho "📦 ClaudeBox Installation" "$WHITE"
    echo "   Script:  $SCRIPT_PATH"
    echo "   Symlink: $LINK_TARGET"
    echo

    # Saved CLI Flags
    cecho "🚀 Saved CLI Flags" "$WHITE"
    if [[ -f "$HOME/.claudebox/default-flags" ]]; then
        local saved_flags=()
        while IFS= read -r flag; do
            [[ -n "$flag" ]] && saved_flags+=("$flag")
        done <"$HOME/.claudebox/default-flags"
        if [[ ${#saved_flags[@]} -gt 0 ]]; then
            echo -e "   Flags: ${GREEN}${saved_flags[*]}${NC}"
        else
            echo -e "   ${YELLOW}No flags saved${NC}"
        fi
    else
        echo -e "   ${YELLOW}No saved flags${NC}"
    fi
    echo

    # Claude Commands
    cecho "📝 Claude Commands" "$WHITE"
    local cmd_count=0
    if [[ -d "$HOME/.claude/commands" ]]; then
        cmd_count=$(ls -1 "$HOME/.claude/commands"/*.md 2>/dev/null | wc -l)
    fi
    local project_cmd_count=0
    if [[ -e "$PROJECT_PARENT_DIR/commands" ]]; then
        project_cmd_count=$(ls -1 "$PROJECT_PARENT_DIR/commands"/*.md 2>/dev/null | wc -l)
    fi

    if [[ $cmd_count -gt 0 ]] || [[ $project_cmd_count -gt 0 ]]; then
        echo "   Host:    $cmd_count command(s)"
        if [[ $cmd_count -gt 0 ]] && [[ -d "$HOME/.claude/commands" ]]; then
            for cmd_file in "$HOME/.claude/commands"/*.md; do
                [[ -f "$cmd_file" ]] || continue
                echo "            - $(basename "$cmd_file" .md)"
            done
        fi
        echo "   Project: $project_cmd_count command(s) (shared)"
        if [[ $project_cmd_count -gt 0 ]] && [[ -e "$PROJECT_PARENT_DIR/commands" ]]; then
            for cmd_file in "$PROJECT_PARENT_DIR/commands"/*.md; do
                [[ -f "$cmd_file" ]] || continue
                echo "            - $(basename "$cmd_file" .md)"
            done
        fi
    else
        echo -e "   ${YELLOW}No custom commands found${NC}"
        echo -e "   Location: ~/.claude/commands/ (host), project/commands/ (shared)"
    fi
    echo

    # Project Profiles
    cecho "🛠️ Project Profiles & Packages" "$WHITE"
    local current_profile_file
    current_profile_file=$(get_profile_file_path)
    if [[ -f "$current_profile_file" ]]; then
        local current_profiles=()
        while IFS= read -r line; do
            [[ -n "$line" ]] && current_profiles+=("$line")
        done < <(read_profile_section "$current_profile_file" "profiles")
        local current_packages=()
        while IFS= read -r line; do
            [[ -n "$line" ]] && current_packages+=("$line")
        done < <(read_profile_section "$current_profile_file" "packages")

        if [[ ${#current_profiles[@]} -gt 0 ]]; then
            echo -e "   Installed:  ${GREEN}${current_profiles[*]}${NC}"
        else
            echo -e "   Installed:  ${YELLOW}None${NC}"
        fi

        if [[ ${#current_packages[@]} -gt 0 ]]; then
            echo "   Packages:   ${current_packages[*]}"
        fi
    else
        echo -e "   Status:     ${YELLOW}No profiles installed${NC}"
    fi

    echo -e "   Available:  ${CYAN}core${NC}, python, c, rust, go, flutter, javascript, java, ruby, php"
    echo -e "               database, devops, web, ml, security, embedded, networking"
    echo -e "   ${CYAN}Hint:${NC} Run 'claudebox profile' for profile help "
    echo

    cecho "🐳 Docker Status" "$WHITE"
    if [[ -n "${IMAGE_NAME:-}" ]] && docker image inspect "$IMAGE_NAME" &>/dev/null; then
        local image_info
        image_info=$(docker images --filter "reference=$IMAGE_NAME" --format "{{.Size}}")
        echo -e "   Image:      ${GREEN}Ready${NC} ($IMAGE_NAME - $image_info)"

        local image_created
        image_created=$(docker inspect "$IMAGE_NAME" --format '{{.Created}}' | cut -d'T' -f1)
        local layer_count
        layer_count=$(docker history "$IMAGE_NAME" --no-trunc --format "{{.CreatedBy}}" | wc -l)
        echo "   Created:    $image_created"
        echo "   Layers:     $layer_count"
    else
        echo -e "   Image:      ${YELLOW}Not built${NC}"
    fi

    local running_containers
    running_containers=$(docker ps --filter "ancestor=$IMAGE_NAME" -q 2>/dev/null)
    if [[ -n "$running_containers" ]]; then
        local container_count
        container_count=$(echo "$running_containers" | wc -l)
        echo -e "   Containers: ${GREEN}$container_count running${NC}"

        while IFS= read -r container_id; do
            local container_stats
            container_stats="$(docker stats --no-stream --format "{{.Container}}: {{.CPUPerc}} CPU, {{.MemUsage}}" "$container_id" 2>/dev/null || echo "")"
            if [[ -n "$container_stats" ]]; then
                echo "               - $container_stats"
            fi
        done <<< "$running_containers"
    else
        echo "   Containers: None running"
    fi
    echo

    # All Projects Summary
    cecho "📊 All Projects Summary" "$WHITE"
    local total_projects
    total_projects=$(ls -1d "$HOME/.claudebox/projects"/*/ 2>/dev/null | wc -l)
    echo "   Projects:   $total_projects total"

    local total_size
    total_size=$(docker images --filter "reference=claudebox-*" --format "{{.Size}}" | awk '{
        size=$1; unit=$2;
        if (unit == "GB") size = size * 1024;
        else if (unit == "KB") size = size / 1024;
        total += size
    } END {
        if (total > 1024) printf "%.1fGB", total/1024;
        else printf "%.1fMB", total
    }')
    local image_count
    image_count=$(docker images --filter "reference=claudebox-*" -q | wc -l)
    echo "   Images:     $image_count ClaudeBox images using $total_size"

    local docker_stats
    docker_stats=$(docker system df --format "table {{.Type}}\t{{.Total}}\t{{.Active}}\t{{.Size}}\t{{.Reclaimable}}" 2>/dev/null | tail -n +2)
    if [[ -n "$docker_stats" ]]; then
        echo "   System:"
        while IFS=$'\t' read -r type total active size reclaim; do
            echo "               - $type: $total total, $active active ($size, $reclaim reclaimable)"
        done <<<"$docker_stats"
    fi
    echo

    exit 0
}

_cmd_mount() {
    # Mounts file is stored in parent directory, not slot directory
    local mounts_file="$PROJECT_PARENT_DIR/mounts"
    local subcommand="${1:-}"
    shift || true

    # Handle subcommands
    case "$subcommand" in
        add)
            local mount_spec="${1:-}"
            if [[ -z "$mount_spec" ]]; then
                error "Usage: claudebox mount add <host_path>:<container_path>:<mode>
Examples:
  claudebox mount add /path/to/vault:/workspace/.vault/name:ro
  claudebox mount add ~/docs:/workspace/docs:ro
  claudebox mount add /tmp/scratch:/workspace/scratch:rw

Mode must be 'ro' (read-only) or 'rw' (read-write)
Note: Colons (:) in paths are not supported (used as field separator)"
            fi

            # Validate no embedded newlines (would corrupt mounts file)
            if [[ "$mount_spec" == *$'\n'* ]]; then
                error "Invalid mount specification: must not contain newline characters"
            fi

            # Validate exactly 2 colons (host:container:mode)
            local colon_count="${mount_spec//[^:]}"
            if [[ ${#colon_count} -ne 2 ]]; then
                error "Invalid mount format. Expected exactly 2 colons: <host_path>:<container_path>:<mode>
Got: $mount_spec

Colons (:) are reserved as field separators and cannot appear inside paths.
Windows users: Use WSL2 paths instead (e.g., /mnt/c/Users/... instead of C:\\Users\\...)"
            fi

            # Validate format: host:container:mode
            local host_path container_path mode
            IFS=':' read -r host_path container_path mode <<< "$mount_spec"

            if [[ -z "$host_path" ]] || [[ -z "$container_path" ]] || [[ -z "$mode" ]]; then
                error "Invalid mount format. Expected: <host_path>:<container_path>:<mode>
Got: $mount_spec"
            fi

            # Expand ~ in host path
            host_path="${host_path/#\~/$HOME}"

            # Validate mode
            if [[ "$mode" != "ro" ]] && [[ "$mode" != "rw" ]]; then
                error "Invalid mode '$mode'. Must be 'ro' (read-only) or 'rw' (read-write)"
            fi

            # Validate host path exists
            if [[ ! -e "$host_path" ]]; then
                warn "Warning: Host path does not exist: $host_path"
                cecho "Mount will fail at container start if path doesn't exist." "$YELLOW"
                echo
                read -p "Add anyway? (y/N) " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    info "Mount not added"
                    exit 0
                fi
            fi

            # Create mounts file if needed
            if [[ ! -f "$mounts_file" ]]; then
                mkdir -p "$(dirname "$mounts_file")"
                cat > "$mounts_file" << 'HEADER'
# ClaudeBox Custom Volume Mounts
# Format: host_path:container_path:mode
# Mode: ro (read-only) or rw (read-write)
# Lines starting with # are comments
#
# Example:
# /path/to/vault:/workspace/.vault/name:ro
HEADER
            fi

            # Check for duplicate container path (exact field match, not substring)
            if awk -F: -v cp="$container_path" '!/^#/ && $2 == cp { found=1; exit 0 } END { exit (found ? 0 : 1) }' "$mounts_file" 2>/dev/null; then
                error "A mount already exists for container path: $container_path
Use 'claudebox mount remove $container_path' first"
            fi

            # Add the mount
            echo "${host_path}:${container_path}:${mode}" >> "$mounts_file"
            success "Added mount: $host_path -> $container_path ($mode)"
            echo
            cecho "Note:" "$WHITE"
            echo "  Changes take effect on next container start"
            exit 0
            ;;

        remove)
            local target="${1:-}"
            if [[ -z "$target" ]]; then
                error "Usage: claudebox mount remove <container_path>
Example: claudebox mount remove /workspace/.vault/name"
            fi

            if [[ ! -f "$mounts_file" ]]; then
                error "No mounts configured for this project"
            fi

            # Find and remove the mount (exact field match, not substring)
            local found=false
            local temp_file
            temp_file=$(mktemp)
            while IFS= read -r line; do
                if [[ "$line" =~ ^# ]] || [[ -z "$line" ]]; then
                    echo "$line" >> "$temp_file"
                else
                    # Parse line and check container_path (field 2) exactly
                    local line_container_path
                    IFS=':' read -r _ line_container_path _ <<< "$line"
                    if [[ "$line_container_path" == "$target" ]]; then
                        found=true
                        info "Removing: $line"
                    else
                        echo "$line" >> "$temp_file"
                    fi
                fi
            done < "$mounts_file"

            if [[ "$found" == "true" ]]; then
                mv "$temp_file" "$mounts_file"
                success "Mount removed"
                echo
                cecho "Note:" "$WHITE"
                echo "  Changes take effect on next container start"
            else
                rm -f "$temp_file"
                error "No mount found for container path: $target"
            fi
            exit 0
            ;;

        "")
            # Show current mounts (default behavior)
            ;;

        *)
            error "Unknown subcommand: $subcommand
Usage:
  claudebox mount              Show configured mounts
  claudebox mount add <spec>   Add a mount (host:container:mode)
  claudebox mount remove <path> Remove a mount by container path"
            ;;
    esac

    # Show current mounts
    cecho "📁 ClaudeBox Custom Volume Mounts" "$CYAN"
    echo
    cecho "Current Project: $PROJECT_DIR" "$WHITE"
    echo

    if [[ -f "$mounts_file" ]]; then
        cecho "Mounts file:" "$GREEN"
        echo "  $mounts_file"
        echo

        # Count and display mounts
        local mount_count=0
        cecho "Configured mounts:" "$CYAN"
        while IFS= read -r line; do
            if [[ -n "$line" ]] && [[ ! "$line" =~ ^#.* ]]; then
                local host_path container_path mode
                IFS=':' read -r host_path container_path mode <<< "$line"

                # Check if host path exists (expand tilde first)
                local expanded_host_path="${host_path/#\~/$HOME}"
                local status_icon="✓"
                local status_color="$GREEN"
                if [[ ! -e "$expanded_host_path" ]]; then
                    status_icon="✗"
                    status_color="$RED"
                fi

                printf "  ${status_color}${status_icon}${NC} %s -> %s (%s)\n" "$host_path" "$container_path" "$mode"
                ((mount_count++)) || true
            fi
        done < "$mounts_file"

        if [[ $mount_count -eq 0 ]]; then
            echo "  (none configured)"
        fi
        echo
    else
        cecho "Mounts file:" "$YELLOW"
        echo "  Not yet created"
        echo "  Location: $mounts_file"
        echo
        cecho "No custom mounts configured." "$WHITE"
    fi

    echo
    cecho "Default mounts (always included):" "$CYAN"
    echo "  \$PROJECT_DIR -> /workspace (rw)"
    echo "  ~/.claudebox -> /home/claude/.claudebox (rw)"
    echo "  ~/.ssh -> /home/claude/.ssh (ro)"
    echo
    cecho "Usage:" "$YELLOW"
    echo "  claudebox mount add <host>:<container>:<mode>   Add a mount"
    echo "  claudebox mount remove <container_path>         Remove a mount"
    echo "  \$EDITOR $mounts_file                           Edit directly"
    echo
    cecho "Examples:" "$GREEN"
    echo "  claudebox mount add ~/vault:/workspace/.vault/obsidian:ro"
    echo "  claudebox mount add /tmp/data:/workspace/data:rw"
    echo
    cecho "Note:" "$WHITE"
    echo "  Changes take effect on next container start"

    exit 0
}

export -f _cmd_projects _cmd_allowlist _cmd_mount _cmd_info
