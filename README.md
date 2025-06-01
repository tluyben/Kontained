# Portable Development Environment

A portable development environment system for React applications that bundles all dependencies and provides instant startup.

## Features

- 🚀 Instant startup with bundled dependencies
- 📦 Single binary distribution
- 🔄 Hot Module Replacement (HMR) support
- 💾 SQLite-based project storage
- 🔒 Secure and isolated environment
- 🎯 Cross-platform support (Linux, macOS, Windows)

## Prerequisites

- Go 1.21 or later
- Node.js 18 or later
- Make

## Installation

1. Clone the repository:

```bash
git clone https://github.com/yourusername/portable-dev-env.git
cd portable-dev-env
```

2. Install dependencies:

```bash
make setup
```

## Usage

### Building a Portable Environment

1. Create a new React project or use an existing one:

```bash
npx create-react-app my-app
# or
npx create-next-app my-app
```

2. Build the portable environment:

```bash
make build PROJECT_PATH=./my-app
```

This will create a self-contained executable in the `dist` directory.

### Running the Portable Environment

Simply run the generated binary:

```bash
./dist/portable-dev-env
```

The development server will start automatically with hot reloading enabled.

## Advanced Usage

### Custom Port

You can specify a custom port:

```bash
./dist/portable-dev-env --port 3001
```

### Development Mode

For development and testing:

```bash
make watch PROJECT_PATH=./my-app
```

### Platform-Specific Builds

Build for specific platforms:

```bash
make build-linux PROJECT_PATH=./my-app
make build-macos PROJECT_PATH=./my-app
make build-windows PROJECT_PATH=./my-app
```

## Project Structure

```
portable-dev-env/
├── assets/              # Embedded assets
├── binaries/           # Platform-specific binaries
├── dist/              # Build output
├── main.go            # Main Go application
├── dev-server.js      # Development server
├── importer.ts        # Project importer
├── Makefile          # Build system
├── package.json      # Node.js dependencies
└── tsconfig.json     # TypeScript configuration
```

## Development

### Adding New Features

1. Modify the Go code in `main.go`
2. Update the development server in `dev-server.js`
3. Rebuild using `make build`

### Testing

```bash
make test-binary PLATFORM=darwin
```

## License

MIT

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request
