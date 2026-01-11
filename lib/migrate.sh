#!/usr/bin/env bash
# Migration System - Migrate from old global structure to new project-local structure
# ============================================================================
# Old: ~/.claudebox/projects/{slug}_{crc32}/{hash}/ (global, numbered slots)
# New: $PROJECT/.claudebox/profiles/{name}/ (local, named profiles)

# Check if old structure exists and needs migration
has_old_structure() {
    local old_projects_dir="$HOME/.claudebox/projects"
    [[ -d "$old_projects_dir" ]] && [[ -n "$(ls -A "$old_projects_dir" 2>/dev/null)" ]]
}

# List all old project parent directories
list_old_projects() {
    local old_projects_dir="$HOME/.claudebox/projects"
    if [[ -d "$old_projects_dir" ]]; then
        find "$old_projects_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null
    fi
}

# Get the original project path from an old parent directory
get_old_project_path() {
    local old_parent="$1"
    local path_file="$old_parent/.project_path"
    if [[ -f "$path_file" ]]; then
        cat "$path_file"
    else
        echo ""
    fi
}

# Get slot count from old parent directory
get_old_slot_count() {
    local old_parent="$1"
    local counter_file="$old_parent/.project_container_counter"
    if [[ -f "$counter_file" ]]; then
        cat "$counter_file"
    else
        echo "0"
    fi
}

# List slot directories in old parent (hash-named directories)
list_old_slots() {
    local old_parent="$1"
    # Slots are 8-character hex directories (CRC32 hashes)
    find "$old_parent" -mindepth 1 -maxdepth 1 -type d -name '[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]' 2>/dev/null | sort
}

# Migrate a single project from old to new structure
migrate_project() {
    local old_parent="$1"
    local project_path
    project_path=$(get_old_project_path "$old_parent")

    if [[ -z "$project_path" ]]; then
        warn "Skipping $(basename "$old_parent"): no .project_path file"
        return 1
    fi

    if [[ ! -d "$project_path" ]]; then
        warn "Skipping $(basename "$old_parent"): project path no longer exists: $project_path"
        return 1
    fi

    local new_profiles_dir="$project_path/.claudebox/profiles"

    # Check if already migrated
    if [[ -d "$new_profiles_dir" ]] && [[ -n "$(ls -A "$new_profiles_dir" 2>/dev/null)" ]]; then
        info "Already migrated: $project_path"
        return 0
    fi

    info "Migrating: $project_path"

    # Create new profiles directory
    mkdir -p "$new_profiles_dir"

    # Find and copy slots
    local slot_num=0
    while IFS= read -r old_slot_dir; do
        slot_num=$((slot_num + 1))
        local new_profile_name
        if [[ $slot_num -eq 1 ]]; then
            new_profile_name="default"
        else
            new_profile_name="slot-$slot_num"
        fi

        local new_profile_dir="$new_profiles_dir/$new_profile_name"
        info "  Copying slot $slot_num ($(basename "$old_slot_dir")) -> $new_profile_name"

        # Copy the slot contents
        cp -R "$old_slot_dir" "$new_profile_dir"

    done < <(list_old_slots "$old_parent")

    if [[ $slot_num -eq 0 ]]; then
        warn "  No slots found to migrate"
        return 0
    fi

    success "  Migrated $slot_num slot(s)"
    return 0
}

# Archive the old structure
archive_old_structure() {
    local old_projects_dir="$HOME/.claudebox/projects"
    local archive_dir
    archive_dir="$HOME/.claudebox/archive-$(date +%Y%m%d_%H%M%S)"

    if [[ ! -d "$old_projects_dir" ]]; then
        return 0
    fi

    # Create archive directory
    mkdir -p "$archive_dir"

    # Move old projects to archive
    if mv "$old_projects_dir" "$archive_dir/projects"; then
        success "Archived old structure to: $archive_dir/projects"
        return 0
    else
        error "Failed to archive old structure"
        return 1
    fi
}

# Interactive migration prompt
# Skips prompt in non-interactive mode (no TTY) unless CLAUDEBOX_AUTO_MIGRATE=1
prompt_migration() {
    if ! has_old_structure; then
        return 0
    fi

    # Skip interactive prompt if no TTY (CI, scripted, piped)
    if [[ ! -t 0 ]] && [[ "${CLAUDEBOX_AUTO_MIGRATE:-}" != "1" ]]; then
        info "Old directory structure detected. Run 'claudebox migrate' interactively to migrate."
        return 1
    fi

    echo
    cecho "ClaudeBox has detected an old directory structure." "$YELLOW"
    echo
    echo "The old structure stored data globally in ~/.claudebox/projects/"
    echo "The new structure stores data locally in each project's .claudebox/ folder."
    echo
    echo "This migration will:"
    echo "  1. Copy your existing slots to each project's .claudebox/profiles/"
    echo "  2. Rename slot-1 to 'default' in each project"
    echo "  3. Archive the old structure to ~/.claudebox/archive-YYYYMMDD_HHMMSS/"
    echo

    # List projects to migrate
    local count=0
    while IFS= read -r old_parent; do
        local project_path
        project_path=$(get_old_project_path "$old_parent")
        local slot_count
        slot_count=$(list_old_slots "$old_parent" | wc -l | tr -d ' ')
        if [[ -n "$project_path" ]]; then
            printf "  - %s (%s slot%s)\n" "$project_path" "$slot_count" "$([[ "$slot_count" -eq 1 ]] && echo "" || echo "s")"
            count=$((count + 1))
        fi
    done < <(list_old_projects)

    if [[ $count -eq 0 ]]; then
        info "No projects found to migrate"
        return 0
    fi

    echo
    read -r -p "Would you like to migrate now? [Y/n] " response
    case "$response" in
        [nN]*)
            info "Migration skipped. Run 'claudebox migrate' to migrate later."
            return 1
            ;;
        *)
            run_migration
            return $?
            ;;
    esac
}

# Run the full migration
run_migration() {
    echo
    cecho "Starting migration..." "$CYAN"
    echo

    local success_count=0
    local fail_count=0

    while IFS= read -r old_parent; do
        if migrate_project "$old_parent"; then
            success_count=$((success_count + 1))
        else
            fail_count=$((fail_count + 1))
        fi
    done < <(list_old_projects)

    echo
    if [[ $fail_count -eq 0 ]]; then
        success "Migration complete: $success_count project(s) migrated"

        # Archive old structure
        echo
        read -r -p "Archive the old structure? [Y/n] " response
        case "$response" in
            [nN]*)
                warn "Old structure preserved at ~/.claudebox/projects/"
                warn "You can manually delete it after verifying the migration."
                ;;
            *)
                archive_old_structure
                ;;
        esac
    else
        warn "Migration completed with issues: $success_count succeeded, $fail_count failed"
        warn "Old structure preserved at ~/.claudebox/projects/"
    fi

    echo
    return 0
}

# Manual migration command
_cmd_migrate() {
    if ! has_old_structure; then
        info "No old structure found. Nothing to migrate."
        return 0
    fi

    prompt_migration
}

export -f has_old_structure list_old_projects get_old_project_path get_old_slot_count
export -f list_old_slots migrate_project archive_old_structure
export -f prompt_migration run_migration _cmd_migrate
