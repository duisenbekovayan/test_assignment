#!/bin/bash
set -e

ORIGINAL_SRPM="${1:-kernel-4.18.0-448.el8.src.rpm}"
OUTPUT_DIR="${2:-./patched-srpm}"

echo "=== Creating Patched SRPM ==="
echo "Original SRPM: $ORIGINAL_SRPM"
echo "Output directory: $OUTPUT_DIR"

# Check if original SRPM exists
if [ ! -f "$ORIGINAL_SRPM" ]; then
    echo "Error: Original SRPM not found: $ORIGINAL_SRPM"
    echo "Please download it first:"
    echo "  wget https://vault.centos.org/8-stream/BaseOS/Source/SPackages/kernel-4.18.0-448.el8.src.rpm"
    exit 1
fi

# Create working directory
WORK_DIR=$(mktemp -d)
echo "Working directory: $WORK_DIR"

# Setup RPM build environment
mkdir -p ~/rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}

# Install the original SRPM
echo "Installing original SRPM..."
rpm -ivh "$ORIGINAL_SRPM"

# Download the patches
echo "Downloading patches..."
PATCH1="0001-custom-80e648042e512d5a767da251d44132553fe04ae0.patch"
PATCH2="0002-custom-f90fff1e152dedf52b932240ebbd670d83330eca.patch"

curl -L "https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/patch/?id=80e648042e512d5a767da251d44132553fe04ae0" -o "$WORK_DIR/$PATCH1"
curl -L "https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/patch/?id=f90fff1e152dedf52b932240ebbd670d83330eca" -o "$WORK_DIR/$PATCH2"

# Copy patches to SOURCES
cp "$WORK_DIR/$PATCH1" ~/rpmbuild/SOURCES/
cp "$WORK_DIR/$PATCH2" ~/rpmbuild/SOURCES/

# Modify the spec file to include our patches
SPEC_FILE=~/rpmbuild/SPECS/kernel.spec

echo "Modifying spec file to include patches..."
# Find the last patch number in the spec file
LAST_PATCH=$(grep -E "^Patch[0-9]+:" "$SPEC_FILE" | sed 's/Patch\([0-9]*\):.*/\1/' | sort -n | tail -1)
NEXT_PATCH=$((LAST_PATCH + 1))
NEXT_PATCH2=$((LAST_PATCH + 2))

# Add our patches to the spec file after the last existing patch
sed -i "/^Patch${LAST_PATCH}:/a\\
Patch${NEXT_PATCH}: $PATCH1\\
Patch${NEXT_PATCH2}: $PATCH2" "$SPEC_FILE"

# Find the %prep section and add patch application
sed -i "/%setup -q -n kernel-%{kversion}%{?dist}/a\\
# Apply custom patches\\
%patch${NEXT_PATCH} -p1\\
%patch${NEXT_PATCH2} -p1" "$SPEC_FILE"

# Increment the release number
sed -i 's/^%define buildid .local$/&.patched/' "$SPEC_FILE" || \
sed -i '/^%define buildid/d; /^%define dist_base_version/a %define buildid .local.patched' "$SPEC_FILE" || \
sed -i '/^Release:/s/\(Release:.*\)/\1.patched/' "$SPEC_FILE"

# Build the patched SRPM
echo "Building patched SRPM..."
cd ~/rpmbuild/SPECS
rpmbuild -bs kernel.spec

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Copy the patched SRPM to output directory
PATCHED_SRPM=$(ls -t ~/rpmbuild/SRPMS/kernel-*.src.rpm | head -1)
cp "$PATCHED_SRPM" "$OUTPUT_DIR/"

# Cleanup
rm -rf "$WORK_DIR"

echo "=== Patched SRPM Created ==="
echo "Location: $OUTPUT_DIR/$(basename $PATCHED_SRPM)"
echo ""
echo "You can now build this patched SRPM using:"
echo "  ./build-stream8-kernel $OUTPUT_DIR/$(basename $PATCHED_SRPM) ./output-patched"
