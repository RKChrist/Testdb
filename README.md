This is a test demonstration of docker-compose with PostSQLServer with 1 replica

Inspiration from the following medium article:
https://medium.com/@eremeykin/how-to-setup-single-primary-postgresql-replication-with-docker-compose-98c48f233bbf




# Need to Know in the Docker-compose
**wal_level=replica**: Sets the Write-Ahead Logging (WAL) level to support replication, enabling the server to provide the necessary data for streaming replication and point-in-time recovery.

**hot_standby=on**: Enables the server to operate as a hot standby, allowing it to handle read-only queries while in a standby mode, useful for high availability setups.

**max_wal_senders=10**: Configures up to 10 concurrent connections for streaming WAL data, essential for replication setups with multiple standby servers.

**max_replication_slots=10**: Allows up to 10 replication slots, ensuring the primary server retains necessary WAL logs for standby servers.

**hot_standby_feedback=on**: Enables feedback from standby servers to the primary, preventing the premature deletion of WAL files needed by the standby server, especially during long-running queries.

**Master Server Configuration (POSTGRES_HOST_AUTH_METHOD: "scram-sha-256")**: This setting on the master server dictates that the default authentication method for host connections is scram-sha-256. SCRAM-SHA-256 is a more secure authentication mechanism compared to MD5, providing better security against password cracking. When replicas or any other clients connect to the master server, this method will be required for authentication, ensuring a higher level of security for these connections.

**Specific Replica Connection Configuration (host replication all 0.0.0.0/0 md5)**: It specifies that for replication purposes (indicated by host replication), any replica (from any IP address, as indicated by 0.0.0.0/0) should authenticate using MD5. This is a specific rule that overrides the default SCRAM-SHA-256 method for replication connections. It means that while the master server uses SCRAM-SHA-256 for most connections, it still accepts MD5 for replication connections, possibly for compatibility or other specific reasons.

**Enforcing Configurations on Master (POSTGRES_INITDB_ARGS: "--auth-host=scram-sha-256")**: When the master database is initially set up using initdb, this argument enforces that the default authentication for host connections will be SCRAM-SHA-256. This setting ensures a high level of security for new connections made to the master server. It's important to note that while this sets the default authentication method, specific rules in the pg_hba.conf file (like the one for replication connections) can override this default on a case-by-case basis.

# DB setup with replication:

This line creates an new user and gives it access to the replication slot.
```
create user replicator with replication encrypted password 'replicator_password';
select pg_create_physical_replication_slot('replication_slot');
```
# Setup
Run

```
    Docker-compose up -d
```
Delete Volumes

```
    Docker-compose down -v
```


# Nice to know

These configurations are just an example of how to use it. Since for development purposes **hot_standby** doesn't need to be on. 

Likewise the connections allowed to the database in form of replication, should in this examaple just be 1, since we're only using 1 replica.
