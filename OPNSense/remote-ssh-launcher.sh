#!/bin/sh
# This script is used to launch remote SSH sessions on OPNsense
# It works around the lack of bash on FreeBSD-based systems

# Set environment variables
export SHELL=/bin/sh

# Execute the command that's passed
exec /bin/sh "$@"
