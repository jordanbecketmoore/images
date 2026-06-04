FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    jq \
    bash \
    gnupg \
    openssh-server \
    && rm -rf /var/lib/apt/lists/*

# Node.js 22 LTS (required for Claude CLI)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# kubectl — pin to latest stable at build time
RUN ARCH=$(dpkg --print-architecture) \
    && KUBECTL_VERSION=$(curl -sSL https://dl.k8s.io/release/stable.txt) \
    && curl -sSLo /usr/local/bin/kubectl \
       "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" \
    && chmod +x /usr/local/bin/kubectl

# helm
RUN curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Claude CLI
RUN npm install -g @anthropic-ai/claude-code

RUN useradd -m -s /bin/bash -u 1001 agent \
    && mkdir -p /home/agent/.ssh \
    && chmod 700 /home/agent/.ssh

COPY sshd_config /etc/ssh/sshd_config
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22

ENTRYPOINT ["/entrypoint.sh"]
