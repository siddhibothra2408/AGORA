#!/usr/bin/env bash
# Agora Demo Fixture Mode Startup Script (Bash)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
export AI_PROVIDER="fixture"
exec "$DIR/demo-up.sh" --fixture
