# User documentation

This guide is for anyone who needs to run or administer the Inception stack.
All commands are run from the root of the repository.

## 1. What the stack provides

| Service     | What it does for you |
|-------------|----------------------|
| **NGINX**   | The web server you talk to. Serves the site over HTTPS on port 443 (TLSv1.2/1.3 only). It is the only service reachable from outside. |
| **WordPress** | The website and its admin panel, run by php-fpm. |
| **MariaDB** | The database where WordPress stores posts, pages, users and settings. Not reachable from outside. |

Two folders on the host keep your data between restarts:

- `/home/msuizu/data/wordpress` — WordPress files (themes, plugins, uploads)
- `/home/msuizu/data/mariadb` — database files

## 2. Start and stop the project

| Action | Command | Effect |
|---|---|---|
| First start / start after changes | `make up` | Builds images and starts all containers in the background |
| Pause | `make stop` | Stops containers without removing them |
| Resume | `make start` | Starts the stopped containers again |
| Shut down | `make down` | Stops and removes containers. **Data is kept.** |
| Full reset | `make fclean` | Removes containers, images and volumes, and **deletes all site and database data** |
| Reset and start again | `make re` | `make fclean` followed by `make up` |
| List commands | `make` or `make help` | Prints the available targets |

The first `make up` takes a few minutes: images are built and WordPress is
downloaded and installed.

## 3. Access the website and the admin panel

1. Make sure the domain points to this machine (only needed once):

   ```sh
   grep msuizu.42.fr /etc/hosts || echo "127.0.0.1 msuizu.42.fr" | sudo tee -a /etc/hosts
   ```

2. Open the site: <https://msuizu.42.fr>

   The certificate is self-signed, so the browser shows a warning. Choose
   *Advanced → Proceed* (or equivalent) to continue.

3. Open the admin panel: <https://msuizu.42.fr/wp-admin>

   Log in with the administrator account (see below).

Plain HTTP (`http://msuizu.42.fr`, port 80) is intentionally not served.

## 4. Credentials

All credentials are stored in **`srcs/.env`**. This file is not in Git; ask the
project owner for it or create it as described in
[DEV_DOC.md](DEV_DOC.md#2-create-srcsenv).

| What | Variables in `srcs/.env` |
|---|---|
| WordPress administrator | `WP_ADMIN_USER`, `WP_ADMIN_PASSWORD`, `WP_ADMIN_EMAIL` |
| WordPress second user (role: author) | `WP_USER`, `WP_USER_PASSWORD`, `WP_USER_EMAIL` |
| Database used by WordPress | `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD` |
| Database root | `MYSQL_ROOT_PASSWORD` |

To view them:

```sh
cat srcs/.env
```

**Changing a password.** The values in `.env` are only used the *first* time
the stack is installed. After that:

- WordPress users: change the password in the admin panel
  (*Users → Profile*), or from the command line:

  ```sh
  docker exec wordpress wp user update <username> --user_pass='<new password>' --allow-root --path=/var/www/html
  ```

  Then update `srcs/.env` so it stays accurate.
- Database passwords: changing them in `.env` alone has no effect on an
  existing database. Either change them inside MariaDB *and* in
  `/var/www/html/wp-config.php`, or run `make re` to reinstall from scratch
  (this erases all site data).

Never commit `srcs/.env` or paste its contents anywhere public.

## 5. Check that the services are running

**Container status** — all three should be `Up`:

```sh
make ps
```

**Logs** — follow all logs (Ctrl+C to quit), or one service only:

```sh
make logs
docker logs wordpress
```

**Website responds over HTTPS:**

```sh
curl -kI https://msuizu.42.fr        # expect HTTP/1.1 200 (or a 30x redirect)
```

**Only TLSv1.2/1.3 are accepted:**

```sh
openssl s_client -connect msuizu.42.fr:443 -tls1_2 </dev/null | grep Protocol   # works
openssl s_client -connect msuizu.42.fr:443 -tls1_1 </dev/null                    # fails
```

**Database is alive:**

```sh
docker exec mariadb mysqladmin ping                       # "mysqld is alive"
```

**WordPress has two users:**

```sh
docker exec wordpress wp user list --allow-root --path=/var/www/html
```

### Common problems

| Symptom | Likely cause / fix |
|---|---|
| Browser can't find `msuizu.42.fr` | Missing `/etc/hosts` entry (step 3.1) |
| `502 Bad Gateway` | WordPress is still installing or crashed — check `docker logs wordpress` |
| WordPress keeps waiting for the database | Check `docker logs mariadb`; verify `MYSQL_*` values in `srcs/.env` |
| `make up` fails on volumes | The data folders are missing or not writable: `ls -ld ~/data/*` |
