# workspace-infra Deployment

## Prerequisites

- AWS credentials available in the current shell
- `DATABRICKS_ACCOUNT_ID` set
- `DATABRICKS_CLIENT_ID` set
- `DATABRICKS_CLIENT_SECRET` set
- `DATABRICKS_OWNER_EMAIL` set

## Suggested Setup

```bash
. ./bin/set_env_vars.sh
```

## Deployment Order

```text
terraform-state-infra
account-admin
network-infra
uc-metastore-infra
streaming-lake-infra
workspace-infra
```

## Deploy This Stack

```bash
make plan STACK=workspace-infra
make deploy STACK=workspace-infra
```

## Destroy This Stack

```bash
make destroy STACK=workspace-infra
```
