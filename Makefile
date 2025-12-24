.PHONY: help build-docker build-go build-all test-build build-patched clean

# Default target
help:
	@echo "CentOS Stream 8 Kernel Build System"
	@echo ""
	@echo "Available targets:"
	@echo "  build-docker     - Build the Docker image"
	@echo "  build-go         - Build the Go tool"
	@echo "  build-all        - Build both Docker image and Go tool"
	@echo "  test-build       - Test build with original SRPM"
	@echo "  build-patched    - Create and build patched SRPM"
	@echo "  clean            - Clean build artifacts"
	@echo ""
	@echo "Examples:"
	@echo "  make build-all"
	@echo "  make test-build"
	@echo "  make build-patched"

# Docker image name
DOCKER_IMAGE = stream8-kernel-builder

# Directories
DOCKER_DIR = docker
TASK2_DIR = task2
TASK3_DIR = task3
OUT_DIR = out

# Build Docker image
build-docker:
	@echo "[*] Building Docker image: $(DOCKER_IMAGE)"
	cd $(DOCKER_DIR) && docker build -t $(DOCKER_IMAGE) .
	@echo "[+] Docker image built successfully"

# Build Go tool
build-go:
	@echo "[*] Building Go tool..."
	cd $(TASK2_DIR) && go build -o build-stream8-kernel main.go
	@echo "[+] Go tool built: $(TASK2_DIR)/build-stream8-kernel"

# Build both
build-all: build-docker build-go
	@echo "[+] All components built successfully"

# Test build with original SRPM
test-build: build-all
	@echo "[*] Testing build with original SRPM..."
	@mkdir -p $(OUT_DIR)
	@if [ -f kernel-4.18.0-448.el8.src.rpm ]; then \
		$(TASK2_DIR)/build-stream8-kernel kernel-4.18.0-448.el8.src.rpm $(OUT_DIR); \
	else \
		echo "[!] Original SRPM not found. Download it first:"; \
		echo "    wget https://vault.centos.org/8-stream/BaseOS/Source/SPackages/kernel-4.18.0-448.el8.src.rpm"; \
	fi

# Create and build patched SRPM
build-patched: build-all
	@echo "[*] Creating patched SRPM..."
	@mkdir -p $(TASK3_DIR)/out
	@if [ -f kernel-4.18.0-448.el8.src.rpm ]; then \
		cd $(TASK3_DIR) && ./apply-patches.sh ../kernel-4.18.0-448.el8.src.rpm ./out ./work; \
		echo "[*] Building patched kernel..."; \
		cd ../$(TASK2_DIR) && ./build-stream8-kernel ../$(TASK3_DIR)/out/kernel-4.18.0-448.el8.patched.src.rpm ../$(TASK3_DIR)/out/rpms; \
	else \
		echo "[!] Original SRPM not found. Download it first:"; \
		echo "    wget https://vault.centos.org/8-stream/BaseOS/Source/SPackages/kernel-4.18.0-448.el8.src.rpm"; \
	fi

# Clean build artifacts
clean:
	@echo "[*] Cleaning build artifacts..."
	rm -rf $(OUT_DIR)
	rm -rf $(TASK3_DIR)/out
	rm -rf $(TASK3_DIR)/work
	rm -f $(TASK2_DIR)/build-stream8-kernel
	@echo "[+] Clean complete"
