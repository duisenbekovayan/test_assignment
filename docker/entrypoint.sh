#!/usr/bin/env bash
set -euo pipefail

SRPM_IN="${1:-}"
OUTDIR="${2:-/out}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[*]${NC} $*"; }
log_success() { echo -e "${GREEN}[+]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

if [[ -z "${SRPM_IN}" ]]; then
    log_error "SRPM path not provided"
    echo "Usage: $0 <srpm_path_inside_container> <outdir>"
    exit 2
fi

if [[ ! -f "${SRPM_IN}" ]]; then
    log_error "SRPM file not found: ${SRPM_IN}"
    exit 2
fi

if [[ "$(id -u)" -eq 0 ]]; then
    : "${RPMBUILD:=/root/rpmbuild}"
else
    : "${RPMBUILD:=/home/builder/rpmbuild}"
fi

mkdir -p "${RPMBUILD}"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}

log_info "Starting kernel build..."
log_info "SRPM: ${SRPM_IN}"
log_info "Output directory: ${OUTDIR}"
log_info "RPMBUILD directory: ${RPMBUILD}"

log_info "Disk space before build:"
df -h . || true

log_info "Extracting SRPM..."
cd "${RPMBUILD}"
rpm2cpio "${SRPM_IN}" | cpio -idmv

SPEC=$(find "${RPMBUILD}" -name "*.spec" -type f | head -1)
if [[ -z "${SPEC}" ]]; then
    log_error "No spec file found in SRPM"
    exit 3
fi

log_info "Found spec file: ${SPEC}"

log_info "Installing build dependencies..."
dnf builddep -y "${SPEC}" || log_warn "Some build dependencies may have failed to install"

log_info "Building RPMs (this may take 30-60 minutes)..."
if ! rpmbuild \
    --define "_topdir ${RPMBUILD}" \
    --define "debug_package %{nil}" \
    --define "_without_debug 1" \
    --define "without_debuginfo 1" \
    -ba "${SPEC}" 2>&1 | tee /tmp/rpmbuild.log; then
    log_error "RPM build failed"
    log_info "Last 50 lines of build log:"
    tail -50 /tmp/rpmbuild.log || true
    exit 5
fi

log_info "Exporting RPMs to ${OUTDIR}..."
mkdir -p "${OUTDIR}"

RPM_COUNT=0
SRPM_COUNT=0

# FIXED: Use mapfile instead of process substitution to avoid early termination
mapfile -t rpm_files < <(find "${RPMBUILD}/RPMS" -type f -name "*.rpm" 2>/dev/null || true)

for rpm_file in "${rpm_files[@]}"; do
    if [[ -f "${rpm_file}" ]]; then
        if cp -v "${rpm_file}" "${OUTDIR}/"; then
            ((RPM_COUNT++))
        else
            log_warn "Failed to copy: ${rpm_file}"
        fi
    fi
done

mapfile -t srpm_files < <(find "${RPMBUILD}/SRPMS" -type f -name "*.src.rpm" 2>/dev/null || true)

for srpm_file in "${srpm_files[@]}"; do
    if [[ -f "${srpm_file}" ]]; then
        if cp -v "${srpm_file}" "${OUTDIR}/"; then
            ((SRPM_COUNT++))
        else
            log_warn "Failed to copy: ${srpm_file}"
        fi
    fi
done

log_info "Exported ${RPM_COUNT} binary RPM(s) and ${SRPM_COUNT} source RPM(s)"

log_info "Disk space after build:"
df -h . || true

log_info "Built RPMs in ${OUTDIR}:"
if ls "${OUTDIR}"/*.rpm 1>/dev/null 2>&1; then
    ls -lh "${OUTDIR}"/*.rpm | awk '{print $9, "(" $5 ")"}'
else
    log_warn "No RPMs found in output directory"
fi

log_success "Build completed successfully!"
log_info "Output location: ${OUTDIR}"
