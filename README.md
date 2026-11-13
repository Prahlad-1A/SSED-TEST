# CampusHub (9-Service Containerized Stack)

CampusHub is a full-stack event registration application orchestrating 9 independent microservices using Docker and Docker Compose.

---

## 1. Architecture Overview & Services

```
                       [ Host / Client ]
                               │
                       :8080 (0.0.0.0)
                               ▼
                        ┌─────────────┐
                        │   gateway   │ (nginx-unprivileged)
                        └──────┬──────┘
            ┌──────────────────┼──────────────────┐
            │                  │                  │
            │ /                │ /api/            │ /storage/
            ▼                  ▼                  ▼
     ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
     │   frontend   │   │     api      │   │    minio     │
     │  (React/Vite)│   │  (Express)   │   │  (S3 Storage)│
     └──────────────┘   └──────┬───────┘   └──────────────┘
                               │
       ┌───────────────┬───────┴───────┬───────────────┐
       ▼               ▼               ▼               ▼
┌──────────────┐┌──────────────┐┌──────────────┐┌──────────────┐
│      db      ││    redis     ││   rabbitmq   ││    worker    │
│ (PostgreSQL) ││   (Cache)    ││   (Broker)   ││ (Mail Worker)│
└──────────────┘└──────────────┘└──────┬───────┘└──────┬───────┘
                                       │               │
                                       └───────────────┤
                                                       ▼
                                                ┌──────────────┐
                                                │   mailhog    │
                                                │ (SMTP Mock)  │
                                                └──────────────┘
```

### Service Contract
| Service | Image / Build Context | Port(s) | Role & Configuration |
|---|---|---|---|
| **gateway** | `nginxinc/nginx-unprivileged:alpine` | `8080` (public 0.0.0.0) | Reverse proxy routing `/` to frontend, `/api/` to api, `/storage/` to minio |
| **frontend** | Multi-stage build (`app/frontend`) | `8080` (internal) | Static React app built with Vite, served via unprivileged Nginx |
| **api** | Alpine Node build (`app/api`) | `3000` (internal) | REST API, auto-runs database migrations and seed on startup |
| **worker** | Reused `campushub-api` image | None | Background consumer for registration events; sends confirmation emails |
| **db** | `postgres:16-alpine` | `5432` (internal) | Primary PostgreSQL database with persistent volume |
| **redis** | `redis:7-alpine` | `6379` (internal) | Event listing cache with password authentication (`REDIS_PASSWORD`) |
| **rabbitmq** | `rabbitmq:3-management-alpine` | `5672` (internal), `15672` (127.0.0.1) | Message queue for asynchronous email processing |
| **minio** | `minio/minio:latest` | `9000` (internal), `9001` (127.0.0.1) | S3-compatible object storage for event promotional images |
| **mailhog** | `mailhog/mailhog:latest` | `1025` (internal), `8025` (127.0.0.1) | Mock SMTP server and web interface for email testing |

---

## 2. How to Run the Stack

### Prerequisites
- Docker Engine & Docker Compose v2+ installed and running.

### Quick Start
1. Copy the example environment file:
   ```bash
   cp .env.example .env
   ```
2. Build and start all 9 services:
   ```bash
   docker compose up -d --build --wait
   ```
3. Access endpoints:
   - **Web UI**: [http://localhost:8080](http://localhost:8080)
   - **API Health**: [http://localhost:8080/api/health](http://localhost:8080/api/health)
   - **MailHog Inbox**: [http://127.0.0.1:8025](http://127.0.0.1:8025)
   - **RabbitMQ Management**: [http://127.0.0.1:15672](http://127.0.0.1:15672)
   - **MinIO Console**: [http://127.0.0.1:9001](http://127.0.0.1:9001)

4. Stop the stack:
   ```bash
   docker compose down
   ```
   *(Add `-v` if you also want to remove persistent database/storage volumes).*

---

## 3. Design Decisions & Rationale

1. **Non-Root Execution across all Application Services**:
   - *Decision*: Configured `gateway` and `frontend` using `nginxinc/nginx-unprivileged:alpine` (UID 101) and `api`/`worker` using the `node` user (UID 1000).
   - *Rationale*: Running as non-root aligns with security best practices and least-privilege principles, preventing container breakouts and host privilege escalation vulnerabilities.

2. **Lean Pinned Base Images & Image Size Optimization**:
   - *Decision*: Standardized on `node:20-alpine` with npm production dependency pruning (`npm install --omit=dev --no-audit --no-fund`) and removed temporary cache files (`/root/.npm`, yarn caches).
   - *Rationale*: Keeps the API image lightweight (~215 MB, well within the 250 MB ceiling) to minimize deployment transfer times, reduce attack surface, and enhance cold-start efficiency while maintaining Docker layer caching.

3. **Tiered Network Isolation & Minimal Public Surface**:
   - *Decision*: Segmented services across three Docker bridge networks (`frontend`, `backend`, `data`), and published only the gateway port (8080) on `0.0.0.0`. Debug/management endpoints (RabbitMQ, MailHog, MinIO console) are bound to `127.0.0.1` only.
   - *Rationale*: Isolates the database, cache, and message broker from direct frontend or external access. Gateway acts as the single secure reverse proxy entrypoint, guaranteeing zero unintended data tier exposure.
