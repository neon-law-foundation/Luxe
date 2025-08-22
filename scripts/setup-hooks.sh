#!/bin/bash

# Setup script to install git hooks from .githooks directory

echo "Setting up git hooks..."

# Copy hooks from .githooks to .git/hooks
if [ -d ".githooks" ]; then
    for hook in .githooks/*; do
        if [ -f "$hook" ]; then
            hook_name=$(basename "$hook")
            echo "Installing $hook_name hook..."
            cp "$hook" ".git/hooks/$hook_name"
            chmod +x ".git/hooks/$hook_name"
        fi
    done
    echo "Git hooks installed successfully!"
else
    echo "No .githooks directory found"
    exit 1
fi