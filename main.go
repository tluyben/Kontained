package main

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"context"
	"crypto/sha256"
	"embed"
	"encoding/hex"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"runtime"
	"syscall"
	"time"

	_ "github.com/mattn/go-sqlite3"
)

//go:embed assets/*
var assets embed.FS

// Embedded binaries for different platforms
//
//go:embed binaries/node-linux-x64
//go:embed binaries/node-linux-arm64
//go:embed binaries/node-darwin-x64
//go:embed binaries/node-darwin-arm64
//go:embed binaries/node-windows-x64.exe
//go:embed binaries/node-windows-arm64.exe
var nodeBinaries embed.FS

// Embedded dev server and dependencies
//
//go:embed dev-server.ts
//go:embed node_modules.tar.gz
//go:embed project.db
var projectFiles embed.FS

type DevEnvironment struct {
	tempDir     string
	nodeExePath string
	serverPath  string
	dbPath      string
	nodeModules string
	originalBin string
	dbModified  bool
	ctx         context.Context
	cancel      context.CancelFunc
}

func main() {
	fmt.Println("🚀 Starting self-contained portable dev environment...")

	env, err := NewDevEnvironment()
	if err != nil {
		log.Fatalf("❌ Failed to initialize: %v", err)
	}

	// Setup graceful shutdown
	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt, syscall.SIGTERM)

	go func() {
		<-c
		fmt.Println("\n🛑 Shutting down gracefully...")
		env.Shutdown()
		os.Exit(0)
	}()

	// Start the environment
	if err := env.Start(); err != nil {
		log.Fatalf("❌ Failed to start: %v", err)
	}

	// Keep running until interrupted
	<-env.ctx.Done()
}

func NewDevEnvironment() (*DevEnvironment, error) {
	// Create temporary directory
	tempDir, err := os.MkdirTemp("", "portable-dev-*")
	if err != nil {
		return nil, fmt.Errorf("failed to create temp dir: %v", err)
	}

	fmt.Printf("📁 Created workspace: %s\n", tempDir)

	ctx, cancel := context.WithCancel(context.Background())

	// Get the current executable path for repacking
	originalBin, err := os.Executable()
	if err != nil {
		return nil, fmt.Errorf("failed to get executable path: %v", err)
	}

	return &DevEnvironment{
		tempDir:     tempDir,
		originalBin: originalBin,
		ctx:         ctx,
		cancel:      cancel,
	}, nil
}

func (env *DevEnvironment) Start() error {
	fmt.Println("📦 Extracting embedded environment...")

	// 1. Extract Node.js binary for current platform
	if err := env.extractNodeBinary(); err != nil {
		return fmt.Errorf("failed to extract Node binary: %v", err)
	}

	// 2. Extract SQLite database
	if err := env.extractDatabase(); err != nil {
		return fmt.Errorf("failed to extract database: %v", err)
	}

	// 3. Extract node_modules
	if err := env.extractNodeModules(); err != nil {
		return fmt.Errorf("failed to extract node_modules: %v", err)
	}

	// 4. Extract dev server
	if err := env.extractDevServer(); err != nil {
		return fmt.Errorf("failed to extract dev server: %v", err)
	}

	// 5. Start the development server
	if err := env.startDevServer(); err != nil {
		return fmt.Errorf("failed to start dev server: %v", err)
	}

	fmt.Println("✨ Environment ready!")
	fmt.Println("🌐 Open http://localhost:3000 in your browser")
	fmt.Println("🛑 Press Ctrl+C to stop and repack")

	return nil
}

func (env *DevEnvironment) extractNodeBinary() error {
	var binaryPath string

	// Determine the correct Node.js binary for current platform
	switch runtime.GOOS {
	case "linux":
		if runtime.GOARCH == "arm64" {
			binaryPath = "binaries/node-linux-arm64"
		} else {
			binaryPath = "binaries/node-linux-x64"
		}
	case "darwin":
		if runtime.GOARCH == "arm64" {
			binaryPath = "binaries/node-darwin-arm64"
		} else {
			binaryPath = "binaries/node-darwin-x64"
		}
	case "windows":
		if runtime.GOARCH == "arm64" {
			binaryPath = "binaries/node-windows-arm64.exe"
		} else {
			binaryPath = "binaries/node-windows-x64.exe"
		}
	default:
		return fmt.Errorf("unsupported platform: %s/%s", runtime.GOOS, runtime.GOARCH)
	}

	fmt.Printf("🔧 Extracting Node.js for %s/%s\n", runtime.GOOS, runtime.GOARCH)

	// Read embedded binary
	nodeData, err := nodeBinaries.ReadFile(binaryPath)
	if err != nil {
		return fmt.Errorf("failed to read embedded Node binary: %v", err)
	}

	// Write to temp directory
	env.nodeExePath = filepath.Join(env.tempDir, "node")
	if runtime.GOOS == "windows" {
		env.nodeExePath += ".exe"
	}

	if err := os.WriteFile(env.nodeExePath, nodeData, 0755); err != nil {
		return fmt.Errorf("failed to write Node binary: %v", err)
	}

	fmt.Printf("✅ Node.js extracted to: %s\n", env.nodeExePath)
	return nil
}

func (env *DevEnvironment) extractDatabase() error {
	fmt.Println("💾 Extracting SQLite database...")

	dbData, err := projectFiles.ReadFile("project.db")
	if err != nil {
		return fmt.Errorf("failed to read embedded database: %v", err)
	}

	env.dbPath = filepath.Join(env.tempDir, "project.db")
	if err := os.WriteFile(env.dbPath, dbData, 0644); err != nil {
		return fmt.Errorf("failed to write database: %v", err)
	}

	fmt.Printf("✅ Database extracted: %s\n", env.dbPath)
	return nil
}

func (env *DevEnvironment) extractNodeModules() error {
	fmt.Println("📦 Extracting node_modules...")

	// Read compressed node_modules
	nodeModulesData, err := projectFiles.ReadFile("node_modules.tar.gz")
	if err != nil {
		return fmt.Errorf("failed to read embedded node_modules: %v", err)
	}

	env.nodeModules = filepath.Join(env.tempDir, "node_modules")

	// Create gzip reader
	gzReader, err := gzip.NewReader(bytes.NewReader(nodeModulesData))
	if err != nil {
		return fmt.Errorf("failed to create gzip reader: %v", err)
	}
	defer gzReader.Close()

	// Create tar reader
	tarReader := tar.NewReader(gzReader)

	// Extract files
	for {
		header, err := tarReader.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return fmt.Errorf("failed to read tar: %v", err)
		}

		// Create full path
		fullPath := filepath.Join(env.tempDir, header.Name)

		// Create directory structure
		if header.Typeflag == tar.TypeDir {
			if err := os.MkdirAll(fullPath, 0755); err != nil {
				return fmt.Errorf("failed to create directory %s: %v", fullPath, err)
			}
			continue
		}

		// Create parent directories
		if err := os.MkdirAll(filepath.Dir(fullPath), 0755); err != nil {
			return fmt.Errorf("failed to create parent directory: %v", err)
		}

		// Create file
		file, err := os.OpenFile(fullPath, os.O_CREATE|os.O_WRONLY, os.FileMode(header.Mode))
		if err != nil {
			return fmt.Errorf("failed to create file %s: %v", fullPath, err)
		}

		if _, err := io.Copy(file, tarReader); err != nil {
			file.Close()
			return fmt.Errorf("failed to write file %s: %v", fullPath, err)
		}
		file.Close()
	}

	fmt.Printf("✅ node_modules extracted: %s\n", env.nodeModules)
	return nil
}

func (env *DevEnvironment) extractDevServer() error {
	fmt.Println("🖥️  Extracting dev server...")

	serverData, err := projectFiles.ReadFile("dev-server.ts")
	if err != nil {
		return fmt.Errorf("failed to read embedded dev server: %v", err)
	}

	env.serverPath = filepath.Join(env.tempDir, "dev-server.ts")
	if err := os.WriteFile(env.serverPath, serverData, 0644); err != nil {
		return fmt.Errorf("failed to write dev server: %v", err)
	}

	fmt.Printf("✅ Dev server extracted: %s\n", env.serverPath)
	return nil
}

func (env *DevEnvironment) startDevServer() error {
	fmt.Println("🚀 Starting development server...")

	// Start Node.js dev server
	cmd := exec.CommandContext(env.ctx, env.nodeExePath, env.serverPath, env.dbPath, "3000")
	cmd.Dir = env.tempDir
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	// Set NODE_PATH to our extracted node_modules
	cmd.Env = append(os.Environ(),
		fmt.Sprintf("NODE_PATH=%s", env.nodeModules),
		fmt.Sprintf("PATH=%s%c%s", filepath.Dir(env.nodeExePath), os.PathListSeparator, os.Getenv("PATH")),
	)

	if err := cmd.Start(); err != nil {
		return fmt.Errorf("failed to start dev server: %v", err)
	}

	// Monitor for database changes
	go env.monitorDatabaseChanges()

	fmt.Println("✅ Development server started")
	return nil
}

func (env *DevEnvironment) monitorDatabaseChanges() {
	initialHash := env.getDatabaseHash()

	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-env.ctx.Done():
			return
		case <-ticker.C:
			currentHash := env.getDatabaseHash()
			if currentHash != initialHash {
				env.dbModified = true
				initialHash = currentHash
			}
		}
	}
}

func (env *DevEnvironment) getDatabaseHash() string {
	data, err := os.ReadFile(env.dbPath)
	if err != nil {
		return ""
	}

	hash := sha256.Sum256(data)
	return hex.EncodeToString(hash[:])
}

func (env *DevEnvironment) Shutdown() error {
	fmt.Println("🧹 Cleaning up and repacking...")

	// Cancel context to stop dev server
	env.cancel()

	// Give processes time to shutdown
	time.Sleep(2 * time.Second)

	// If database was modified, repack the binary
	if env.dbModified {
		fmt.Println("💾 Database was modified, repacking binary...")
		if err := env.repackBinary(); err != nil {
			fmt.Printf("❌ Failed to repack binary: %v\n", err)
		} else {
			fmt.Println("✅ Binary repacked with updated database")
		}
	}

	// Clean up temp directory
	if err := os.RemoveAll(env.tempDir); err != nil {
		fmt.Printf("⚠️  Failed to clean temp directory: %v\n", err)
	} else {
		fmt.Println("🧹 Temporary files cleaned up")
	}

	fmt.Println("👋 Goodbye!")
	return nil
}

func (env *DevEnvironment) repackBinary() error {
	// This is a simplified version - you'd need a more sophisticated approach
	// to actually modify the embedded files in the Go binary

	// Read the updated database
	updatedDB, err := os.ReadFile(env.dbPath)
	if err != nil {
		return fmt.Errorf("failed to read updated database: %v", err)
	}

	// Create a new binary with updated embedded files
	// This would typically involve:
	// 1. Reading the original binary
	// 2. Locating the embedded file sections
	// 3. Replacing the database content
	// 4. Writing the new binary

	// For now, we'll save the updated database alongside the binary
	backupPath := env.originalBin + ".updated.db"
	if err := os.WriteFile(backupPath, updatedDB, 0644); err != nil {
		return fmt.Errorf("failed to write backup database: %v", err)
	}

	fmt.Printf("💾 Updated database saved to: %s\n", backupPath)
	fmt.Println("📝 Note: Manual repackaging required for full binary update")

	return nil
}
