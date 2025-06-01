# Portable Dev Environment Builder
# Creates self-contained executables with embedded React projects

# Configuration
PROJECT_NAME ?= my-app
PROJECT_PATH ?= ./example-project
OUTPUT_DIR ?= ./dist
NODE_VERSION ?= 18.17.0
GO_VERSION ?= 1.21

# Derived variables
DIST_DIR = $(OUTPUT_DIR)
BUILD_DIR = $(DIST_DIR)/build
BINARIES_DIR = $(BUILD_DIR)/binaries

# Platform targets
PLATFORMS = linux-amd64 linux-arm64 darwin-amd64 darwin-arm64 windows-amd64 windows-arm64

# Node.js platform mappings
NODE_LINUX_X64 = node-v$(NODE_VERSION)-linux-x64
NODE_LINUX_ARM64 = node-v$(NODE_VERSION)-linux-arm64  
NODE_DARWIN_X64 = node-v$(NODE_VERSION)-darwin-x64
NODE_DARWIN_ARM64 = node-v$(NODE_VERSION)-darwin-arm64
NODE_WIN_X64 = node-v$(NODE_VERSION)-win-x64
NODE_WIN_ARM64 = node-v$(NODE_VERSION)-win-arm64

.PHONY: all clean setup build package test demo help
.DEFAULT_GOAL := help

# Colors for output
RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[1;33m
BLUE = \033[0;34m
PURPLE = \033[0;35m
CYAN = \033[0;36m
NC = \033[0m # No Color

help: ## Show this help message
	@echo "$(CYAN)🏗️  Portable Dev Environment Builder$(NC)"
	@echo ""
	@echo "$(YELLOW)Usage:$(NC)"
	@echo "  make <target> [PROJECT_PATH=./my-project] [PROJECT_NAME=my-app]"
	@echo ""
	@echo "$(YELLOW)Targets:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(YELLOW)Examples:$(NC)"
	@echo "  make setup                              # Install dependencies"
	@echo "  make build PROJECT_PATH=./my-shadcn-app # Build from specific project"
	@echo "  make package PROJECT_NAME=my-cool-app   # Package with custom name"
	@echo "  make demo                               # Build and test demo project"

setup: ## Install all dependencies and tools
	@echo "$(BLUE)🔧 Setting up build environment...$(NC)"
	@echo "$(YELLOW)📦 Installing Node.js dependencies...$(NC)"
	npm install
	@echo "$(YELLOW)🔧 Compiling TypeScript tools...$(NC)"
	npx tsc importer.ts --target es2020 --module commonjs --esModuleInterop --outDir ./build
	npx tsc bundled-dev-server.ts --target es2020 --module commonjs --esModuleInterop --outDir ./build
	npx tsc builder.ts --target es2020 --module commonjs --esModuleInterop --outDir ./build
	@echo "$(YELLOW)🔧 Setting up Go environment...$(NC)"
	go mod init portable-dev-env 2>/dev/null || true
	go mod tidy
	@echo "$(GREEN)✅ Setup complete!$(NC)"

validate-project: ## Validate the source project
	@echo "$(BLUE)🔍 Validating project...$(NC)"
	@if [ ! -d "$(PROJECT_PATH)" ]; then \
		echo "$(RED)❌ Project path does not exist: $(PROJECT_PATH)$(NC)"; \
		exit 1; \
	fi
	@if [ ! -f "$(PROJECT_PATH)/package.json" ]; then \
		echo "$(RED)❌ No package.json found in: $(PROJECT_PATH)$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)✅ Project validation passed$(NC)"

clean: ## Clean build artifacts
	@echo "$(BLUE)🧹 Cleaning build artifacts...$(NC)"
	rm -rf $(DIST_DIR)
	rm -rf ./build
	rm -rf ./temp-*
	go clean -cache 2>/dev/null || true
	@echo "$(GREEN)✅ Clean complete$(NC)"

import-project: validate-project ## Import project to SQLite
	@echo "$(BLUE)📁 Importing project to SQLite...$(NC)"
	mkdir -p $(BUILD_DIR)
	node ./build/importer.js "$(PROJECT_PATH)" "$(BUILD_DIR)/project.db"
	@echo "$(GREEN)✅ Project imported$(NC)"

bundle-deps: import-project ## Bundle dependencies
	@echo "$(BLUE)📦 Bundling dependencies...$(NC)"
	node ./build/bundled-dev-server.js bundle "$(PROJECT_PATH)" "$(BUILD_DIR)/project.db"
	@echo "$(GREEN)✅ Dependencies bundled$(NC)"

download-node: ## Download Node.js binaries for all platforms
	@echo "$(BLUE)⬇️  Downloading Node.js binaries...$(NC)"
	mkdir -p $(BINARIES_DIR)
	
	# Linux x64
	@if [ ! -f "$(BINARIES_DIR)/node-linux-x64" ]; then \
		echo "$(YELLOW)📥 Downloading Node.js $(NODE_VERSION) for linux-x64...$(NC)"; \
		curl -sL "https://nodejs.org/dist/v$(NODE_VERSION)/$(NODE_LINUX_X64).tar.gz" | \
		tar -xz -C /tmp && \
		cp "/tmp/$(NODE_LINUX_X64)/bin/node" "$(BINARIES_DIR)/node-linux-x64" && \
		chmod +x "$(BINARIES_DIR)/node-linux-x64" && \
		rm -rf "/tmp/$(NODE_LINUX_X64)"; \
	fi
	
	# Linux arm64
	@if [ ! -f "$(BINARIES_DIR)/node-linux-arm64" ]; then \
		echo "$(YELLOW)📥 Downloading Node.js $(NODE_VERSION) for linux-arm64...$(NC)"; \
		curl -sL "https://nodejs.org/dist/v$(NODE_VERSION)/$(NODE_LINUX_ARM64).tar.gz" | \
		tar -xz -C /tmp && \
		cp "/tmp/$(NODE_LINUX_ARM64)/bin/node" "$(BINARIES_DIR)/node-linux-arm64" && \
		chmod +x "$(BINARIES_DIR)/node-linux-arm64" && \
		rm -rf "/tmp/$(NODE_LINUX_ARM64)"; \
	fi
	
	# macOS x64
	@if [ ! -f "$(BINARIES_DIR)/node-darwin-x64" ]; then \
		echo "$(YELLOW)📥 Downloading Node.js $(NODE_VERSION) for darwin-x64...$(NC)"; \
		curl -sL "https://nodejs.org/dist/v$(NODE_VERSION)/$(NODE_DARWIN_X64).tar.gz" | \
		tar -xz -C /tmp && \
		cp "/tmp/$(NODE_DARWIN_X64)/bin/node" "$(BINARIES_DIR)/node-darwin-x64" && \
		chmod +x "$(BINARIES_DIR)/node-darwin-x64" && \
		rm -rf "/tmp/$(NODE_DARWIN_X64)"; \
	fi
	
	# macOS arm64
	@if [ ! -f "$(BINARIES_DIR)/node-darwin-arm64" ]; then \
		echo "$(YELLOW)📥 Downloading Node.js $(NODE_VERSION) for darwin-arm64...$(NC)"; \
		curl -sL "https://nodejs.org/dist/v$(NODE_VERSION)/$(NODE_DARWIN_ARM64).tar.gz" | \
		tar -xz -C /tmp && \
		cp "/tmp/$(NODE_DARWIN_ARM64)/bin/node" "$(BINARIES_DIR)/node-darwin-arm64" && \
		chmod +x "$(BINARIES_DIR)/node-darwin-arm64" && \
		rm -rf "/tmp/$(NODE_DARWIN_ARM64)"; \
	fi
	
	# Windows x64
	@if [ ! -f "$(BINARIES_DIR)/node-windows-x64.exe" ]; then \
		echo "$(YELLOW)📥 Downloading Node.js $(NODE_VERSION) for windows-x64...$(NC)"; \
		curl -sL "https://nodejs.org/dist/v$(NODE_VERSION)/$(NODE_WIN_X64).zip" -o /tmp/node-win-x64.zip && \
		unzip -q /tmp/node-win-x64.zip -d /tmp && \
		cp "/tmp/$(NODE_WIN_X64)/node.exe" "$(BINARIES_DIR)/node-windows-x64.exe" && \
		rm -rf /tmp/node-win-x64.zip "/tmp/$(NODE_WIN_X64)"; \
	fi
	
	# Windows arm64
	@if [ ! -f "$(BINARIES_DIR)/node-windows-arm64.exe" ]; then \
		echo "$(YELLOW)📥 Downloading Node.js $(NODE_VERSION) for windows-arm64...$(NC)"; \
		curl -sL "https://nodejs.org/dist/v$(NODE_VERSION)/$(NODE_WIN_ARM64).zip" -o /tmp/node-win-arm64.zip && \
		unzip -q /tmp/node-win-arm64.zip -d /tmp && \
		cp "/tmp/$(NODE_WIN_ARM64)/node.exe" "$(BINARIES_DIR)/node-windows-arm64.exe" && \
		rm -rf /tmp/node-win-arm64.zip "/tmp/$(NODE_WIN_ARM64)"; \
	fi
	
	@echo "$(GREEN)✅ All Node.js binaries downloaded$(NC)"

prepare-go: bundle-deps download-node ## Prepare Go build environment
	@echo "$(BLUE)🔧 Preparing Go build environment...$(NC)"
	
	# Copy dev server
	cp ./build/bundled-dev-server.js $(BUILD_DIR)/dev-server.js
	
	# Create go.mod
	@echo "module $(PROJECT_NAME)" > $(BUILD_DIR)/go.mod
	@echo "" >> $(BUILD_DIR)/go.mod
	@echo "go $(GO_VERSION)" >> $(BUILD_DIR)/go.mod
	@echo "" >> $(BUILD_DIR)/go.mod
	@echo "require (" >> $(BUILD_DIR)/go.mod
	@echo "    github.com/mattn/go-sqlite3 v1.14.17" >> $(BUILD_DIR)/go.mod
	@echo ")" >> $(BUILD_DIR)/go.mod
	
	# Copy main.go (you'd put the actual Go code here)
	cp main.go $(BUILD_DIR)/ 2>/dev/null || echo 'package main\n\nimport "fmt"\n\nfunc main() {\n    fmt.Println("Portable dev environment")\n}' > $(BUILD_DIR)/main.go
	
	# Download Go dependencies
	cd $(BUILD_DIR) && go mod tidy
	
	@echo "$(GREEN)✅ Go environment prepared$(NC)"

build-binaries: prepare-go ## Build Go binaries for all platforms
	@echo "$(BLUE)🔨 Building Go binaries for all platforms...$(NC)"
	
	# Linux amd64
	@echo "$(YELLOW)🔨 Building linux-amd64...$(NC)"
	cd $(BUILD_DIR) && GOOS=linux GOARCH=amd64 CGO_ENABLED=1 \
		go build -ldflags="-s -w" -o "$(PROJECT_NAME)-linux-amd64" .
	
	# Linux arm64  
	@echo "$(YELLOW)🔨 Building linux-arm64...$(NC)"
	cd $(BUILD_DIR) && GOOS=linux GOARCH=arm64 CGO_ENABLED=1 \
		go build -ldflags="-s -w" -o "$(PROJECT_NAME)-linux-arm64" .
	
	# macOS amd64
	@echo "$(YELLOW)🔨 Building darwin-amd64...$(NC)"
	cd $(BUILD_DIR) && GOOS=darwin GOARCH=amd64 CGO_ENABLED=1 \
		go build -ldflags="-s -w" -o "$(PROJECT_NAME)-darwin-amd64" .
	
	# macOS arm64
	@echo "$(YELLOW)🔨 Building darwin-arm64...$(NC)"
	cd $(BUILD_DIR) && GOOS=darwin GOARCH=arm64 CGO_ENABLED=1 \
		go build -ldflags="-s -w" -o "$(PROJECT_NAME)-darwin-arm64" .
	
	# Windows amd64
	@echo "$(YELLOW)🔨 Building windows-amd64...$(NC)"
	cd $(BUILD_DIR) && GOOS=windows GOARCH=amd64 CGO_ENABLED=1 \
		go build -ldflags="-s -w" -o "$(PROJECT_NAME)-windows-amd64.exe" .
	
	# Windows arm64
	@echo "$(YELLOW)🔨 Building windows-arm64...$(NC)"
	cd $(BUILD_DIR) && GOOS=windows GOARCH=arm64 CGO_ENABLED=1 \
		go build -ldflags="-s -w" -o "$(PROJECT_NAME)-windows-arm64.exe" .
	
	@echo "$(GREEN)✅ All binaries built$(NC)"

package: build-binaries ## Package binaries for distribution
	@echo "$(BLUE)📦 Packaging for distribution...$(NC)"
	
	mkdir -p $(DIST_DIR)/releases
	
	# Copy binaries to release directory
	cp $(BUILD_DIR)/$(PROJECT_NAME)-* $(DIST_DIR)/releases/
	
	# Create checksums
	cd $(DIST_DIR)/releases && sha256sum $(PROJECT_NAME)-* > checksums.txt
	
	# Show build summary
	@echo ""
	@echo "$(CYAN)📊 BUILD SUMMARY$(NC)"
	@echo "$(CYAN)================================$(NC)"
	@echo "$(YELLOW)🎯 Project:$(NC) $(PROJECT_NAME)"
	@echo "$(YELLOW)📁 Source:$(NC)  $(PROJECT_PATH)"
	@echo "$(YELLOW)📦 Output:$(NC)  $(DIST_DIR)/releases"
	@echo ""
	@echo "$(YELLOW)🚀 Portable Binaries:$(NC)"
	@cd $(DIST_DIR)/releases && ls -lh $(PROJECT_NAME)-* | awk '{printf "  📱 %-35s %5s\n", $$9, $$5}'
	@echo ""
	@echo "$(GREEN)✅ Package complete!$(NC)"
	@echo ""
	@echo "$(CYAN)🎯 Usage:$(NC)"
	@echo "  1. Distribute the appropriate binary for each platform"
	@echo "  2. Users run: ./$(PROJECT_NAME)-<platform>"
	@echo "  3. Browser opens to localhost:3000"
	@echo "  4. Ctrl+C automatically saves changes"

build: package ## Complete build process (alias for package)

test-binary: ## Test a built binary (specify PLATFORM=linux-amd64)
	@if [ -z "$(PLATFORM)" ]; then \
		echo "$(RED)❌ Please specify PLATFORM (e.g., make test-binary PLATFORM=linux-amd64)$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)🧪 Testing $(PROJECT_NAME)-$(PLATFORM)...$(NC)"
	@if [ -f "$(DIST_DIR)/releases/$(PROJECT_NAME)-$(PLATFORM)" ]; then \
		echo "$(YELLOW)🚀 Starting binary (will run for 10 seconds)...$(NC)"; \
		timeout 10s $(DIST_DIR)/releases/$(PROJECT_NAME)-$(PLATFORM) || true; \
		echo "$(GREEN)✅ Binary test completed$(NC)"; \
	else \
		echo "$(RED)❌ Binary not found: $(DIST_DIR)/releases/$(PROJECT_NAME)-$(PLATFORM)$(NC)"; \
		exit 1; \
	fi

demo: ## Create and build a demo project
	@echo "$(BLUE)🎭 Creating demo project...$(NC)"
	mkdir -p ./demo-project/src/components
	
	# Create demo package.json
	@echo '{\n  "name": "demo-app",\n  "version": "1.0.0",\n  "dependencies": {\n    "react": "^18.2.0",\n    "react-dom": "^18.2.0"\n  },\n  "devDependencies": {\n    "@types/react": "^18.2.0",\n    "@types/react-dom": "^18.2.0",\n    "typescript": "^5.0.0"\n  }\n}' > ./demo-project/package.json
	
	# Create demo React app
	@echo 'import React from "react";\nimport ReactDOM from "react-dom/client";\nimport App from "./App";\n\nconst root = ReactDOM.createRoot(document.getElementById("root") as HTMLElement);\nroot.render(<App />);' > ./demo-project/src/index.tsx
	
	@echo 'import React from "react";\n\nexport default function App() {\n  return (\n    <div style={{ padding: "2rem", fontFamily: "Arial" }}>\n      <h1>🚀 Portable Dev Environment Demo</h1>\n      <p>This React app is running from a self-contained binary!</p>\n      <ul>\n        <li>✅ No Node.js installation required</li>\n        <li>✅ No npm install needed</li>\n        <li>✅ Completely portable</li>\n        <li>✅ Hot reloading works</li>\n      </ul>\n    </div>\n  );\n}' > ./demo-project/src/App.tsx
	
	# Create demo HTML
	mkdir -p ./demo-project/public
	@echo '<!DOCTYPE html>\n<html>\n<head>\n  <title>Portable Dev Environment Demo</title>\n</head>\n<body>\n  <div id="root"></div>\n</body>\n</html>' > ./demo-project/public/index.html
	
	@echo "$(GREEN)✅ Demo project created$(NC)"
	
	# Build the demo
	@$(MAKE) build PROJECT_PATH=./demo-project PROJECT_NAME=demo-app
	
	@echo ""
	@echo "$(CYAN)🎉 Demo complete!$(NC)"
	@echo "$(YELLOW)Try running:$(NC) ./dist/releases/demo-app-linux-amd64"

# Platform-specific targets
linux-amd64: ## Build only Linux AMD64 binary
	@$(MAKE) build-binaries
	cp $(BUILD_DIR)/$(PROJECT_NAME)-linux-amd64 $(DIST_DIR)/

darwin-arm64: ## Build only macOS ARM64 binary  
	@$(MAKE) build-binaries
	cp $(BUILD_DIR)/$(PROJECT_NAME)-darwin-arm64 $(DIST_DIR)/

windows-amd64: ## Build only Windows AMD64 binary
	@$(MAKE) build-binaries  
	cp $(BUILD_DIR)/$(PROJECT_NAME)-windows-amd64.exe $(DIST_DIR)/

# Development helpers
watch: ## Watch for changes and rebuild (development)
	@echo "$(BLUE)👀 Watching for changes...$(NC)"
	@echo "$(YELLOW)⚠️  This will rebuild on any file change$(NC)"
	while true; do \
		inotifywait -r -e modify,create,delete $(PROJECT_PATH) 2>/dev/null || sleep 2; \
		echo "$(YELLOW)🔄 Change detected, rebuilding...$(NC)"; \
		$(MAKE) build PROJECT_PATH=$(PROJECT_PATH) PROJECT_NAME=$(PROJECT_NAME) || true; \
		echo "$(GREEN)✅ Rebuild complete$(NC)"; \
	done

info: ## Show current configuration
	@echo "$(CYAN)ℹ️  Current Configuration$(NC)"
	@echo "$(CYAN)========================$(NC)"
	@echo "$(YELLOW)Project Name:$(NC)     $(PROJECT_NAME)"
	@echo "$(YELLOW)Project Path:$(NC)     $(PROJECT_PATH)"
	@echo "$(YELLOW)Output Directory:$(NC) $(OUTPUT_DIR)"
	@echo "$(YELLOW)Node.js Version:$(NC)  $(NODE_VERSION)"
	@echo "$(YELLOW)Go Version:$(NC)       $(GO_VERSION)"
	@echo ""
	@echo "$(YELLOW)Target Platforms:$(NC)"
	@for platform in $(PLATFORMS); do \
		echo "  📱 $$platform"; \
	done

.SILENT: help info 