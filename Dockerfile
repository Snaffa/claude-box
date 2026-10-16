# Shared sandbox for running Claude Code on any project under ~/Projects.
# Projects, Claude's memory, and the network share are mounted in at run time
# (see compose.yaml); only the conda environments are baked in.
FROM ubuntu:24.04

ARG USERNAME
ARG USER_UID=1000
ARG USER_GID=1000

# System tools Claude uses (git, ripgrep, pdftotext) plus the X/GL libraries
# that gmsh and pyvista need for offscreen rendering.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl git ripgrep less procps bzip2 poppler-utils \
        libgl1 libegl1 libglu1-mesa libxrender1 libxext6 libxcursor1 libxft2 libxinerama1 \
    && rm -rf /var/lib/apt/lists/*

# Match the host user so files written in mounted projects keep your ownership.
# (ubuntu:24.04 ships a default "ubuntu" user on UID 1000; remove it first.)
RUN userdel -r ubuntu 2>/dev/null || true \
    && groupadd -g ${USER_GID} ${USERNAME} \
    && useradd -m -u ${USER_UID} -g ${USER_GID} -s /bin/bash ${USERNAME}

RUN curl -fsSL https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh -o /tmp/miniforge.sh \
    && bash /tmp/miniforge.sh -b -p /opt/conda \
    && rm /tmp/miniforge.sh
ENV PATH=/opt/conda/bin:${PATH}

# One conda environment per project that has an environment.yml, named after
# the project folder (e.g. ~/Projects/MC-AI/environment.yml -> env "MC-AI").
# Naming by folder avoids clashes when two projects use the same env name.
COPY . /tmp/projects/
RUN for f in /tmp/projects/*/environment.yml; do \
        [ -e "$f" ] || continue; \
        project=$(basename "$(dirname "$f")"); \
        echo "=== creating env for ${project} ==="; \
        mamba env create -n "${project}" -f "$f" || exit 1; \
    done \
    && conda clean -afy \
    && rm -rf /tmp/projects

COPY --chmod=755 claude-box/entrypoint.sh /usr/local/bin/entrypoint.sh

USER ${USERNAME}

# Claude Code (native installer, lands in ~/.local/bin)
RUN curl -fsSL https://claude.ai/install.sh | bash
ENV PATH=/home/${USERNAME}/.local/bin:${PATH}

# Claude's config (login, settings) lives here; compose puts it on a named volume.
# The projects folder is pre-created so the bind mount over it isn't root-owned.
ENV CLAUDE_CONFIG_DIR=/home/${USERNAME}/.claude
RUN mkdir -p /home/${USERNAME}/.claude/projects

# Interactive shells (VS Code terminals, `docker exec`) skip the entrypoint, so
# ~/.bashrc does the same job: whenever you cd into a different project, switch
# to that project's conda env (base outside ~/Projects or if it has none).
# Written inline rather than COPYed so it doesn't invalidate the conda layer.
RUN cat >> /home/${USERNAME}/.bashrc <<'EOF'

# --- claude-box: per-project conda env ---
source /opt/conda/etc/profile.d/conda.sh
_claude_box_env() {
    local rel=${PWD#"$HOME/Projects/"} project=base
    [[ "$rel" != "$PWD" && -d "/opt/conda/envs/${rel%%/*}" ]] && project=${rel%%/*}
    [[ "$project" == "${_CLAUDE_BOX_PROJECT:-}" ]] && return
    _CLAUDE_BOX_PROJECT=$project
    conda activate "$project"
}
PROMPT_COMMAND="_claude_box_env${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
_claude_box_env
EOF

# ssh client and rsync for launching runs on the lab servers. Added last so it
# doesn't invalidate the conda layers above.
USER root
RUN apt-get update && apt-get install -y --no-install-recommends openssh-client rsync \
    && rm -rf /var/lib/apt/lists/*
USER ${USERNAME}

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["claude"]
