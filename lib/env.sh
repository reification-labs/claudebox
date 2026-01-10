#!/usr/bin/env bash
# All immutable or rarely‑changing environment variables live here.

# Configuration
# DEFAULT_FLAGS is loaded from file in main.sh, don't reset it here

# Docker and user settings
# shellcheck disable=SC2034  # Used in docker.sh
readonly DOCKER_USER="claude"
# shellcheck disable=SC2155  # readonly requires assignment at declaration
readonly USER_ID=$(id -u)
# shellcheck disable=SC2155  # readonly requires assignment at declaration
readonly GROUP_ID=$(id -g)

# Directories and paths
PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
# shellcheck disable=SC2034  # Used in update logic
readonly LINK_TARGET="$HOME/.local/bin/claudebox"
export CLAUDEBOX_HOME="${HOME}/.claudebox"

# Version constants
# shellcheck disable=SC2034  # Used in profile installations
readonly NODE_VERSION="--lts"
# shellcheck disable=SC2034  # Used in profile installations
readonly DELTA_VERSION="0.17.0"

# Script path resolution - moved to main claudebox.sh since it needs BASH_SOURCE
# SCRIPT_PATH will be set by main script

# Export what other modules need
export USER_ID
export GROUP_ID
export PROJECT_DIR
