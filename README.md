# snowflake-admin-sql

Snowflake platform administration worked through in SQL: role based access
control, service user setup with key pair authentication, and a set of audit
queries for answering access and cost questions.

Built as a hands on study project. The same access model is managed as code in
[snowflake-platform-tf](https://github.com/Shaz-Khan431/snowflake-platform-tf),
which is deployed by the pipeline in
[gocd-local-lab](https://github.com/Shaz-Khan431/gocd-local-lab). This repo is
the SQL layer underneath both: what the provider is actually doing, and what
you fall back to when Terraform fails or when an auditor asks a question no
config file answers.

## Files

```
├── 01_setup.sql          # warehouse, database, schema, resource monitor
├── 02_rbac.sql           # access roles, functional roles, grants
├── 03_service_user.sql   # key pair auth for a TYPE = SERVICE user
└── 04_audit_queries.sql  # ACCOUNT_USAGE queries for access and cost review
```

No real identifiers, keys, or passwords. Placeholders are marked in angle
brackets.

## The access model

Privileges attach to roles, never to users. Users receive roles. Snowflake
enforces this strictly, which is unusual and useful, since you cannot drift
into per user grants even by accident.

The structure here is the standard two layer pattern:

* **Access roles** (`AR_*`) hold privileges on objects. `AR_CLAIMS_RO` holds
  read access to one schema and nothing else.
* **Functional roles** (`FR_*`) map to job functions and are granted access
  roles. `FR_DATA_ANALYST` gets a set of read access roles.
* **Users** are granted functional roles only.

The payoff is that when a team's scope changes you edit one grant instead of
forty users, and "who can read claims data" is answerable by listing role
members rather than reconstructing scattered individual grants.

Every functional role is granted to `SYSADMIN`. That is not cosmetic. Objects
are owned by whichever role created them, and if nothing sits above that role
in the hierarchy, `SYSADMIN` cannot see or manage what it owns. You end up with
objects only reachable through `ACCOUNTADMIN`. Granting the role upward keeps
the administrative view complete.

## System roles

```
ACCOUNTADMIN          everything; very few holders, MFA required
├── SECURITYADMIN     users, roles, grants (access administration)
│   └── USERADMIN     users and roles only, no grants
└── SYSADMIN          warehouses, databases, objects (object administration)
    └── custom roles roll up here
```

Two branches for two concerns, joined only at the top. The scripts switch to
the narrowest role that can do each task rather than doing everything as
`SECURITYADMIN`. That is partly least privilege habit and partly because
`QUERY_HISTORY` records the role every statement ran under, so consistent role
usage makes unusual activity visible.

## The grant chain

Reading one table requires four separate things:

```
USAGE on the database
USAGE on the schema
SELECT on the table
USAGE on a warehouse to run the query
```

`USAGE` is traversal, not access. It lets a role enter a container; it never
reads data. Miss any link and Snowflake returns `object does not exist or not
authorized` for all four cases, deliberately, so users cannot probe for what
exists. That makes it the most common access ticket and the reason to
troubleshoot by walking the chain with `SHOW GRANTS` rather than guessing.

## Future grants

`GRANT ... ON ALL TABLES IN SCHEMA` is a one time operation against the tables
that exist at that moment. `GRANT ... ON FUTURE TABLES IN SCHEMA` is a standing
rule that applies to tables created later. You generally need both.

The symptom of missing the future grant is a role that can query forty tables
but errors on the one created yesterday.

## Service user authentication

`03_service_user.sql` sets up a `TYPE = SERVICE` user authenticating with an
RSA key pair rather than a password. Snowflake requires this for service
accounts, and the reasoning is worth stating plainly: the private key never
crosses the network. The client signs a JWT with it and Snowflake verifies that
signature using the stored public key, so a breach of Snowflake's side yields
nothing an attacker can log in with.

Generating the pair:

```bash
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out tf_key.p8 -nocrypt
openssl rsa -in tf_key.p8 -pubout -out tf_key.pub
chmod 600 tf_key.p8
```

PKCS#8 format matters. The header should read `BEGIN PRIVATE KEY`, not
`BEGIN RSA PRIVATE KEY`; the wrong format is a common cause of authentication
failures that look like permission problems.

To confirm which key a user actually has, `DESC USER <name>` exposes
`RSA_PUBLIC_KEY_FP`, a fingerprint you can compare against your local key. That
is the first thing to check on a JWT error.

Snowflake supports `RSA_PUBLIC_KEY` and `RSA_PUBLIC_KEY_2` simultaneously, so
key rotation can happen without downtime: add the new public key to the second
slot, move clients to the new private key, then remove the old one.

## Audit queries

`04_audit_queries.sql` covers the questions that come up in an access review:

| Question | Source |
|---|---|
| Who currently holds `ACCOUNTADMIN`, and since when | `GRANTS_TO_USERS` |
| Which humans lack MFA, which service users still have passwords | `USERS` |
| Who has never logged in, or has not logged in recently | `USERS` |
| Failed login attempts and where they came from | `LOGIN_HISTORY` |
| Who granted or revoked privileges, when, and under which role | `QUERY_HISTORY` |
| Credit burn by warehouse | `WAREHOUSE_METERING_HISTORY` |

Two things that will silently produce wrong answers:

* **`deleted_on IS NULL` is not optional.** These views keep history, so
  dropped users and revoked grants remain as rows with a deletion timestamp.
  Omit the filter and an access review reports former employees as current
  access holders. Use `IS NULL`, never `= NULL`, since comparing to NULL never
  evaluates true and the query returns nothing without erroring.
* **`ACCOUNT_USAGE` lags** by minutes to a few hours and retains one year.
  `INFORMATION_SCHEMA` equivalents are real time with shorter retention. For
  live troubleshooting use the latter; for audit evidence use the former.

Also worth knowing when reading `QUERY_HISTORY`: Snowflake **redacts the query
text** of statements that could contain secrets, such as `CREATE USER` with a
password. A blank `query_text` is the feature working, not missing data. The
metadata columns are still populated.

## Live checks versus historical views

Both have a place and they answer different questions.

```sql
SHOW GRANTS TO ROLE   fr_data_analyst;  -- what the role can do
SHOW GRANTS OF ROLE   fr_data_analyst;  -- who holds the role
SHOW GRANTS TO USER   some_user;        -- that user's roles
SHOW GRANTS ON TABLE  db.schema.table;  -- who can reach the object
```

`SHOW` is immediate and exact. The `ACCOUNT_USAGE` views are queryable,
filterable, exportable, and carry timestamps, which is what an auditor
actually wants.

One gap worth naming: `SHOW GRANTS OF ROLE ACCOUNTADMIN` lists **direct**
grants only. Someone granted a custom role that itself inherits `ACCOUNTADMIN`
holds it effectively but will not appear. A thorough answer checks role
inheritance in `GRANTS_TO_ROLES` as well.

## Known gaps

* **The Terraform role is over privileged.** It holds `SYSADMIN` and
  `SECURITYADMIN` for convenience. Production would scope it to only the
  privileges the managed resources require.
* **No network policy** restricting where the service user can authenticate
  from. In a real setup the CI agent addresses would be the only allowed
  source.
* **Access review is manual.** The queries exist but nothing schedules them or
  alerts on findings such as a new `ACCOUNTADMIN` grant or a privilege granted
  to `PUBLIC`.
* **Out of band grants are not detected here.** Privileges granted outside
  Terraform generally do not appear in `terraform plan`, so drift detection
  alone will not surface them. Catching that needs a scheduled comparison of
  `GRANTS_TO_ROLES` against an expected baseline.
