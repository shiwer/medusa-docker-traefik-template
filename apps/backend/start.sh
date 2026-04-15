#!/usr/bin/env bash
set -euo pipefail

# Function to print usage instructions
print_usage() {
    cat << EOF
Usage: ./start.sh [options]

This script starts the Medusa server.

Options:
  --help                    Show this help message
  --build-folder=<path>     Specify custom build folder path (default: .medusa/server)

Examples:
  ./start.sh
  ./start.sh --build-folder=./custom-path
EOF
    exit 0
}

BUILD_FOLDER=".medusa/server"
ROOT_FOLDER=$(pwd)

while [ $# -gt 0 ]; do
    case "$1" in
        --help|-h)
            print_usage
            ;;
        --build-folder=*)
            BUILD_FOLDER="${1#*=}"
            ;;
        --build-folder)
            BUILD_FOLDER="$2"
            shift
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            print_usage
            ;;
    esac
    shift
done

# Create symbolic link for node_modules if it doesn't exist in build folder
if [ ! -e "$BUILD_FOLDER/node_modules" ]; then
    echo "Creating symbolic link for node_modules in build folder..."
    mkdir -p "${BUILD_FOLDER}"
    if [ -d "$ROOT_FOLDER/node_modules" ]; then
        ln -s "$ROOT_FOLDER/node_modules" "$BUILD_FOLDER/node_modules"
        echo "Symbolic link created successfully"
    else
        echo "Error: node_modules not found in root folder" >&2
        exit 1
    fi
fi

# Create symbolic link for static folder if it doesn't exist in build folder
if [ ! -e "$BUILD_FOLDER/static" ]; then
    echo "Creating symbolic link for static folder in build folder..."
    mkdir -p "${BUILD_FOLDER}"
    if [ -d "$ROOT_FOLDER/static" ]; then
        ln -s "$ROOT_FOLDER/static" "$BUILD_FOLDER/static"
        echo "Static symlink created successfully"
    else
        echo "Error: static folder not found in root folder" >&2
        exit 1
    fi
fi

echo "🚀 Starting Medusa server..."
cd "${BUILD_FOLDER}" || exit 1
exec npx medusa start
