// CentOS Stream 8 Kernel Build Tool
// A Go tool to build kernel SRPMs using Docker
package main

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

const (
	dockerImage = "stream8-kernel-builder"
	dockerCmd   = "docker"
)

func main() {
	if len(os.Args) != 3 {
		printUsage()
		os.Exit(1)
	}

	source := os.Args[1]
	outputDir := os.Args[2]

	// Validate Docker
	if err := checkDocker(); err != nil {
		fmt.Fprintf(os.Stderr, "[ERROR] %v\n", err)
		os.Exit(1)
	}

	// Validate Docker image exists
	if err := checkDockerImage(); err != nil {
		fmt.Fprintf(os.Stderr, "[ERROR] %v\n", err)
		os.Exit(1)
	}

	// Create output directory
	absOutput, err := filepath.Abs(outputDir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "[ERROR] Invalid output path: %v\n", err)
		os.Exit(1)
	}
	if err := os.MkdirAll(absOutput, 0755); err != nil {
		fmt.Fprintf(os.Stderr, "[ERROR] Cannot create output directory: %v\n", err)
		os.Exit(1)
	}

	// Get SRPM path (download if URL)
	srpmPath, cleanup, err := resolveSRPM(source)
	if err != nil {
		fmt.Fprintf(os.Stderr, "[ERROR] %v\n", err)
		os.Exit(1)
	}
	if cleanup != nil {
		defer cleanup()
	}

	// Run the build
	startTime := time.Now()
	fmt.Printf("[*] Starting kernel build at %s\n", startTime.Format(time.RFC1123))

	if err := runBuild(srpmPath, absOutput); err != nil {
		fmt.Fprintf(os.Stderr, "[ERROR] Build failed: %v\n", err)
		os.Exit(1)
	}

	elapsed := time.Since(startTime)
	fmt.Printf("\n[+] Build completed successfully in %s\n", elapsed.Round(time.Second))
	fmt.Printf("[*] Output directory: %s\n", absOutput)

	// List output files
	listOutputFiles(absOutput)
}

func printUsage() {
	fmt.Println("CentOS Stream 8 Kernel Build Tool")
	fmt.Println("")
	fmt.Println("Usage:")
	fmt.Println("  build-stream8-kernel <srpm_or_url> <output_directory>")
	fmt.Println("")
	fmt.Println("Examples:")
	fmt.Println("  build-stream8-kernel kernel-4.18.0-448.el8.src.rpm ./output")
	fmt.Println("  build-stream8-kernel https://vault.centos.org/.../kernel-4.18.0-448.el8.src.rpm ./output")
	fmt.Println("")
	fmt.Println("Requirements:")
	fmt.Println("  - Docker must be installed and running")
	fmt.Printf("  - Docker image '%s' must be built first\n", dockerImage)
	fmt.Println("")
	fmt.Println("Build the Docker image:")
	fmt.Println("  cd docker && docker build -t stream8-kernel-builder .")
}

func checkDocker() error {
	fmt.Println("[*] Checking Docker...")
	cmd := exec.Command(dockerCmd, "version", "--format", "{{.Server.Version}}")
	output, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("Docker is not available or not running. Please install/start Docker")
	}
	fmt.Printf("[+] Docker version: %s\n", strings.TrimSpace(string(output)))
	return nil
}

func checkDockerImage() error {
	fmt.Printf("[*] Checking for Docker image: %s\n", dockerImage)
	cmd := exec.Command(dockerCmd, "images", "-q", dockerImage)
	output, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("failed to check Docker images: %w", err)
	}
	if strings.TrimSpace(string(output)) == "" {
		return fmt.Errorf("Docker image '%s' not found.\n\nBuild it first:\n  cd docker && docker build -t %s .", dockerImage, dockerImage)
	}
	fmt.Printf("[+] Docker image found: %s\n", dockerImage)
	return nil
}

func resolveSRPM(source string) (string, func(), error) {
	// Check if URL
	if strings.HasPrefix(source, "http://") || strings.HasPrefix(source, "https://") {
		return downloadSRPM(source)
	}

	// Local file - get absolute path
	absPath, err := filepath.Abs(source)
	if err != nil {
		return "", nil, fmt.Errorf("invalid path: %w", err)
	}

	info, err := os.Stat(absPath)
	if err != nil {
		return "", nil, fmt.Errorf("SRPM not found: %s", absPath)
	}
	if info.IsDir() {
		return "", nil, fmt.Errorf("path is a directory, not a file: %s", absPath)
	}

	fmt.Printf("[*] Using local SRPM: %s\n", absPath)
	return absPath, nil, nil
}

func downloadSRPM(url string) (string, func(), error) {
	fmt.Printf("[*] Downloading SRPM from: %s\n", url)

	// Create temp directory
	tmpDir, err := os.MkdirTemp("", "kernel-build-*")
	if err != nil {
		return "", nil, fmt.Errorf("cannot create temp directory: %w", err)
	}

	cleanup := func() {
		os.RemoveAll(tmpDir)
	}

	// Extract filename from URL
	parts := strings.Split(url, "/")
	filename := parts[len(parts)-1]
	if !strings.HasSuffix(filename, ".src.rpm") {
		filename = "kernel.src.rpm"
	}

	destPath := filepath.Join(tmpDir, filename)

	// Download
	resp, err := http.Get(url)
	if err != nil {
		cleanup()
		return "", nil, fmt.Errorf("download failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		cleanup()
		return "", nil, fmt.Errorf("download failed: HTTP %d", resp.StatusCode)
	}

	file, err := os.Create(destPath)
	if err != nil {
		cleanup()
		return "", nil, fmt.Errorf("cannot create file: %w", err)
	}
	defer file.Close()

	size, err := io.Copy(file, resp.Body)
	if err != nil {
		cleanup()
		return "", nil, fmt.Errorf("download error: %w", err)
	}

	fmt.Printf("[+] Downloaded: %s (%.2f MB)\n", filename, float64(size)/(1024*1024))
	return destPath, cleanup, nil
}

func runBuild(srpmPath, outputDir string) error {
	fmt.Println("[*] Starting Docker container for build...")

	// Docker run command
	args := []string{
		"run",
		"--rm",
		"--user", "0",
		"-v", fmt.Sprintf("%s:/input.src.rpm:ro", srpmPath),
		"-v", fmt.Sprintf("%s:/out", outputDir),
		dockerImage,
		"/input.src.rpm",
		"/out",
	}

	fmt.Printf("[*] Running: docker %s\n", strings.Join(args[:5], " ")+"...")

	cmd := exec.Command(dockerCmd, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	return cmd.Run()
}

func listOutputFiles(dir string) {
	fmt.Println("\n[*] Built packages:")

	files, err := os.ReadDir(dir)
	if err != nil {
		return
	}

	for _, f := range files {
		if strings.HasSuffix(f.Name(), ".rpm") {
			info, err := f.Info()
			if err != nil {
				continue
			}
			size := float64(info.Size()) / (1024 * 1024)
			fmt.Printf("  %s (%.2f MB)\n", f.Name(), size)
		}
	}
}

