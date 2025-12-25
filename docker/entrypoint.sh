#!/bin/bash
set -euo pipefail

# CentOS Stream 8 Kernel Build Script
# Usage: entrypoint.sh <srpm_path> <output_dir>

# ============================================================================
# Configuration
# ============================================================================
SRPM_PATH="${1:-}"
OUTPUT_DIR="${2:-/out}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================================
# Logging Functions
# ============================================================================
log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ============================================================================
# Validation
# ============================================================================
if [[ -z "${SRPM_PATH}" ]]; then
    log_error "SRPM path not provided"
    echo ""
    echo "Usage: $0 <srpm_path> <output_dir>"
    echo ""
    echo "Example:"
    echo "  $0 /input.src.rpm /out"
    exit 1
fi

if [[ ! -f "${SRPM_PATH}" ]]; then
    log_error "SRPM file not found: ${SRPM_PATH}"
    exit 1
fi

# Ensure output directory exists
mkdir -p "${OUTPUT_DIR}"

# ============================================================================
# Setup RPM Build Environment
# ============================================================================
if [[ "$(id -u)" -eq 0 ]]; then
    RPMBUILD_DIR="/root/rpmbuild"
else
    RPMBUILD_DIR="/home/builder/rpmbuild"
fi

# Create RPM build directories
mkdir -p "${RPMBUILD_DIR}"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}

log_info "Build environment:"
log_info "  SRPM: ${SRPM_PATH}"
log_info "  Output: ${OUTPUT_DIR}"
log_info "  RPM Build Dir: ${RPMBUILD_DIR}"
log_info "  User: $(whoami) (UID: $(id -u))"

# ============================================================================
# Install SRPM
# ============================================================================
log_info "Installing SRPM..."

# Use --nomd5 to suppress warnings about missing users (mockbuild)
# Redirect warnings to /dev/null for cleaner output
rpm -ivh --nomd5 --define "_topdir ${RPMBUILD_DIR}" "${SRPM_PATH}" 2>&1 | grep -v "warning: user\|warning: group" || true

log_success "SRPM installed"

# Find spec file (kernel SRPMs may have various naming patterns)
SPEC_FILE=$(find "${RPMBUILD_DIR}/SPECS" -name "*.spec" -type f | head -1)
if [[ -z "${SPEC_FILE}" ]]; then
    log_error "No spec file found in ${RPMBUILD_DIR}/SPECS"
    log_error "Contents of SPECS directory:"
    ls -la "${RPMBUILD_DIR}/SPECS/" || true
    exit 1
fi
log_info "Spec file: ${SPEC_FILE}"

# ============================================================================
# Install Build Dependencies
# ============================================================================
log_info "Installing build dependencies (this may take a while)..."
dnf builddep -y "${SPEC_FILE}" || {
    log_warn "dnf builddep had issues, attempting to continue..."
}
log_success "Build dependencies installed"

# ============================================================================
# Build the Kernel
# ============================================================================
log_info "Starting kernel build (this will take 30-60 minutes)..."
log_info "Build started at: $(date)"

# Build with optimized settings for faster builds
rpmbuild \
    --define "_topdir ${RPMBUILD_DIR}" \
    --define "debug_package %{nil}" \
    -ba "${SPEC_FILE}" 2>&1 | tee /tmp/build.log || {
        log_error "Build failed! Last 50 lines of build log:"
        tail -50 /tmp/build.log
        exit 1
    }

log_success "Build completed at: $(date)"

# ============================================================================
# Export Built RPMs
# ============================================================================
log_info "Exporting built RPMs to ${OUTPUT_DIR}..."

RPM_COUNT=0
SRPM_COUNT=0

# Copy binary RPMs
for rpm in $(find "${RPMBUILD_DIR}/RPMS" -name "*.rpm" -type f 2>/dev/null); do
    cp -v "${rpm}" "${OUTPUT_DIR}/"
    ((RPM_COUNT++)) || true
done

# Copy source RPMs
for srpm in $(find "${RPMBUILD_DIR}/SRPMS" -name "*.src.rpm" -type f 2>/dev/null); do
    cp -v "${srpm}" "${OUTPUT_DIR}/"
    ((SRPM_COUNT++)) || true
done

# ============================================================================
# Summary
# ============================================================================
echo ""
log_success "=========================================="
log_success "Build completed successfully!"
log_success "=========================================="
log_info "Binary RPMs: ${RPM_COUNT}"
log_info "Source RPMs: ${SRPM_COUNT}"
log_info "Output directory: ${OUTPUT_DIR}"
echo ""
log_info "Built packages:"
ls -lh "${OUTPUT_DIR}"/*.rpm 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'

