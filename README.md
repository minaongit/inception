*This project has been created as part of the 42 curriculum by _msuizu_.*

# Inception

## Description

Inception is a system administration project. The goal is to build a small web
infrastructure out of several Docker containers, orchestrated with Docker
Compose, inside a virtual machine.

The stack serves a WordPress website over HTTPS at `https://msuizu.42.fr`:

| Service     | Role                                                        | Port (internal) |
|-------------|-------------------------------------------------------------|-----------------|
| `nginx`     | Only entry point. Terminates TLS (TLSv1.2 / TLSv1.3 only) and forwards PHP requests to WordPress | 443 (published to the host) |
| `wordpress` | WordPress + php-fpm (no web server inside). Installed and configured with WP-CLI on first start | 9000 |
| `mariadb`   | MariaDB database that stores WordPress data                 | 3306            |

```
    Internet / host
       │ 443 (HTTPS)
┌──────┼──────────────────────────────────────────────────┐
│  docker network "inception" (bridge)                    │
│      ▼                                                  │
│   ┌─────────┐  9000   ┌───────────┐  3306  ┌─────────┐  │
│   │  nginx  │ ──────▶ │ wordpress │ ─────▶ │ mariadb │  │
│   └────┬────┘         └─────┬─────┘        └────┬────┘  │
└────────┼────────────────────┼───────────────────┼───────┘
         └──── volume ────────┘                   │
              "wordpress"                  volume "mariadb"
         /home/msuizu/data/wordpress   /home/msuizu/data/mariadb
```

### Use of Docker and sources included

Every image is built locally from its own `Dockerfile` — no ready-made images
are pulled except the `debian` base image. All configuration lives in `srcs/`:

```
.
├── Makefile                         # entry point: builds and runs everything
└── srcs/
    ├── .env                         # environment variables (not committed)
    ├── docker-compose.yml           # services, volumes, network
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   ├── conf/my.cnf          # listen on 0.0.0.0:3306
        │   └── tools/init.sh        # first-run DB/user creation, then exec mysqld_safe
        ├── nginx/
        │   ├── Dockerfile
        │   ├── conf/nginx.conf      # TLS server block + FastCGI to wordpress:9000
        │   └── tools/init.sh        # self-signed cert generation, then exec nginx
        └── wordpress/
            ├── Dockerfile
            ├── conf/www.conf        # php-fpm pool listening on 0.0.0.0:9000
            └── tools/init.sh        # waits for DB, installs WP + 2 users, then exec php-fpm
```

### Main design choices

- **Base image: `debian:oldstable`** (Debian 12 "bookworm"), the penultimate
  stable Debian release, as required by the subject. PHP 8.2 is the version
  shipped by bookworm.
- **One process per container, running as PID 1.** Each entrypoint script does
  its one-time setup and then uses `exec` to replace itself with the real
  service (`nginx -g "daemon off;"`, `php-fpm8.2 -F`, `mysqld_safe`), so the
  service receives signals directly and no `tail -f` / `sleep infinity` hack is
  needed.
- **Idempotent initialisation.** Setup only runs when its result is missing
  (no database directory, no `wp-config.php`, no certificate), so restarting a
  container does not reinstall anything.
- **WP-CLI** is used to download, configure and install WordPress
  non-interactively and to create the second (non-admin) user.
- **Self-signed TLS certificate** generated at container start with `openssl`.
- **`restart: unless-stopped`** on every service so containers come back after
  a crash.

### Virtual Machines vs Docker

| Virtual machine | Docker container |
|---|---|
| Virtualises hardware; each VM runs a full guest OS with its own kernel | Shares the host kernel; isolation through namespaces and cgroups |
| Boots in tens of seconds, weighs gigabytes | Starts in about a second, images weigh megabytes |
| Strong isolation boundary | Lighter isolation (same kernel) |
| Good for running a different OS or kernel | Good for packaging one service with its dependencies, reproducibly |

In this project both are used: the VM provides an isolated machine to work in,
and Docker splits the stack into small, reproducible, independently restartable
services.

### Secrets vs Environment Variables

| Environment variables | Docker secrets |
|---|---|
| Passed to the container at start (`env_file`, `environment:`) | Mounted as files under `/run/secrets/<name>` |
| Visible through `docker inspect` and to every process in the container | Not shown by `docker inspect`; readable only where mounted |
| Simple, fine for non-sensitive config (domain, DB name, usernames) | Designed for passwords, keys and certificates |

This project currently stores all configuration, including passwords, in
`srcs/.env`, which is excluded from Git by `.gitignore` and from build contexts
by `.dockerignore`. No password is written in any Dockerfile. Moving the
passwords into Docker secrets (`secrets/*.txt` read via `/run/secrets/…`) would
be the more secure option.

### Docker Network vs Host Network

| Docker bridge network | Host network |
|---|---|
| Containers get their own network namespace and private IPs | Container shares the host's network stack directly |
| Built-in DNS: containers reach each other by service name (`mariadb`, `wordpress`) | No service-name DNS; everything is `localhost` |
| Only explicitly published ports (`443`) are reachable from outside | Every port a container opens is exposed on the host |

The stack uses a user-defined bridge network named `inception`. MariaDB (3306)
and php-fpm (9000) are reachable only from inside that network; NGINX on 443 is
the single entry point. `network: host`, `links` and `--link` are not used.

### Docker Volumes vs Bind Mounts

| Named volume | Bind mount |
|---|---|
| Managed by Docker (`docker volume ls`, `docker volume inspect`) | A raw host path mounted into the container |
| Referenced by name, decoupled from the host layout | Tied to an exact host path |
| Created and removed with Docker tooling | Lifecycle managed by hand on the host |

The subject requires named volumes stored under `/home/<login>/data`. The two
named volumes `mariadb` and `wordpress` use the `local` driver with
`driver_opts` (`type: none`, `o: bind`) so Docker manages them as named volumes
while their data lands in `~/data/mariadb` and `~/data/wordpress` on the host.

## Instructions

### Prerequisites

- A Linux virtual machine with Docker Engine and the Docker Compose plugin
  (`docker compose`)
- `make`, and `sudo` rights (used by `make fclean`)
- `msuizu.42.fr` pointing to the local machine:

  ```sh
  echo "127.0.0.1 msuizu.42.fr" | sudo tee -a /etc/hosts
  ```

### Configuration

Create `srcs/.env` (it is not in the repository). See
[DEV_DOC.md](DEV_DOC.md#2-create-srcsenv) for the full list of variables.

### Build and run

```sh
make up      # create data directories, build images, start containers
make ps      # check status
make logs    # follow logs
make down    # stop and remove containers (data is kept)
make re      # wipe everything and rebuild from scratch
```

Then open <https://msuizu.42.fr> (accept the self-signed certificate warning).
The admin panel is at <https://msuizu.42.fr/wp-admin>.

More detail: [USER_DOC.md](USER_DOC.md) for operating the stack,
[DEV_DOC.md](DEV_DOC.md) for setting it up and working on it.

## Resources

- [Docker documentation](https://docs.docker.com/)
- [Dockerfile reference](https://docs.docker.com/reference/dockerfile/) and
  [best practices](https://docs.docker.com/build/building/best-practices/)
- [Compose file reference](https://docs.docker.com/reference/compose-file/)
- [Docker volumes](https://docs.docker.com/engine/storage/volumes/) and
  [bind mounts](https://docs.docker.com/engine/storage/bind-mounts/)
- [Docker networking](https://docs.docker.com/engine/network/)
- [Docker secrets in Compose](https://docs.docker.com/compose/how-tos/use-secrets/)
- [NGINX: configuring HTTPS servers](https://nginx.org/en/docs/http/configuring_https_servers.html)
- [NGINX: FastCGI module](https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html)
- [PHP-FPM configuration](https://www.php.net/manual/en/install.fpm.configuration.php)
- [WP-CLI commands](https://developer.wordpress.org/cli/commands/)
- [MariaDB Server documentation](https://mariadb.com/kb/en/documentation/)
- [Why PID 1 matters in containers](https://cloud.google.com/architecture/best-practices-for-building-containers#signal-handling)

### Use of AI

AI (Claude) was used to:

- draft `README.md`, `USER_DOC.md` and `DEV_DOC.md` from the existing project
  sources and the subject;
- explain Docker concepts (PID 1, named volumes vs bind mounts, secrets vs
  environment variables) while studying the subject.

All AI output was reviewed, tested in the VM, and edited before being committed.
