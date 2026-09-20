# Add a user

The identity playbook creates groups `admin` and `user` and the bind account `tinyauth`. You add users in the lldap UI. TinyAuth binds to lldap on localhost.

## UI

lldap listens on `127.0.0.1:17170` on CT 114 (`192.168.1.114`). From the machine that runs the browser:

```bash
ssh -i ~/.ssh/jarvis_ed25519 -N -L 17170:127.0.0.1:17170 root@192.168.1.114
```

Open [http://127.0.0.1:17170](http://127.0.0.1:17170). Username `admin`. From the repo root:

```bash
sops -d --extract '["auth_lldap_admin_password"]' ansible/inventory/group_vars/identity_servers.sops.yml
```

## User

| Field | Value |
| --- | --- |
| User name | login name. |
| Email | `name@antoinejosset.fr` |
| Password | in the UI |

Put the user in `admin` or `user`. A person in both groups gets Admin.

Leave `lldap_admin` and `lldap_strict_readonly` as the playbook set them. Keep `tinyauth` in `lldap_strict_readonly`.
