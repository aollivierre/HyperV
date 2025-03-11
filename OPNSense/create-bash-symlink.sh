#!/bin/sh
# This script creates a symbolic link to /bin/sh called bash
# This helps VS Code's Remote SSH extension work with OPNsense

# Check if bash symlink already exists
if [ ! -e /usr/local/bin/bash ]; then
    # Create directory if it doesn't exist
    mkdir -p /usr/local/bin
    
    # Create symlink
    ln -s /bin/sh /usr/local/bin/bash
    
    echo "Created symlink: /usr/local/bin/bash -> /bin/sh"
else
    echo "Symlink already exists"
fi

# Make sure the path includes /usr/local/bin
PATH=$PATH:/usr/local/bin
export PATH

echo "Current PATH: $PATH"

# Test if bash is now accessible
which bash
