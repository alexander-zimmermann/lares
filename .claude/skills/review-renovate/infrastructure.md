# Layer 1 — `infrastructure/` · Proxmox IaC

## Context

- `infrastructure/` is OpenTofu, not Terraform: provider features only Terraform supports, such as actions and list resources, do not work here. Provider pins sit in `infrastructure/versions.tf` and in each module's `required_providers` (`infrastructure/modules/<layer>-<name>/main.tf`), the values in `infrastructure/manifest/<layer>/*.yaml`. Find the consumers of a provider by grepping its resource prefix (`proxmox_virtual_environment_`, `pbs_`).
- High blast radius, research these deepest: bpg/proxmox and Omni.
- Nothing in `infrastructure/` applies on merge: CI only runs `tofu validate` and cannot reach PVE or PBS, so there is no plan, and `tofu apply` runs by hand. Every VM has `protection = true`, so a provider change that would replace a VM is a breaking change.
- Versions in `infrastructure/templates/30-cloud-init/` (Omni, its Proxmox infra provider, docker-volume-backup, static curl) reach a VM only through cloud-init at its first boot; the VM ignores later changes (`ignore_changes = [initialization]`). A bump takes effect at that VM's next rebuild, together with every bump since the last one.

## Step 4: diff the provider docs

For an OpenTofu provider, diff the docs page of every resource and data source lares uses between the old and the new tag (`docs/resources/<name>.md`, `docs/data-sources/<name>.md`, the name without the provider prefix; compare filter `.filename | startswith("docs/")`). Check every argument our modules set: renamed, removed, changed default, new required argument, or a change that forces replacement.

Done when every argument we set is accounted for.

## Step 5 and After merge

There is no rendered diff. After merge says what the next `tofu plan` should show, or for a cloud-init version that it waits for the VM's rebuild.
