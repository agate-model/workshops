FROM julia:1.10

ENV DEBIAN_FRONTEND=noninteractive
ENV JULIA_NUM_THREADS=auto
ENV JULIA_PROJECT=/opt/agate-workshop-env
ENV PATH="/root/.local/bin:${PATH}"

# System dependencies for code-server, Julia package builds, and plotting backends.
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    curl \
    ca-certificates \
    git \
    build-essential \
    libgl1 \
    libglx-mesa0 \
    libegl1 \
    libxrender1 \
    libxext6 \
    libx11-6 \
    libfontconfig1 \
    libfreetype6 \
    libglib2.0-0 \
    libdbus-1-3 \
    libxi6 \
    libxrandr2 \
    libxinerama1 \
    libxcursor1 \
    libxcomposite1 \
    libasound2 \
    && rm -rf /var/lib/apt/lists/*

# Install code-server.
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Verify Julia path.
RUN command -v julia && julia --version

# Create the Julia workshop environment and install Agate.jl 0.4.0 from the registry.
RUN julia -e 'using Pkg; \
    Pkg.activate("/opt/agate-workshop-env"); \
    Pkg.add(Pkg.PackageSpec(name="Agate", version="0.4.0")); \
    Pkg.add(["CairoMakie", "NCDatasets", "DataFrames", "CSV", "Statistics"]); \
    Pkg.precompile()'

# Install the Julia VS Code extension inside code-server.
# If this fails because the marketplace endpoint changes, the container still works:
# users can run Julia scripts from the integrated terminal.
RUN code-server --install-extension julialang.language-julia || true

# User settings for code-server.
RUN mkdir -p /root/.local/share/code-server/User \
    && cat > /root/.local/share/code-server/User/settings.json <<'EOF'
{
  "workbench.colorTheme": "Default Dark Modern",
  "workbench.preferredDarkColorTheme": "Default Dark Modern",

  "workbench.activityBar.location": "hidden",
  "window.menuBarVisibility": "hidden",
  "workbench.layoutControl.enabled": false,
  "workbench.statusBar.visible": true,
  "workbench.startupEditor": "readme",
  "workbench.editor.enablePreview": false,
  "workbench.tips.enabled": false,
  "workbench.welcomePage.walkthroughs.openOnInstall": false,
  "workbench.commandCenter": false,

  "chat.disableAIFeatures": true,
  "chat.commandCenter.enabled": false,
  "chat.agent.enabled": false,
  "github.copilot.chat.enabled": false,
  "github.copilot.enable": {
    "*": false,
    "julia": false,
    "markdown": false,
    "plaintext": false
  },

  "git.enabled": false,
  "scm.diffDecorations": "none",

  "extensions.ignoreRecommendations": true,
  "extensions.showRecommendationsOnlyOnDemand": true,

  "telemetry.telemetryLevel": "off",
  "update.mode": "none",

  "julia.environmentPath": "/opt/agate-workshop-env",
  "julia.executablePath": "/usr/local/bin/julia"
}
EOF

# Remove common chat keyboard shortcuts. Command IDs vary between VS Code/code-server versions.
RUN cat > /root/.local/share/code-server/User/keybindings.json <<'EOF'
[
  { "key": "ctrl+alt+i", "command": "-workbench.action.chat.open" },
  { "key": "cmd+alt+i", "command": "-workbench.action.chat.open" },
  { "key": "ctrl+i", "command": "-workbench.action.chat.open" },
  { "key": "cmd+i", "command": "-workbench.action.chat.open" },
  { "key": "ctrl+shift+i", "command": "-workbench.action.chat.open" },
  { "key": "cmd+shift+i", "command": "-workbench.action.chat.open" },
  { "key": "ctrl+shift+i", "command": "-workbench.action.quickchat.toggle" },
  { "key": "cmd+shift+i", "command": "-workbench.action.quickchat.toggle" },
  { "key": "ctrl+i", "command": "-inlineChat.start" },
  { "key": "cmd+i", "command": "-inlineChat.start" }
]
EOF

# Runtime wrapper. It writes workspace settings after /workspace has been mounted,
# because image-time files under /workspace are hidden by the bind mount.
RUN cat > /usr/local/bin/start-code-server <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

mkdir -p /workspace/.vscode

cat > /workspace/.vscode/settings.json <<'JSON'
{
  "workbench.colorTheme": "Default Dark Modern",
  "workbench.activityBar.location": "hidden",
  "window.menuBarVisibility": "hidden",
  "workbench.layoutControl.enabled": false,
  "workbench.commandCenter": false,

  "chat.disableAIFeatures": true,
  "chat.commandCenter.enabled": false,
  "chat.agent.enabled": false,
  "github.copilot.chat.enabled": false,
  "github.copilot.enable": {
    "*": false,
    "julia": false,
    "markdown": false,
    "plaintext": false
  },

  "git.enabled": false,
  "extensions.ignoreRecommendations": true,
  "telemetry.telemetryLevel": "off",

  "julia.environmentPath": "/opt/agate-workshop-env",
  "julia.executablePath": "/usr/local/bin/julia"
}
JSON

exec code-server \
  --bind-addr 0.0.0.0:8080 \
  --auth none \
  --disable-telemetry \
  --disable-update-check \
  /workspace
EOF

RUN chmod +x /usr/local/bin/start-code-server

WORKDIR /workspace
EXPOSE 8080

CMD ["/usr/local/bin/start-code-server"]