# PostgreSQL (Global)

SKYLAB uses a centralized PostgreSQL instance shared across multiple services. 
This reduces resource overhead and simplifies database management.

## Service Configuration

The core service is configured in `modules/services/postgresql.nix`.
Each consuming service defines its own database and user in its respective module.

- **Active Version**: PostgreSQL 16 (pinned in `modules/services/postgresql.nix`)
- **Data Directory**: `/var/lib/postgresql/16`
- **Socket Path**: `/run/postgresql` (Unix socket)
- **Authentication**: Peer Authentication (no password required for local Unix socket connections).

## Database Upgrades

When moving to a new major version of PostgreSQL in NixOS:
1.  Update `services.postgresql.package` in `modules/services/postgresql.nix`.
2.  NixOS will create a new, empty data directory for the new version.
3.  To keep data, you must perform a dump and restore:
    ```bash
    # 1. Back up all databases from the OLD version
    sudo -u postgres pg_dumpall > all_databases_backup.sql
    
    # 2. Update config and nixos-rebuild switch
    
    # 3. Restore data into the NEW version
    sudo -u postgres psql -f all_databases_backup.sql
    ```
4.  Once verified, old data directories (e.g., `/var/lib/postgresql/15`) can be safely removed.

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
