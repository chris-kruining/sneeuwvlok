# Persistence Clan service

Foundational persistence service. The initial driver is `postgresql`; it provisions PostgreSQL on the target machine and exports the selected database endpoint for other services.

Consumer services export `persistence.databases` claims, and the persistence instance aggregates those claims to create databases, users, passwords, and PostgreSQL access material.