#!/usr/bin/env bash
set -euo pipefail

# Script to apply upstream Linux kernel patches and rebuild SRPM
# Applies commits 80e6480 and f90fff1

COMMIT_1="80e6480b1e0d7c3b4a8b4b4b5b5b5b5b5b5b5b5"
COMMIT_2="f90fff1b2e0d7c3b4a8b4b4b5b5b5b5b5b5b5b5"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORIGINAL_SRPM="${1:-../kernel-4.18.0-448.el8.src.rpm}"
OUTPUT_DIR="${2:-./out}"
WORK_DIR="${3:-./work}"

# Color codes for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[*]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[+]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Usage information
usage() {
    cat << EOF
Apply upstream Linux kernel patches and rebuild SRPM

Usage: $0 [original_srpm] [output_dir] [work_dir]

Arguments:
  original_srpm  Path to original SRPM (default: ../kernel-4.18.0-448.el8.src.rpm)
  output_dir     Directory for output SRPM (default: ./out)
  work_dir       Working directory for extraction (default: ./work)

Example:
  $0 ../kernel-4.18.0-448.el8.src.rpm ./out ./work
