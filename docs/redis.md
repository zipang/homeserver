# Redis (Global)

SKYLAB uses a centralized Redis instance for caching and session management.

## Service Configuration

The core service is configured in `modules/services/redis.nix`.

- **Socket Path**: `/run/redis/redis.sock`
- **Permissions**: `0660` (owned by `redis:redis`)
- **Access Control**: Consuming services must be added to the `redis` system group to access the Unix socket.

## Consumer Registry

| Service | Usage | Module Path |
| :--- | :--- | :--- | :--- |
| Authelia | Session Storage | `modules/services/authelia.nix` |
| Nextcloud | Distributed Cache & File Locking | `modules/services/nextcloud.nix` |
| Immich | Job Queue & Cache | `modules/services/immich.nix` |


## Operational Guides

### Checking Redis Status

```bash
systemctl status redis-default.service
```

### Accessing Redis CLI via Socket

```bash
sudo redis-cli -s /run/redis/redis.sock
```

### Monitoring Redis Traffic

```bash
sudo redis-cli -s /run/redis/redis.sock monitor
```
