#!/usr/bin/env bash
# Activate the conda env belonging to the project we were started in
# (the first folder under ~/Projects), then run the given command.
set -e
source /opt/conda/etc/profile.d/conda.sh

relative=${PWD#"$HOME/Projects/"}
project=${relative%%/*}

if conda env list | awk '{print $1}' | grep -qx -- "$project"; then
    conda activate "$project"
else
    echo "claude-box: no conda env for '${project}', using base" >&2
    conda activate base
fi

exec "$@"
