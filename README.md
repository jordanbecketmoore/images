# k8s-agent

A container image that runs an SSH server, giving you an interactive shell with `claude`, `kubectl`, `helm`, `curl`, and `jq` pre-installed. Intended to run inside a Kubernetes cluster so Claude can interact with the API server using the pod's service account.

## Kubernetes requirements

### Secrets

Two secrets must be available to the pod.

**SSH authorized keys** — one or more public keys that may connect:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: k8s-agent-ssh
type: Opaque
stringData:
  authorized_keys: |
    ssh-ed25519 AAAA... you@host
```

**Claude authentication** — choose one of the two options below.

#### Option A: API key (pay-per-use)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: anthropic
type: Opaque
stringData:
  api_key: sk-ant-...
```

#### Option B: OAuth credentials (Pro/Max subscription)

Claude Code stores OAuth credentials in `~/.claude/.credentials.json` after you log in locally. Copy that file into a secret:

```sh
kubectl create secret generic claude-credentials \
  --from-file=.credentials.json=$HOME/.claude/.credentials.json
```

Then mount it into the pod instead of setting `ANTHROPIC_API_KEY` (see the Pod spec below).

### RBAC

The pod needs a service account with permissions appropriate for the tasks you intend Claude to perform. A read-only cluster-wide role is a reasonable starting point:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: k8s-agent
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: k8s-agent-viewer
subjects:
  - kind: ServiceAccount
    name: k8s-agent
    namespace: default
roleRef:
  kind: ClusterRole
  name: view
  apiGroup: rbac.authorization.k8s.io
```

Grant broader permissions (e.g. `edit` or a custom role) if you need Claude to create or modify resources.

### Pod

#### Option A: API key

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: k8s-agent
spec:
  serviceAccountName: k8s-agent
  containers:
    - name: agent
      image: <your-dockerhub-username>/k8s-agent:<tag>
      ports:
        - containerPort: 22
      env:
        - name: SSH_AUTHORIZED_KEYS
          valueFrom:
            secretKeyRef:
              name: k8s-agent-ssh
              key: authorized_keys
        - name: ANTHROPIC_API_KEY
          valueFrom:
            secretKeyRef:
              name: anthropic
              key: api_key
```

#### Option B: OAuth credentials

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: k8s-agent
spec:
  serviceAccountName: k8s-agent
  containers:
    - name: agent
      image: <your-dockerhub-username>/k8s-agent:<tag>
      ports:
        - containerPort: 22
      env:
        - name: SSH_AUTHORIZED_KEYS
          valueFrom:
            secretKeyRef:
              name: k8s-agent-ssh
              key: authorized_keys
      volumeMounts:
        - name: claude-credentials
          mountPath: /home/agent/.claude/.credentials.json
          subPath: .credentials.json
          readOnly: true
  volumes:
    - name: claude-credentials
      secret:
        secretName: claude-credentials
```

### Connecting

Forward the pod's SSH port to your local machine:

```sh
kubectl port-forward pod/k8s-agent 2222:22
```

Then connect in another terminal:

```sh
ssh -p 2222 agent@localhost
```

Once in the shell, run `claude` to start an interactive session. `kubectl` is pre-configured to use the pod's service account token, so it has whatever permissions were granted above.
