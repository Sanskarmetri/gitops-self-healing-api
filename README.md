# gitops-self-healing-api

A simple Task/Todo REST API built with **Java 17**, **Spring Boot**, and **Maven**. It was created as the starter application for a college DevOps assignment. Data is stored only in memory — no database and no authentication.

## What the application does

- Lets you store Todo items in an in-memory list.
- Returns all todos as JSON.
- Provides a health endpoint that reports the application status.
- Runs on port **8080**.

## How to run it

Requirements: Java 17+ and Maven.

```bash
# Build the project
mvn clean package

# Run the application
mvn spring-boot:run
```

Or run the packaged jar:

```bash
java -jar target/gitops-self-healing-api-1.0.0.jar
```

The application starts at `http://localhost:8080`.

## API endpoints

| Method | Path     | Description                          | Request body example                                      |
|--------|----------|--------------------------------------|-----------------------------------------------------------|
| GET    | `/todos` | Return all todos                     | —                                                         |
| POST   | `/todos` | Add a new todo                       | `{"title": "Buy milk", "completed": false}`               |
| GET    | `/health`| Return application health status     | —                                                         |

### Example responses

`GET /health`

```json
{"status": "UP"}
```

`POST /todos`

```json
{"id": 1, "title": "Buy milk", "completed": false}
```

## How to test it

Run the unit tests with Maven:

```bash
mvn test
```

Test the endpoints manually with `curl`:

```bash
# Check health
curl http://localhost:8080/health

# Add a todo
curl -X POST http://localhost:8080/todos \
  -H "Content-Type: application/json" \
  -d '{"title": "Buy milk", "completed": false}'

# Get all todos
curl http://localhost:8080/todos
```

## Docker containerization (GitOps stage)

The application is packaged as a container image built from the Maven-produced
JAR (`target/gitops-self-healing-api-1.0.0.jar`). The image uses a lightweight
Java 21 runtime (`eclipse-temurin:21-jre-alpine`) and runs the app as a
non-root user.

### Build the image

```bash
# JAR must exist first
mvn -q package -DskipTests

docker build -t gitops-self-healing-api .
```

`docker build` will print the image ID. The `.dockerignore` keeps the build
context small (excludes `.git`, `ansible/`, generated Ansible SSH keys).

### Run the container

```bash
docker run -d \
  --name gitops-api \
  -p 8080:8080 \
  gitops-self-healing-api
```

The container listens on port **8080** (mapped to host port 8080).

### Health-check the API

```bash
curl http://localhost:8080/health
# => {"status":"UP"}
```

### View logs

```bash
docker logs gitops-api
```

### Stop and remove the container

```bash
docker stop gitops-api
docker rm gitops-api
```

### Clean up the image

```bash
docker rmi gitops-self-healing-api:latest
```

## Ansible deployment (GitOps stage)

This stage deploys the built JAR to a Linux host using Ansible. The target is a
real Ubuntu 24.04 machine running inside Docker (systemd as PID 1, SSH for
Ansible), which is how the assignment demonstrates a "remote" production-like
host from macOS.

### Directory layout

```
ansible/
├── ansible.cfg                # Ansible configuration (uses generated SSH key)
├── inventory.ini              # The managed Linux host
├── site.yml                   # Main playbook
├── roles/gitops_api/          # Deployment role
│   ├── defaults/main.yml      # app_port=8080 and other variables
│   ├── tasks/main.yml         # installs Java 21, user, dir, JAR, service
│   ├── handlers/main.yml      # "Restart gitops API" handler
│   └── templates/gitops-api.service.j2
├── target/
│   ├── Dockerfile             # Ubuntu 24.04 + systemd + OpenSSH
│   └── setup-target.sh        # builds & starts the target container
└── .ansible/                  # generated SSH keys (never committed)
```

What the playbook does:

- Runs the `gitops_api` role as root (`become: true`).
- Installs **Java 21** runtime (`openjdk-21-jre-headless`).
- Creates a dedicated `gitops` system user.
- Creates `/opt/gitops-api`.
- Copies `target/gitops-self-healing-api-1.0.0.jar`.
- Deploys a systemd unit (`gitops-api.service`) that runs the JAR with
  `--server.port={{ app_port }}` (default `8080`), restarts automatically on
  failure, and starts + enables the service.

Handler behaviour: the **"Restart gitops API"** handler is notified **only** when
the JAR or the systemd unit template actually change. Re-running the playbook on
an unchanged target reports `ok` and does **not** restart the service.

### 1. Start the target

Requirements: Docker running (Docker Desktop on Apple Silicon is fine).

```bash
bash ansible/target/setup-target.sh
```

The script:

- generates an SSH key pair under `ansible/.ansible/` if one does not exist,
- builds the `gitops-target:latest` image,
- starts the container `gitops-target` with SSH on host port **2222** and the
  application published on host port **8082 → 8080**,
- installs the SSH public key for the `ansible` user so Ansible can log in.

### 2. Test SSH connectivity with Ansible

```bash
cd ansible
ansible -i inventory.ini -m ping gitops-target
```

or the equivalent reading everything from the config:

```bash
cd ansible
ansible gitops-target -m ping
```

Expected: `gitops-target | SUCCESS => { "ping": "pong" }`.

### 3. Run the playbook

```bash
cd ansible
ansible-playbook site.yml
```

### 4. Verify the service

```bash
ansible gitops-target -m shell -a 'systemctl status gitops-api --no-pager'
ansible gitops-target -m shell -a 'systemctl is-active gitops-api'
```

### 5. Verify the API

On the host (mapped port):

```bash
curl http://localhost:8082/health
# => {"status":"UP"}
```

Or from inside the remote target:

```bash
ansible gitops-target -m shell -a 'curl -s http://localhost:8080/health'
```

### 6. Demonstrate the handler behaviour

Run the playbook twice:

```bash
ansible-playbook site.yml      # first run: deploys + starts
ansible-playbook site.yml      # second run: all tasks "ok", NO restart
```

Then rebuild the JAR so its checksum differs, and re-run to see the handler fire:

```bash
cd ~/path/to/project                              # repo root
mvn package -DskipTests                           # fresh JAR with a new checksum
cd ansible
ansible-playbook site.yml
# "Copy application JAR" reports changed -> HANDLER "Restart gitops API" runs
```

### 7. Stop and remove the target

```bash
docker stop gitops-target
docker rm gitops-target
```

To also delete the image:

```bash
docker rmi gitops-target:latest
```

## Kubernetes deployment (GitOps stage)

The application is deployed to Kubernetes (Minikube) from the manifests in
`k8s/`. There are two objects:

- `k8s/deployment.yaml` — a `Deployment` running **3 replicas** of the
  `gitops-self-healing-api:latest` image, with liveness and readiness probes
  hitting `GET /health` on port 8080.
- `k8s/service.yaml` — a `NodePort` `Service` that exposes the app on port 8080
  and selects the same `app: gitops-api` pods.

Prerequisites: `minikube`, `kubectl`, and the Docker image from the container
stage (see the Docker section above).

### 1. Load the image into Minikube

Minikube does not see your Docker daemon, so load the image first:

```bash
mvn -q package -DskipTests                       # build the JAR
docker build -t gitops-self-healing-api:latest . # build the image
minikube image load gitops-self-healing-api:latest
```

Alternative (build directly inside Minikube):

```bash
minikube image build -t gitops-self-healing-api:latest .
```

### 2. Apply the Deployment and Service

```bash
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

### 3. Check pods

```bash
kubectl get pods
```

Expected: 3 pods, all `Running` with `1/1` READY:

```text
NAME                         READY   STATUS    RESTARTS   AGE
gitops-api-<hash>-<pod>      1/1     Running   0          1m
gitops-api-<hash>-<pod>      1/1     Running   0          1m
gitops-api-<hash>-<pod>      1/1     Running   0          1m
```

### 4. Check the Deployment

```bash
kubectl get deployment gitops-api
kubectl describe deployment gitops-api
```

`DESIRED`/`CURRENT`/`READY` should all show 3.

### 5. Check the Service

```bash
kubectl get svc gitops-api
```

Note the `NodePort` (30000–32767) assigned by Minikube.

### 6. Scale from 3 replicas to 5

```bash
kubectl scale deployment gitops-api --replicas=5
```

### 7. Verify the 5 replicas

```bash
kubectl get deployment gitops-api    # READY 5/5
kubectl get pods                      # 5 pods Running
```

### 8. Access the application in Minikube

```bash
minikube service gitops-api           # opens the browser
```

or get the URL and check the health endpoint:

```bash
minikube service gitops-api --url     # e.g. http://192.168.49.2:3XXXX
curl "$(minikube service gitops-api --url)/health"
# => {"status":"UP"}
```

### Cleanup

```bash
kubectl delete -f k8s/deployment.yaml -f k8s/service.yaml
```
