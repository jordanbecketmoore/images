build:
	@docker build -t k8s-agent:latest .

run:
	@docker run -it --rm \
		-p 2222:22 \
		-e SSH_AUTHORIZED_KEYS="$$(cat ~/.ssh/id_ed25519.pub 2>/dev/null || cat ~/.ssh/id_rsa.pub)" \
		-v ~/.claude/.credentials.json:/run/secrets/claude-credentials:ro \
		k8s-agent:latest

connect:
	@ssh -p 2222 agent@localhost
