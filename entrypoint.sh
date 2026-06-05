#!/bin/bash
set -e

# Generate SSH host keys if not already present (e.g. mounted via Secret)
ssh-keygen -A

# Inject authorized public keys from env (set via Kubernetes Secret)
if [ -n "$SSH_AUTHORIZED_KEYS" ]; then
    echo "$SSH_AUTHORIZED_KEYS" > /home/agent/.ssh/authorized_keys
    chmod 600 /home/agent/.ssh/authorized_keys
    chown agent:agent /home/agent/.ssh/authorized_keys
fi

# Copy Claude credentials from staging mount so agent owns the file
if [ -f /run/secrets/claude-credentials ]; then
    cp /run/secrets/claude-credentials /home/agent/.claude/.credentials.json
    chown agent:agent /home/agent/.claude/.credentials.json
    chmod 600 /home/agent/.claude/.credentials.json
fi

# Make ANTHROPIC_API_KEY available to SSH sessions via the agent's login profile
mkdir -p /home/agent/.profile.d
if [ -n "$ANTHROPIC_API_KEY" ]; then
    echo "export ANTHROPIC_API_KEY='${ANTHROPIC_API_KEY}'" > /home/agent/.profile.d/anthropic.sh
fi

cat > /home/agent/.profile <<'EOF'
for f in ~/.profile.d/*.sh; do [ -r "$f" ] && . "$f"; done
unset f
EOF
chown -R agent:agent /home/agent/.profile.d /home/agent/.profile

mkdir -p /run/sshd

exec /usr/sbin/sshd -D -e
