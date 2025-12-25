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
- **Disk space**: At least 30GB free (kernel builds are large)

## Task 1: Docker Build Environment

### Building the Docker Image

```bash
cd docker
docker build -t stream8-kernel-builder .
```

You can test the Docker environment manually:

```bash
# Build the image
cd docker
docker build -t stream8-kernel-builder .

# Run a build manually, inside test_assignment directory! (root directory)
  docker run --rm \
  -v "$PWD/../kernel-4.18.0-448.el8.src.rpm:/input.src.rpm:ro" \
  -v "$PWD/out:/out" \
  stream8-kernel-builder \
  /input.src.rpm /out
```

## Task 2: Go Build Tool

### Building the Go Tool

```bash
go build -o build-stream8-kernel ./task2/main.go
```

### Usage

```bash
# Build from local SRPM file
./task2/build-stream8-kernel ~/Desktop/test_assignment/kernel-4.18.0-448.el8.src.rpm ./output

# Build from URL
./task2/build-stream8-kernel \
  
https://vault.centos.org/8-stream/BaseOS/Source/SPackages/kernel-4.18.0-448.el8.src.rpm \
  ./output
```
## Task 3: Patched SRPM Creation

### Applying Patches

The script applies two upstream Linux kernel commits:
- `80e6480`
- `f90fff1`

```bash
# Start the Docker container:
docker run --rm -it \
  --entrypoint /bin/bash \
  -v ~/Desktop/test_assignment/task3:/workspace \
  -v ~/Desktop/test_assignment/task3/out:/out \
  -v ~/Desktop/test_assignment/kernel-4.18.0-448.el8.src.rpm:/input.src.rpm \
  stream8-kernel-builder

# Run the patching script:
cd /workspace
./apply-patches.sh /input.src.rpm /out /tmp/work
# Patched SRPM will be at:
./out/kernel-4.18.0-448.el8.src.rpm
# For building patched SRPM:
entrypoint.sh /out/kernel-4.18.0-448.el8.src.rpm /out
```

