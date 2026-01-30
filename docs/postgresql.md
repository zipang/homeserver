# PostgreSQL (Global)

SKYLAB uses a centralized PostgreSQL instance shared across multiple services. 
This reduces resource overhead and simplifies database management.

## Service Configuration

The core service is configured in `modules/services/postgresql.nix`.
Each consuming service defines its own database and user in its respective module.

- **Socket Path**: `/run/postgresql` (Unix socket)
- **Authentication**: Peer Authentication (no password required for local Unix socket connections).

## Consumer Registry

| Service | Database Name | User Name | Module Path |
| :--- | :--- | :--- | :--- |
| Authelia | `authelia-main` | `authelia-main` | `modules/services/authelia.nix` |
| Nextcloud | `nextcloud` | `nextcloud` | `modules/services/nextcloud.nix` |
| Immich | `immich` | `immich` | `modules/services/immich.nix` |

## Operational Guides

### Checking Databases

```bash
sudo -u postgres psql -c "\l"
```

### Checking Users

```bash
sudo -u postgres psql -c "\du"
```

### Backing Up a Database

```bash
sudo -u postgres pg_dump <dbname> > <dbname>-backup.sql
```
