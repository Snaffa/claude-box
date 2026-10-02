#!/usr/bin/env bash
# Build the image, or start Claude Code in the container.
#   claude-box.sh build        build/rebuild the image (run from anywhere)
#   claude-box.sh [args...]    start Claude in the project you're currently in;
#                              run from inside ~/Projects/<project>. Extra
#                              arguments go to claude, e.g.
#                              claude-box.sh --dangerously-skip-permissions
set -euo pipefail

export HOST_UID=$(id -u) HOST_GID=$(id -g)
compose=(docker compose -f "$(dirname "$(realpath "$0")")/compose.yaml")

if [[ "${1:-}" == "build" ]]; then
    exec "${compose[@]}" build
fi

# The folder you launch from decides which project Claude opens in
# and which conda environment is activated.
workdir=$PWD
if [[ "$workdir" != "$HOME/Projects/"* ]]; then
    echo "claude-box: to launch, cd into a project under $HOME/Projects first" >&2
    exit 1
fi

# If the VS Code dev container is up, join it so everything shares one
# container; otherwise start a throwaway one.
if [[ "$(docker inspect -f '{{.State.Running}}' claude-box 2>/dev/null)" == true ]]; then
    exec docker exec -it -w "$workdir" claude-box bash -ic 'exec claude "$@"' claude "$@"
fi
"${compose[@]}" run --rm -w "$workdir" claude claude "$@"
