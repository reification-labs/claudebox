# ClaudeBox Security & Profile Refactor

## Summary

Major refactor with three goals:
1. **Security**: Read-only global config (`~/.claudebox/`)
2. **Locality**: Project-local runtime state (`$PROJECT_DIR/.claudebox/`)
3. **Named Profiles**: Replace numbered slots with named profiles (default, frontend, backend)

## Target Architecture

```
~/.claudebox/                           # GLOBAL CONFIG (read-only to container)
├── mounts                              # ONLY place mounts lives - never in project
├── allowlist                           # ONLY place allowlist lives - never in project
├── profiles.ini                        # Default dev profiles (python, rust, etc.)
└── common.sh                           # Shared utilities

$PROJECT_DIR/.claudebox/profiles/       # PROJECT PROFILES (each fully isolated)
├── default/                            # Each profile is a complete sandbox
│   ├── .claude/                        # Claude state + CLAUDE.md
│   ├── .config/
│   ├── .cache/
│   ├── .venv/                          # Profile-specific Python venv
│   ├── tooling.md                      # Profile-specific tooling docs
│   └── .tooling_checksum
├── frontend/                           # Another profile - completely isolated
│   ├── .claude/
│   ├── .config/
│   ├── .cache/
│   ├── .venv/                          # Its OWN venv (different packages OK)
│   └── ...
└── backend/
    └── ...
```

**Security Principle**: Nothing writable exists outside of `/workspace` and the single profile directory. No mounts, allowlist, or profiles.ini in project dir.

## Command Changes

| Old | New | Notes |
|-----|-----|-------|
| `claudebox create` | `claudebox create [name]` | Defaults to "default" |
| `claudebox slot 2` | `claudebox profile <name>` | Named access |
| `claudebox slots` | `claudebox profiles` | List all profiles |
| `claudebox revoke` | `claudebox profile delete <name>` | Explicit delete |

## Implementation Phases

### Phase 1: Global Config Separation (Security Fix)

**Goal**: Make `~/.claudebox/` read-only to container, protecting mounts/allowlist.

**Files**:
- `lib/docker.sh` (lines 218-295) - Mount configuration
- `main.sh` - Initialize global config on first run

**Changes**:
```bash
# Before:
-v "$PROJECT_PARENT_DIR":"/home/$DOCKER_USER/.claudebox"

# After - mount ONLY the specific profile, not all profiles:
-v "$HOME/.claudebox":"/home/$DOCKER_USER/.claudebox:ro"
-v "$PROJECT_DIR/.claudebox/profiles/$PROFILE":"/home/$DOCKER_USER/.claudebox/profile:rw"
```

**Security**: By mounting only `profiles/$PROFILE/` (not `profiles/`), one Claude cannot access another profile's data. Complete isolation between profiles.

**Test**:
1. Verify container cannot write to `~/.claudebox/mounts`
2. Verify container cannot see other profiles (only its own)

---

### Phase 2: Project-Local State (Locality)

**Goal**: Move runtime state to `$PROJECT_DIR/.claudebox/profiles/$PROFILE/`.

**Files**:
- `lib/project.sh` - New path functions
- `lib/state.sh` - Checksum locations (now per-profile)
- `build/docker-entrypoint` - Runtime paths for .venv, tooling.md

**Key Changes**:
```bash
# Remove:
get_parent_dir()              # Was: ~/.claudebox/projects/{slug}
generate_parent_folder_name() # CRC32 hashing

# Add:
get_profile_dir() { echo "$PROJECT_DIR/.claudebox/profiles/${1:-default}"; }
```

**Per-Profile State** (all inside profile dir):
- `.venv/` - Profile-specific Python venv (allows different packages per profile)
- `tooling.md` - Profile-specific tooling docs
- `.tooling_checksum` - Profile-specific checksum

**Test**: Run claudebox, verify `.claudebox/profiles/default/` created in project dir

---

### Phase 3: Named Profiles (Replace Slots)

**Goal**: Human-readable profile names instead of numbered slots.

**Files**:
- `lib/commands.slot.sh` → `lib/commands.profile.sh` (rename)
- `lib/project.sh` - Remove counter system
- `lib/commands.sh` - Update dispatcher

**Remove** (~100 lines):
- `read_counter()` / `write_counter()`
- `prune_slot_counter()`
- `generate_container_name()` (CRC32 chain)
- `get_slot_index()`
- `.project_container_counter` file

**Add**:
```bash
_cmd_create() {
    local name="${1:-default}"
    [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]] || error "Invalid profile name"
    init_profile_dir "$(get_profile_dir "$name")"
}

_cmd_profile() {
    local name="${1:-default}"
    export PROFILE_NAME="$name"
    export PROJECT_PROFILE_DIR="$(get_profile_dir "$name")"
    # ... run container
}

_cmd_profiles() {
    for dir in "$PROJECT_DIR/.claudebox/profiles"/*/; do
        echo "$(basename "$dir")"
    done
}
```

**Test**: `claudebox create backend`, `claudebox profile backend`

---

### Phase 4: Migration System

**Goal**: Migrate existing users from old structure.

**New File**: `lib/migrate.sh`

**Logic**:
1. Detect `~/.claudebox/projects/` (old structure)
2. For each project, copy slots to `$PROJECT/.claudebox/profiles/`
3. Rename `slot-1` → `default`
4. Archive old structure to `~/.claudebox/archive-YYYYMMDD/`

**Trigger**: Automatic prompt on startup if old structure detected

---

### Phase 5: Tests & Documentation

**Update Tests**:
- `tests/test_mount_readonly.sh` - Add global config read-only test
- `tests/test_named_profiles.sh` (new) - Profile CRUD tests

**Update Docs**:
- README.md - New directory structure
- Help text - New commands

## Critical Files

| File | Changes |
|------|---------|
| `lib/project.sh` | Remove CRC32, counter; add profile functions |
| `lib/docker.sh` | Split mounts: global ro, project rw |
| `lib/commands.slot.sh` | Rename to profile, named access |
| `main.sh` | Migration trigger, default profile |
| `build/docker-entrypoint` | Update runtime paths |

## Verification

1. **Security**: `docker exec ... touch ~/.claudebox/mounts` → fails
2. **Locality**: `.claudebox/` created in project, not `~/.claudebox/projects/`
3. **Profiles**: `claudebox create frontend` + `claudebox profile frontend` works
4. **Migration**: Old slots become named profiles
5. **Tests**: All existing tests pass + new profile tests

## Breaking Changes & Compatibility

**Command changes**:
- `claudebox slot <number>` → `claudebox profile <name>`
- `claudebox slots` → `claudebox profiles`
- `claudebox revoke` → `claudebox profile delete <name>`

**Backward compatibility aliases**:
- `claudebox slot 2` → aliases to `claudebox profile slot-2` (migration creates slot-N profiles)
- Old commands continue working during transition period

**State migration**:
- `~/.claudebox/projects/` → `$PROJECT/.claudebox/profiles/`
- Old numbered slots become `slot-1`, `slot-2`, etc. profiles
- `slot-1` is renamed to `default` for convenience

Migration handles all of this automatically with user confirmation.
