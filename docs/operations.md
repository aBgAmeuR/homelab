# Operations

## Secrets

Secrets are encrypted with SOPS and an age key. The private key is read from `~/.config/sops/age/keys.txt`. Guest SSH uses `~/.ssh/jarvis_ed25519`.

Edit an encrypted file:

```bash
sops terraform/secrets.sops.yaml
sops ansible/inventory/group_vars/all.sops.yml
sops ansible/inventory/group_vars/garage_servers.sops.yml
sops ansible/inventory/group_vars/observability.sops.yml
sops ansible/inventory/group_vars/reverse_proxies.sops.yml
sops ansible/inventory/group_vars/identity_servers.sops.yml
sops ansible/inventory/host_vars/docker.sops.yml
```

## Commands

Run `task` with no argument to list the available tasks.

```bash
task tf:init
task tf:plan
task tf:apply
task ansible -- playbooks/site.yml
task check
```

`task check` runs `terraform fmt -check`, `terraform validate`, and `ansible-playbook --syntax-check` on `playbooks/site.yml`.

Terraform state lives in Garage (S3 on CT 112). The `tf:*` tasks decrypt the S3 keys and the Proxmox API token with SOPS and pass them to Terraform as environment variables. Nothing is written to disk.
