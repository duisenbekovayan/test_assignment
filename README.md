# CentOS Stream 8 Kernel Build System

A complete solution for building CentOS Stream 8 kernel RPMs using Docker, including patch application capabilities.

## Project Structure

```
├── docker/
│   ├── Dockerfile          # CentOS Stream 8 build environment
│   └── entrypoint.sh       # Automated build script
├── task2/
│   ├── main.go            # Go build tool
│   └── go.mod             # Go module
├── task3/
│   └── apply-patches.sh   # SRPM patching script
├── kernel-4.18.0-448.el8.src.rpm  # Original SRPM
├── Makefile               # Build automation
└── README.md             # This file
```

## Prerequisites

- **Docker** (version 20.10 or later)
- **Go** (version 1.18 or later) - for building the Go tool
- **Linux/macOS** host system
- **Internet connection** (for downloading patches and dependencies)
- **Disk space**: At least 20GB free (kernel builds are large)

## Task 1: Docker Build Environment

### Building the Docker Image

**Important:** The Dockerfile is in the `docker/` subdirectory, so you must either:

**Option 1:** Change to the docker directory first (recommended):
```bash
cd docker
docker build -t stream8-kernel-builder .
```

**Option 2:** Specify the Dockerfile path from the root:
```bash
docker build -f docker/Dockerfile -t stream8-kernel-builder docker/
```

The Dockerfile creates a CentOS Stream 8 environment with:
- All kernel build dependencies
- RPM build tools
- Proper repository configuration
- Non-root user setup (though builds run as root for `dnf builddep`)

### Manual Build (Testing)

You can test the Docker environment manually:

```bash
# Build the image
cd docker
docker build -t stream8-kernel-builder .

# Run a build manually
docker run --rm --user 0 \
  -v /path/to/kernel-4.18.0-448.el8.src.rpm:/input.src.rpm:ro \
  -v /path/to/output:/out \
  stream8-kernel-builder \
  /input.src.rpm /out
```

### Features

- **Automatic dependency resolution**: Uses `dnf builddep` to install all required packages
- **Repository configuration**: Automatically configures CentOS repositories
- **Error handling**: Comprehensive error checking and logging
- **Progress reporting**: Shows disk space and build progress
- **Output management**: Automatically exports all built RPMs

## Task 2: Go Build Tool

### Building the Go Tool

```bash
cd task2
go build -o build-stream8-kernel main.go
```

### Usage

```bash
# Build from local SRPM file
./build-stream8-kernel kernel-4.18.0-448.el8.src.rpm ./output

# Build from URL
./build-stream8-kernel \
  
https://vault.centos.org/8-stream/BaseOS/Source/SPackages/kernel-4.18.0-448.el8.src.rpm \
  ./output
```

### Features

- ✅ Docker availability checking
- ✅ Docker image validation
- ✅ URL download support
- ✅ Local file support
- ✅ Progress reporting
- ✅ Build timing
- ✅ Output file listing

## Task 3: Patched SRPM Creation

### Applying Patches

The script applies two upstream Linux kernel commits:
- `80e6480` - Security fix
- `f90fff1` - Performance improvement

```bash
cd task3
./apply-patches.sh ../kernel-4.18.0-448.el8.src.rpm ./out ./work
```

### Features

- ✅ Downloads patches from kernel.org
- ✅ Applies patches to kernel source
- ✅ Rebuilds SRPM with patches
- ✅ Handles permission issues automatically
- ✅ Comprehensive error handling

## Using Make (Recommended)

The Makefile handles all directory changes automatically:

```bash
# Build all components
make build-all

# Test with original SRPM
make test-build

# Create and build patched SRPM
make build-patched
```

**Note:** If you prefer to run commands manually, remember the Dockerfile is in `docker/` subdirectory.

## Manual Steps

Complete workflow from scratch:

```bash
# 1. Build Docker image
cd docker
docker build -t stream8-kernel-builder .

# 2. Build Go tool
cd ../task2
go build -o build-stream8-kernel main.go

# 3. Build original kernel
./build-stream8-kernel ../kernel-4.18.0-448.el8.src.rpm ../out

# 4. Create patched SRPM
cd ../task3
./apply-patches.sh ../kernel-4.18.0-448.el8.src.rpm ./out ./work

# 5. Build patched kernel
cd ../task2
./build-stream8-kernel ../task3/out/kernel-4.18.0-448.el8.patched.src.rpm ../task3/out/rpms
```

## Troubleshooting

### Permission Denied Errors in task3/work

If you see "Permission denied" errors when trying to clean up `task3/work`, the files were likely created as root. Fix it with:

```bash
# Option 1: Use the helper script
cd task3
./fix-permissions.sh

# Option 2: Manual fix
sudo chown -R $USER:$USER task3/work
rm -rf task3/work

# Option 3: Remove with sudo
sudo rm -rf task3/work
```

The updated `apply-patches.sh` script now automatically fixes ownership after extraction to prevent this issue.

### Docker Build Fails with "SRPM file not found"

Ensure you're using an absolute path for the SRPM file. The Go tool now automatically converts relative paths to absolute paths, but if you're running Docker directly:

```bash
# Wrong (relative path)
docker run ... -v ./file.rpm:/input.rpm ...

# Correct (absolute path)
docker run ... -v "$(pwd)/file.rpm:/input.rpm" ...
```

## License

This project is provided as a test assignment implementation. The kernel source code and patches are subject to their respective licenses (GPL v2 for Linux kernel).
