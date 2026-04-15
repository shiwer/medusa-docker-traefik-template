# medusa-docker-traefik-template

Deploy a Medusa backend and Next.js storefront in production with Docker Compose and Traefik.

## Overview

This repository provides a simple production-ready template to run a headless Medusa stack with Docker Compose.

It is designed for developers who already have:
- a Medusa backend
- a Next.js storefront

and want a clean server setup to run both applications behind Traefik with HTTPS, Postgres and Redis.

The goal is not to add complexity.  
The goal is to make deployment understandable, reproducible and easy to operate.

---

## What this template includes

- **Traefik** as reverse proxy and HTTPS entrypoint
- **Postgres** for Medusa database
- **Redis** for cache and events
- **Medusa backend** container
- **Next.js storefront** container
- **Init services** for:
    - database migrations
    - admin user creation

---

## Architecture

This project is organized into 3 layers:

### 1. Infra

The infra layer contains shared services used by the applications:

- **Traefik**
- **Postgres**
- **Redis**

These services are started first and remain stable across deployments.

### 2. App

The app layer contains the business applications:

- **Medusa backend**
- **Next.js storefront**

These services connect to the infra layer and expose HTTP traffic through Traefik.

### 3. Init

The init layer contains one-shot tasks that must run before the backend is used:

- Medusa database migrations
- admin user creation

These services are not long-running services.  
They prepare the application state, then stop.

---

## Why this architecture

This architecture keeps responsibilities clear.

### Infra is separate from app runtime

Postgres, Redis and Traefik are shared technical services.  
They change less often than application code.

Keeping them in a dedicated Compose file makes deployment easier to reason about:
- infra is started once
- app containers can be rebuilt and restarted independently
- data volumes remain stable

### Init is separate from runtime

Migrations and admin creation are setup tasks, not application services.

Separating them avoids mixing:
- startup logic
- one-time setup
- long-running containers

This also makes the deployment flow clearer:

1. start infra
2. run init tasks
3. start app services

### App stays focused on serving traffic

The backend and storefront containers only do their runtime job:
- backend serves Medusa API and admin
- storefront serves the website

That makes failures easier to debug and updates easier to apply.

---

## Why Traefik

Traefik is used because it fits very well with Docker Compose.

It provides:
- automatic service discovery from Docker labels
- HTTPS with Let's Encrypt
- host and path-based routing
- a clean way to expose multiple services behind one public entrypoint

In practice, this means:
- the storefront can be exposed on `SHOP_DOMAIN`
- the Medusa API can be exposed on `API_DOMAIN`
- certificates are handled automatically
- routing rules live close to the containers they expose

This keeps the setup simple for a small production deployment.

---

## Docker networks

This template uses two Docker networks:

### `proxy`

This network is used by Traefik and any service that must receive public HTTP traffic.

Services connected to `proxy` can be reached by Traefik.

Typical members:
- Traefik
- Medusa backend
- Next.js storefront

### `internal`

This network is used for private communication between services.

It is not meant to expose services publicly.

Typical members:
- Postgres
- Redis
- Medusa backend
- Next.js storefront
- init containers

### Why two networks

This separation makes the communication path easier to understand:

- **public traffic** goes through `proxy`
- **private service-to-service traffic** goes through `internal`

This avoids exposing infra services directly and keeps the setup cleaner.

---

## How services communicate

### Public traffic

A user opens the storefront domain in the browser:

1. request reaches **Traefik**
2. Traefik matches the domain
3. Traefik forwards the request to the **storefront** container

For API traffic:

1. request reaches **Traefik**
2. Traefik matches the API domain
3. Traefik forwards the request to the **Medusa backend**

### Internal traffic

Inside Docker:

- Medusa connects to **Postgres**
- Medusa connects to **Redis**
- storefront connects to **Medusa** through the internal network

This means the storefront can call the backend without going through the public internet.

Example:

- storefront → `http://medusa:9000`
- backend → `postgres`
- backend → `redis`

---

## Repository structure

```text
.
├── README.md
├── .env.example
├── compose.infra.yaml
├── compose.app.yaml
├── compose.init.yaml
├── infra/
└── apps/
    ├── backend/
    │   ├── Dockerfile
    │   ├── start.sh
    │   ├── migrate.sh
    │   ├── create-admin.sh
    └── storefront/
        └── Dockerfile
```

### Compose files

#### `compose.infra.yaml`

Starts shared services:
- Traefik
- Postgres
- Redis

#### `compose.app.yaml`

Starts runtime services:
- Medusa backend
- Next.js storefront

#### `compose.init.yaml`

Runs setup tasks:
- Medusa migrations
- admin creation

---

## Environment variables

This template is designed to use environment variables for all domain-specific values.

Do not hardcode domains in Compose labels.

Use variables such as:

```yaml
SHOP_DOMAIN=example.com  
API_DOMAIN=api.example.com  
TRAEFIK_ACME_EMAIL=admin@example.com

POSTGRES_USER=medusa  
POSTGRES_PASSWORD=change-me  
POSTGRES_DB=medusa

DATABASE_URL=postgres://medusa:change-me@postgres:5432/medusa  
REDIS_URL=redis://redis:6379

JWT_SECRET=replace-me  
COOKIE_SECRET=replace-me

MEDUSA_ADMIN_EMAIL=admin@example.com  
MEDUSA_ADMIN_PASSWORD=replace-me

STORE_CORS=https://example.com  
ADMIN_CORS=https://api.example.com  
AUTH_CORS=https://example.com,https://api.example.com  
ADMIN_URL=https://api.example.com/app  
MEDUSA_BACKEND_URL=https://api.example.com  
STOREFRONT_URL=https://example.com

NEXT_PUBLIC_BASE_URL=https://example.com  
NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY=pk_your_key  
NEXT_PUBLIC_DEFAULT_REGION=fr  
NEXT_PUBLIC_AUTH_CORS=https://example.com  
REVALIDATE_SECRET=replace-me

ADMIN_ALLOWED_IPS=1.2.3.4/32,5.6.7.8/32
```

---

## Installation

### 1. Clone the repository

git clone https://github.com/your-org/medusa-docker-traefik-template.git  
cd medusa-docker-traefik-template

### 2. Add your applications

Place your existing projects inside:
- `apps/backend`
- `apps/storefront`

Or adapt the build contexts in `compose.app.yaml` and `compose.init.yaml`.

### 3. Create your environment file

```bash
cp .env.example .env
```

Then update the values for:
- domains
- database credentials
- secrets
- Medusa admin credentials
- storefront public variables

### 4. Create the Let's Encrypt storage file

```
mkdir -p infra/traefik/letsencrypt  
touch infra/traefik/letsencrypt/acme.json  
chmod 600 infra/traefik/letsencrypt/acme.json
```
---

## First startup

The expected flow is:

### 1. Start infra

```bash
docker compose -f compose.infra.yaml up -d
```
This starts:
- Traefik
- Postgres
- Redis

### 2. Run initialization tasks

```bash
docker compose -f compose.infra.yaml -f compose.init.yaml up --build --abort-on-container-exit
```

This runs:
- database migrations
- admin creation

Why this step matters:
- Medusa must have the correct database schema before the backend starts serving requests
- the admin user should exist before you open the admin panel

### 3. Start app services

```bash
docker compose -f compose.infra.yaml -f compose.app.yaml up -d --build
```

This starts:
- Medusa backend
- storefront

---

## Daily usage

### Start everything

```bash
docker compose -f compose.infra.yaml up -d  
docker compose -f compose.infra.yaml -f compose.app.yaml up -d
```

### Rebuild app services

```bash
docker compose -f compose.infra.yaml -f compose.app.yaml up -d --build
```

### Stop app services

```bash
docker compose -f compose.infra.yaml -f compose.app.yaml down
```

### Stop infra too

```bash
docker compose -f compose.infra.yaml down
```

### View logs

```bash
docker compose -f compose.infra.yaml logs -f  
docker compose -f compose.infra.yaml -f compose.app.yaml logs -f
```

### Run migrations again

```bash
docker compose -f compose.infra.yaml -f compose.init.yaml run --rm backend-migrate
```

### Recreate admin user task

```bash
docker compose -f compose.infra.yaml -f compose.init.yaml run --rm backend-create-admin
```

---

## Update flow

A typical update looks like this:

### 1. Pull new code

```bash
git pull origin main
```

if you are using submodules don't forget to :

```bash
git submodule foreach git pull origin main
```

### 2. Rebuild application images

```bash
docker compose -f compose.infra.yaml -f compose.app.yaml build
```

### 3. Run migrations if needed

```bash
docker compose -f compose.infra.yaml -f compose.init.yaml run --rm backend-migrate
```

### 4. Restart app services

```bash
docker compose -f compose.infra.yaml -f compose.app.yaml up -d
```

This keeps the flow explicit:
- schema first
- runtime second

---

## Medusa runtime flow

The important idea is simple:

### migration before runtime

The backend should not be treated as the place where database setup happens automatically.

Instead:
1. infra is ready
2. migrations are executed
3. admin is created if needed
4. backend starts
5. storefront uses the backend

This makes production behavior more predictable.

---

## Volumes and data

This template separates code from persistent data.

### Persistent volumes

Used for data that must survive container recreation:
- Postgres data
- Redis data
- Let's Encrypt certificates

### Why this matters

You can rebuild containers without losing:

- database data
- cache persistence if desired
- TLS certificates

### Example persisted paths

- Postgres → `/var/lib/postgresql/data`
- Redis → `/data`
- Traefik ACME storage → `/letsencrypt/acme.json`

---

## Basic security practices

This template keeps security simple and practical.

### HTTPS through Traefik

Traefik terminates TLS and manages Let's Encrypt certificates automatically.

This means:

- public traffic uses HTTPS
- certificates are renewed automatically
- app containers do not need to manage TLS themselves

### Private infra services

Postgres and Redis are only connected to the internal network.  
They are not exposed directly on public ports.

### Admin route protection

The Medusa admin can be protected with an IP allowlist through Traefik.

This is useful when you want:

- a public API
- a restricted admin panel

### Docker socket

Traefik uses the Docker socket to discover containers and routing labels.

This is a common and practical choice for small Compose-based deployments because it keeps configuration simple.

The important point for users of this template is just this:

- Traefik reads Docker metadata
- Docker labels define routing
- only containers explicitly enabled are exposed

That is why this template uses:

--providers.docker=true  
--providers.docker.exposedbydefault=false

So services are not exposed unless you choose to expose them.

---

## Developer experience

This repository tries to keep operations easy.

### Principles

- one concern per Compose file
- simple Docker commands
- no hidden deployment logic
- no platform lock-in
- easy to inspect logs
- easy to rerun migrations manually

### Good DX examples

You should be able to answer quickly:

- what starts infra?
- what runs migrations?
- what exposes public traffic?
- how does the storefront reach Medusa?

That is why the project is split by role instead of hiding everything in one large Compose file.

---

## Example deployment flow

Here is the full production flow:

```bash
cp .env.example .env

docker compose -f compose.infra.yaml up -d
docker compose -f compose.infra.yaml -f compose.init.yaml up --build --abort-on-container-exit
docker compose -f compose.infra.yaml -f compose.app.yaml up -d --build
```

After that:

- storefront is available on `https://$SHOP_DOMAIN`
- Medusa API is available on `https://$API_DOMAIN`
- Medusa admin is available on `https://$API_DOMAIN/app`

---

## FAQ

### The backend starts but returns database errors

Run migrations first:

```bash
docker compose -f compose.infra.yaml -f compose.init.yaml run --rm backend-migrate
```

The runtime containers assume the database schema already exists.

---

### Traefik does not issue certificates

Check:

- your domain points to the server IP
- ports 80 and 443 are open
- `TRAEFIK_ACME_EMAIL` is set
- `acme.json` exists and has correct permissions

Example:

touch infra/traefik/letsencrypt/acme.json  
chmod 600 infra/traefik/letsencrypt/acme.json

---

### The storefront cannot reach Medusa

Check the internal backend URL used by the storefront container.

Example:

MEDUSA_BACKEND_URL=http://backend:9000

Inside Docker, service names are used for communication.

---

### Uploaded files disappear after rebuild - Only if you use local files to store your data

Make sure the backend static directory is mounted to a volume.

Without a persistent volume, container recreation removes local files.

---

### Postgres or Redis are healthy but the app still fails

Check:
- `.env` values
- `DATABASE_URL`
- `REDIS_URL`
- service names used in URLs
- app logs

Useful commands:

```bash
docker compose -f compose.infra.yaml -f compose.app.yaml logs -f backend  
docker compose -f compose.infra.yaml -f compose.app.yaml logs -f storefront
```

---

## Who is this template for

This template is for developers who:

- already have a Medusa project
- already have a storefront project
- want a clear production setup with Docker Compose
- want HTTPS and routing without adding unnecessary tooling

It is not trying to be a full platform.  
It is a practical deployment baseline.
