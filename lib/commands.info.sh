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
    # SECURITY: Allowlist is stored in global config (~/.claudebox), NOT project directory
    # This prevents sandbox escape via /workspace/.claudebox modification
    local allowlist_file="$HOME/.claudebox/allowlist"

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
        done <<<"$running_containers"
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

_cmd_vault() {
    # SECURITY: Vault file is stored in global config (~/.claudebox), NOT project directory
    # This prevents sandbox escape via /workspace/.claudebox modification
    local vault_file="$HOME/.claudebox/vault"
    local subcommand="${1:-}"
    shift || true

    # Handle subcommands
    case "$subcommand" in
        add)
            local host_path="${1:-}"
            if [[ -z "$host_path" ]]; then
                error "Usage: claudebox vault add <host_path>
Examples:
  claudebox vault add /path/to/my/vault
  claudebox vault add ~/docs
  claudebox vault add /home/user/obsidian

The directory will be mounted read-only at /vault/<dirname>
For example: ~/docs -> /vault/docs:ro"
            fi

            # Expand ~ in host path
            host_path="${host_path/#\~/$HOME}"

            # SECURITY: Validate path is absolute (no relative paths)
            if [[ ! "$host_path" =~ ^/ ]]; then
                error "Security: Host path must be absolute (start with /)
Got: $host_path

Use full paths like /home/user/vault or ~/vault"
            fi

            # SECURITY: Reject path traversal attempts
            if [[ "$host_path" == *".."* ]]; then
                error "Security: Path traversal not allowed (contains '..')
Got: $host_path"
            fi

            # SECURITY: Reject symlinks (could point to sensitive locations)
            if [[ -L "$host_path" ]]; then
                error "Security: Symlinks are not allowed
Got: $host_path

Symlinks could point to sensitive directories. Use the real path instead:
  $(readlink -f "$host_path" 2>/dev/null || echo "<could not resolve>")"
            fi

            # Validate host path exists and is a directory
            if [[ ! -e "$host_path" ]]; then
                warn "Warning: Path does not exist: $host_path"
                cecho "Vault mount will fail at container start if path doesn't exist." "$YELLOW"
                echo
                read -p "Add anyway? (y/N) " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    info "Vault not added"
                    exit 0
                fi
            elif [[ ! -d "$host_path" ]]; then
                error "Path must be a directory, not a file: $host_path"
            fi

            # Derive container path from directory name
            local vault_name
            vault_name=$(basename "$host_path")
            local container_path="/vault/$vault_name"

            # Create vault file if needed
            if [[ ! -f "$vault_file" ]]; then
                mkdir -p "$(dirname "$vault_file")"
                cat >"$vault_file" <<'HEADER'
# ClaudeBox Vault Mounts
# Format: host_path (one path per line)
# All mounts are read-only and appear at /vault/<dirname>
# Lines starting with # are comments
#
# Example:
# /home/user/obsidian-vault
# ~/documents
HEADER
            fi

            # Check for duplicate (same host path or same vault name)
            if grep -q "^${host_path}$" "$vault_file" 2>/dev/null; then
                error "This path is already in the vault: $host_path"
            fi

            # Check if vault name would conflict
            # Note: { grep || true; } prevents pipefail from killing script on empty vault
            local existing_conflict
            existing_conflict=$({ grep -v "^#" "$vault_file" 2>/dev/null || true; } | while read -r line; do
                [[ -z "$line" ]] && continue
                local existing_name
                existing_name=$(basename "${line/#\~/$HOME}")
                if [[ "$existing_name" == "$vault_name" ]]; then
                    echo "$line"
                    break
                fi
            done)
            if [[ -n "$existing_conflict" ]]; then
                error "A vault with name '$vault_name' already exists from: $existing_conflict
Choose a directory with a different name, or rename your directory."
            fi

            # Add the vault
            echo "$host_path" >>"$vault_file"
            success "Added vault: $host_path -> $container_path (ro)"
            echo
            cecho "Note:" "$WHITE"
            echo "  Changes take effect on next container start"
            exit 0
            ;;

        remove)
            local target="${1:-}"
            if [[ -z "$target" ]]; then
                error "Usage: claudebox vault remove <path_or_name>
Examples:
  claudebox vault remove /home/user/vault
  claudebox vault remove docs    # removes by vault name"
            fi

            if [[ ! -f "$vault_file" ]]; then
                error "No vaults configured"
            fi

            # Expand ~ if present
            target="${target/#\~/$HOME}"

            # Find and remove the vault (by full path or by name)
            local found=false
            local temp_file
            temp_file=$(mktemp)
            while IFS= read -r line; do
                if [[ "$line" =~ ^# ]] || [[ -z "$line" ]]; then
                    echo "$line" >>"$temp_file"
                else
                    local expanded_line="${line/#\~/$HOME}"
                    local line_name
                    line_name=$(basename "$expanded_line")

                    # Match by full path or by vault name
                    if [[ "$expanded_line" == "$target" ]] || [[ "$line_name" == "$target" ]]; then
                        found=true
                        info "Removing: $line"
                    else
                        echo "$line" >>"$temp_file"
                    fi
                fi
            done <"$vault_file"

            if [[ "$found" == "true" ]]; then
                mv "$temp_file" "$vault_file"
                success "Vault removed"
                echo
                cecho "Note:" "$WHITE"
                echo "  Changes take effect on next container start"
            else
                rm -f "$temp_file"
                error "No vault found matching: $target"
            fi
            exit 0
            ;;

        "")
            # Show current vaults (default behavior)
            ;;

        *)
            error "Unknown subcommand: $subcommand
Usage:
  claudebox vault              Show configured vaults
  claudebox vault add <path>   Add a directory to vault (read-only)
  claudebox vault remove <path> Remove a vault by path or name"
            ;;
    esac

    # Show current vaults
    cecho "🔒 ClaudeBox Vault (Read-Only Mounts)" "$CYAN"
    echo
    cecho "Current Project: $PROJECT_DIR" "$WHITE"
    echo

    if [[ -f "$vault_file" ]]; then
        cecho "Vault file:" "$GREEN"
        echo "  $vault_file"
        echo

        # Count and display vaults
        local vault_count=0
        cecho "Configured vaults:" "$CYAN"
        while IFS= read -r line; do
            if [[ -n "$line" ]] && [[ ! "$line" =~ ^#.* ]]; then
                # Expand tilde
                local expanded_path="${line/#\~/$HOME}"
                local vault_name
                vault_name=$(basename "$expanded_path")
                local container_path="/vault/$vault_name"

                # Check status
                local status_icon="✓"
                local status_color="$GREEN"
                if [[ ! -e "$expanded_path" ]]; then
                    status_icon="✗"
                    status_color="$RED"
                elif [[ -L "$expanded_path" ]]; then
                    status_icon="⚠"
                    status_color="$YELLOW"
                fi

                printf "  ${status_color}${status_icon}${NC} %s -> %s (ro)\n" "$line" "$container_path"
                ((vault_count++)) || true
            fi
        done <"$vault_file"

        if [[ $vault_count -eq 0 ]]; then
            echo "  (none configured)"
        fi
        echo
    else
        cecho "Vault file:" "$YELLOW"
        echo "  Not yet created"
        echo "  Location: $vault_file"
        echo
        cecho "No vaults configured." "$WHITE"
    fi

    echo
    cecho "Usage:" "$YELLOW"
    echo "  claudebox vault add <path>      Add a directory (read-only at /vault/<name>)"
    echo "  claudebox vault remove <path>   Remove a vault"
    echo
    cecho "Examples:" "$GREEN"
    echo "  claudebox vault add ~/obsidian-vault   -> /vault/obsidian-vault:ro"
    echo "  claudebox vault add /home/user/docs    -> /vault/docs:ro"
    echo
    cecho "Security:" "$WHITE"
    echo "  • All vaults are mounted read-only (no footguns)"
    echo "  • Symlinks are rejected (prevents privilege escalation)"
    echo "  • Path traversal (..) is rejected"
    echo
    cecho "Note:" "$WHITE"
    echo "  Changes take effect on next container start"

    exit 0
}

export -f _cmd_projects _cmd_allowlist _cmd_vault _cmd_info
