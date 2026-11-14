#!/usr/bin/env bash
# One long-lived container ("claude-box") for every project under ~/Projects,
# with Herdr running inside it: one Herdr workspace per project.
#   claude-box.sh build   build/rebuild the image (run from anywhere)
#   claude-box.sh         start the container if needed and open its Herdr
#   claude-box.sh stop    stop the container (ends every session in it)
# Claude runs with permissions bypassed in there: the container is the boundary
# (no ssh, lab share read-only; see compose.yaml).
set -euo pipefail

export HOST_UID=$(id -u) HOST_GID=$(id -g)
dir=$(dirname "$(realpath "$0")")
compose=(docker compose -p claude-box -f "$dir/compose.yaml" -f "$dir/compose.devcontainer.yaml")

case "${1:-}" in
    build) exec "${compose[@]}" build ;;
    stop)  exec docker stop claude-box ;;
esac

if [[ "$(docker inspect -f '{{.State.Running}}' claude-box 2>/dev/null)" != true ]]; then
    "${compose[@]}" up -d
fi
# SHELL makes Herdr panes start bash, whose ~/.bashrc switches conda env on cd
exec docker exec -it -e TERM -e COLORTERM -e SHELL=/bin/bash \
    -w "$HOME/Projects" claude-box herdr
