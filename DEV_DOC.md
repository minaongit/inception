# Developer documentation

How to set up, build, run and work on the Inception stack. For an overview of
the architecture and design choices, see [README.md](README.md).

## 1. Prerequisites

On the virtual machine (Debian/Ubuntu-based Linux):

- **Docker Engine** with the **Compose plugin** (`docker compose version` must
  work). Install from <https://docs.docker.com/engine/install/>.
- Your user in the `docker` group, so Docker runs without `sudo`:

  ```sh
  sudo usermod -aG docker "$USER"   # then log out and back in
  ```

- `make` and `sudo` (`make fclean` uses `sudo rm` on the data folders, which
  are owned by container users).
- The project domain resolving to the VM:

  ```sh
  echo "127.0.0.1 msuizu.42.fr" | sudo tee -a /etc/hosts
  ```

## 2. Create `srcs/.env`

`srcs/.env` holds every configuration value and password. It is ignored by Git
(`.gitignore`) and excluded from build contexts (`srcs/.dockerignore`), so it
must be created on each new machine:

```sh
cat > srcs/.env <<'EOF'
# domain
DOMAIN=msuizu.42.fr

# mariadb
MYSQL_DATABASE=wordpress
MYSQL_USER=msuizu
MYSQL_PASSWORD=unsecuremdp
MYSQL_ROOT_PASSWORD=unsecuremdp

# wordpress
WP_ADMIN_USER=msuizu
WP_ADMIN_PASSWORD=unsecuremdp
WP_ADMIN_EMAIL=msuizu@student.42.fr

WP_USER=msuizu
WP_USER_PASSWORD=unsecuremdp
WP_USER_EMAIL=msuizu@student.42.fr
EOF
chmod 600 srcs/.env
```

| Variable | Used by | Purpose |
|---|---|---|
| `DOMAIN` | wordpress | Site URL (`https://$DOMAIN`) |
| `MYSQL_DATABASE` | mariadb, wordpress | Name of the WordPress database |
| `MYSQL_USER` / `MYSQL_PASSWORD` | mariadb, wordpress | Database account WordPress connects with |
| `MYSQL_ROOT_PASSWORD` | mariadb | Password set on the MariaDB `root@localhost` account |
| `WP_ADMIN_*` | wordpress | WordPress administrator account |
| `WP_USER*` | wordpress | Second WordPress account (role `author`) |

Rules from the subject:

- `WP_ADMIN_USER` **must not contain** `admin` / `administrator` in any case
  (e.g. `admin`, `Admin`, `admin-123`, `superadmin` are all rejected).
- No password may appear in a Dockerfile or in any committed file.

The domain is also hard-coded as `msuizu.42.fr` in
`srcs/requirements/nginx/conf/nginx.conf` (`server_name`) and in
`srcs/requirements/nginx/tools/init.sh` (certificate CN). Change all three
places if the login changes.

## 3. Build and launch

The `Makefile` wraps `docker compose -f srcs/docker-compose.yml`:

| Target | Command run | Notes |
|---|---|---|
| `help` (default) | — | Lists targets |
| `up` | `mkdir -p ~/data/{mariadb,wordpress}` + `docker compose up --build -d` | Creates the volume folders, (re)builds images, starts detached |
| `down` | `docker compose down` | Removes containers and network; volumes and data kept |
| `stop` / `start` | `docker compose stop` / `start` | Pause / resume existing containers |
| `logs` | `docker compose logs -f` | Follow logs of all services |
| `ps` | `docker compose ps` | Container status |
| `clean` | `docker compose down --rmi all --volumes` | Also removes built images and the named volumes (host data stays) |
| `fclean` | `clean` + `sudo rm -rf ~/data/mariadb/* ~/data/wordpress/*` | Deletes all persisted data |
| `re` | `fclean` + `up` | Full rebuild from a clean state |

First launch:

```sh
make up
make logs        # wait for "NOTICE: ready to handle connections" from php-fpm
```

### Startup sequence

`depends_on` only orders container *start*, it does not wait for readiness, so
each entrypoint handles its own dependencies:

1. **mariadb** (`tools/init.sh`): if `/var/lib/mysql/$MYSQL_DATABASE` does not
   exist, initialises the data dir, starts a temporary server without
   networking, creates the database and user, sets the root password, shuts it
   down. Then `exec mysqld_safe`.
2. **wordpress** (`tools/init.sh`): loops on `mysqladmin ping -h mariadb` until
   the DB answers. If `/var/www/html/wp-config.php` is missing, runs
   `wp core download`, `wp config create`, `wp core install` and
   `wp user create`. Then `exec php-fpm8.2 -F` (foreground).
3. **nginx** (`tools/init.sh`): generates a self-signed certificate in
   `/etc/nginx/ssl/` if missing, then `exec nginx -g "daemon off;"`.

Because setup is skipped when its output already exists, **changing `.env`
after the first install does not reconfigure WordPress or MariaDB** — run
`make re` to start over.

## 4. Managing containers, images, volumes and network

Containers are named after their services (`nginx`, `wordpress`, `mariadb`),
and so are the images.

```sh
# Containers
docker compose -f srcs/docker-compose.yml ps
docker logs -f <service>
docker exec -it <service> bash                     # shell inside a container
docker compose -f srcs/docker-compose.yml restart <service>
docker compose -f srcs/docker-compose.yml up -d --build <service>   # rebuild one service

# Images
docker images                                      # mariadb, wordpress, nginx
docker image prune                                 # remove dangling layers

# Volumes
docker volume ls                                   # mariadb, wordpress
docker volume inspect wordpress                    # shows device: ~/data/wordpress

# Network
docker network inspect inception                   # attached containers and IPs
```

Useful checks inside containers:

```sh
# MariaDB shell as root
docker exec -it mariadb mysql -u root -p

# WordPress via WP-CLI
docker exec wordpress wp --allow-root --path=/var/www/html user list
docker exec wordpress wp --allow-root --path=/var/www/html option get siteurl

# NGINX config test
docker exec nginx nginx -t
```

Testing a crash restart (`restart: unless-stopped`):

```sh
docker exec mariadb kill 1     # container exits, Docker restarts it
docker ps                      # STATUS shows a fresh "Up X seconds"
```

## 5. Where data is stored and how it persists

| Named volume | Mounted in container(s) | Host location |
|---|---|---|
| `mariadb` | `mariadb:/var/lib/mysql` | `/home/msuizu/data/mariadb` |
| `wordpress` | `wordpress:/var/www/html`, `nginx:/var/www/html` | `/home/msuizu/data/wordpress` |

Both are Docker **named volumes** (local driver) whose storage is placed in
`~/data/…` through `driver_opts` (`type: none`, `o: bind`). This means:

- Data survives `make stop`, `make down`, container crashes and VM reboots.
- `make clean` removes the volume *definitions* but the files in `~/data`
  remain; the next `make up` picks them up again.
- Only `make fclean` / `make re` actually delete the data.
- NGINX and WordPress share the `wordpress` volume: NGINX serves static files
  directly and forwards `.php` requests to `wordpress:9000` over FastCGI.

Files in `~/data` are owned by container UIDs (`mysql`, `www-data`), which is
why deleting them needs `sudo`.

## 6. Network and ports

- Single user-defined bridge network: `inception`.
- Containers resolve each other by service name (`mariadb`, `wordpress`).
- Only `443` is published to the host (`nginx`). Ports `9000` (php-fpm) and
  `3306` (MariaDB) are only reachable inside the network.
