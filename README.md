# OKE DR Hands-on Lab: Dual-Region OKE with Terraform

[![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/raphaelsteixeira/fsdr-oke-hands-on-lab/archive/refs/heads/main.zip)

This Terraform creates two independent Oracle Kubernetes Engine (OKE) environments:

- One OKE cluster in the primary region.
- One OKE cluster in the standby region.
- Two worker nodes per cluster by default.
- A standard public/private OKE network topology per region.
- Two private Object Storage buckets per region: one for FSDR logs and one for OKE backup.
- One OCI File Storage file system, mount target, and export on the primary side.
- One OCI File Storage mount target on the standby side, in the standby worker node subnet.
- Full Stack DR resource-principal IAM: dynamic group and policy statements for the deployment compartment.
- One Full Stack DR protection group per region, associated as PRIMARY and STANDBY.

Each region gets its own VCN, public Kubernetes API endpoint subnet, private worker subnet, private pod subnet for OCI VCN-native pod networking, public load balancer subnet, internet gateway, NAT gateway, service gateway, route tables, Network Security Groups (NSGs), Object Storage buckets, and a File Storage mount target. The primary region also gets a File Storage file system and export. IAM resources are created through the home-region provider alias.

## Files

- `versions.tf` pins Terraform and the OCI provider requirements.
- `providers.tf` configures separate OCI provider aliases for the primary and standby regions.
- `iam-fsdr.tf` creates the Full Stack DR dynamic group and policy.
- `fsdr.tf` creates and associates the regional DR protection groups using the FSDR log buckets.
- `schema.yaml` customizes the OCI Resource Manager stack creation form.
- `variables.tf` defines all user-configurable values.
- `main.tf` deploys the reusable OKE module twice.
- `modules/oke-region/` contains the regional OKE infrastructure.
- `terraform.tfvars.example` is a starting point for your lab values.

## Deploy With OCI Resource Manager

Select the **Deploy to Oracle Cloud** button above to create an OCI Resource Manager stack directly from this GitHub repository.

Resource Manager opens the Create Stack workflow with this Terraform package already selected. The included `schema.yaml` groups the required inputs, hides local API-key authentication variables, and exposes student-friendly controls such as region selection, worker node count, OCPU, and memory.

When creating the stack:

- Choose the compartment where the Resource Manager stack will live.
- Set `compartment_ocid` to the compartment where the lab resources should be deployed.
- Set `primary_region` and `standby_region`.
- Set `fsdr_iam_tenancy_ocid` to your tenancy/root compartment OCID when Full Stack DR IAM creation is enabled.
- Set `home_region` if your tenancy home region is different from the primary region.
- Keep **Create and associate DR protection groups** enabled to configure the Full Stack DR pair.
- Leave **Configure freeform tags** unchecked to use no tags, or enable it and enter at least one key/value pair.
- Keep **Run apply** selected if you want Resource Manager to deploy immediately after stack creation.

The deploy button uses the `main` branch zip file. For a fixed classroom version, create a GitHub release and update the button `zipUrl` to the release zip.

### Validate the Resource Manager Form

After editing `schema.yaml`, validate it against [Oracle's meta schema](https://docs.oracle.com/en-us/iaas/Content/ResourceManager/Concepts/terraformconfigresourcemanager_topic-schema.htm). Also run the local reference checks:

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -r tests/requirements.txt
.venv/bin/python -m unittest discover -s tests -v
```

For list and map controls, `valueType` names a hidden entry under `variables`, not a primitive type. Object `attributes` also name hidden entries, each with an `actualName` matching the Terraform attribute. The published meta schema checks the structure but does not catch undefined complex-variable references.

## Usage

Create your local variable file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set at least:

```hcl
compartment_ocid = "ocid1.compartment.oc1..replace-me"
primary_region   = "eu-frankfurt-1"
standby_region   = "eu-madrid-1"
node_count       = 2

# Optional when creating Full Stack DR IAM resources.
# fsdr_iam_tenancy_ocid = "ocid1.tenancy.oc1..replace-me"
```

If the primary region is not your tenancy home region, also set `home_region` to the home region. OCI IAM resources such as dynamic groups and tenancy-attached policies must be created in the home region.

Authenticate with OCI using one of these approaches:

- Use your existing `~/.oci/config` profile. Set `config_file_profile` only if you do not want the provider's default profile behavior.
- Or set the optional variables in `variables.tf`: `tenancy_ocid`, `user_ocid`, `fingerprint`, and `private_key_path`.
- Or export the equivalent `TF_VAR_*` or `OCI_*` environment variables supported by the OCI Terraform provider.

Then run:

```bash
terraform init
terraform plan
terraform apply
```

After apply, Terraform outputs the `oci ce cluster create-kubeconfig` commands for both clusters.

The outputs also include the regional Object Storage bucket names and namespaces for FSDR logs and OKE backup, the Full Stack DR IAM resource names and IDs, the associated DR protection groups in `fsdr`, plus the primary and standby File Storage mount target details.

## Full Stack DR Protection Groups

By default, `enable_fsdr = true` creates a DR protection group in each region in `compartment_ocid`:

| Region | DR protection group | Log bucket | Initial role |
| --- | --- | --- | --- |
| `primary_region` | `${name_prefix}-${primary_region_short_name}-drpg` | `${name_prefix}-${primary_region_short_name}-fsdr-logs` | `PRIMARY` |
| `standby_region` | `${name_prefix}-${standby_region_short_name}-drpg` | `${name_prefix}-${standby_region_short_name}-fsdr-logs` | `STANDBY` |

The regional modules already create the dedicated, private, Standard-tier FSDR log buckets. This configuration reuses them without renaming or duplicating buckets; the separate OKE backup buckets are unchanged.

Terraform first creates the DRPG in `primary_region` without an association. It then creates the DRPG in `standby_region` with the peer OCID, peer region, and role `STANDBY`. [OCI assigns the complementary role to the peer](https://docs.oracle.com/en-us/iaas/disaster-recovery/doc/create-dr-protection-groups.html), so both groups are associated in one deployment without a circular dependency. Their display names use the region short labels, such as `oke-dr-lab-fra-drpg` and `oke-dr-lab-mad-drpg`.

When IAM is enabled, the groups wait for the Terraform-managed policy to be created. When `enable_fsdr_iam = false`, equivalent resource-principal policies must already exist. The identity running Terraform or Resource Manager also needs permission to manage DR protection groups in the deployment compartment and access their log buckets. New IAM permissions can take time to propagate; retry an authorization failure after they take effect.

The groups start empty. Adding the OKE clusters, File Storage, and other members, configuring replication/backup prerequisites, and creating DR plans remain subsequent lab steps. Terraform deliberately ignores changes to DRPG membership so later manual lab additions are preserved. This configuration does not enable automatic application recovery on its own.

The `fsdr` output includes each group's OCID, display name, current role, peer OCID/region, and log bucket/namespace. Terraform reads both groups after pairing so the first apply returns their final roles.

## Configure Full Stack DR After Terraform Deployment

Terraform deploys the regional infrastructure, creates the FSDR log and OKE backup buckets, creates the resource-principal IAM resources (by default), and associates the primary and standby DR protection groups. It does not add the OKE clusters or storage to the groups, configure storage replication, or create DR plans. Complete the following steps after the stack apply.

### 1. Record and verify the deployed resources

In Resource Manager, open the stack's **Outputs** tab. For a local Terraform deployment, use:

```bash
terraform output fsdr
terraform output primary
terraform output standby
```

Record the two DR protection group names and OCIDs, the OKE cluster OCIDs, and each region's `oke_backup` bucket name. Verify that the primary group has role `PRIMARY`, the standby group has role `STANDBY`, and each group's peer points to the other. The output values reflect the actual region short names and bucket names for your deployment.

### 2. Confirm IAM and console access

If `enable_fsdr_iam = true`, check the `fsdr_iam` output for the generated dynamic group and policy. The policy authorizes the Full Stack DR resource principals to orchestrate resources in the deployment compartment. Allow new IAM policy changes time to propagate. If `enable_fsdr_iam = false`, have your tenancy administrator configure equivalent Full Stack DR and OKE policies before continuing. The user or group performing these console steps also needs permission to manage DR protection groups and plans, OKE, and any storage resources being added.

### 3. Prepare the stateful workload's storage before adding it to DR

This step is required if you deployed the sample `nginx-lab` workload and need its persistent data to recover. OKE cluster backup saves Kubernetes configuration; it does not by itself replicate the data in persistent volumes.

- **Block volume at `/data/block`:** Find the block volume provisioned for `nginx-block-pvc`. Create a volume group in the volume's availability domain, add the volume, and configure cross-region volume-group replication to the standby region (or an appropriate cross-region backup workflow). The current Terraform stack does not create this volume group or replication.
- **File Storage at `/data/fss`:** Terraform creates the primary file system and export, plus a standby mount target. It does not create a standby file system or replication. Configure File Storage replication to the standby region first. The standby mount target should be used for the destination export mapping when you add the file system member in step 5. Confirm the target region has the capacity and availability domains needed for failover.
- **Kubernetes manifest:** Before applying `k8s/primary-nginx-lab.yaml`, replace its sample File Storage mount-target OCID and `volumeHandle` values with the deployed values from `primary.file_storage`. For recovery, account for the static NFS persistent volume: the restored Kubernetes resource must use the recovered file system and the standby mount target. Configure an OKE resource modifier mapping or an equivalent plan step for the standby values; the primary file system ID and mount-target IP cannot be reused there.

For the File Storage replication lifecycle and failover constraints, see [File Storage replication for disaster recovery](https://docs.oracle.com/en-us/iaas/Content/File/Tasks/replication-disaster-recovery.htm). For OKE prerequisites and persistent-volume requirements, see [Preparing OKE for Disaster Recovery](https://docs.oracle.com/en-us/iaas/disaster-recovery/doc/prepare-oke-disaster-recovery.html) and [Preparing Block Storage for Full Stack DR](https://docs.oracle.com/en-us/iaas/disaster-recovery/doc/block-storage-disaster-recovery.html).

### 4. Add the primary OKE cluster

In the OCI Console, open **Migration & Disaster Recovery → Disaster Recovery → DR protection groups**, choose the deployment compartment, and open the primary DR protection group. Under **Members**, select **Add member** and choose **OKE Cluster**.

Configure the primary cluster as follows:

1. Select the primary OKE cluster from the Terraform output.
2. Select the primary region's `${name_prefix}-${primary_region_short_name}-oke-backup` bucket (use the actual bucket name from the output).
3. Enable the backup schedule. Choose an hourly or daily interval that meets the lab's recovery point objective, set a UTC start time, and choose a retention count.
4. For namespaces, include all namespaces for the lab, or explicitly include every namespace and dependency needed by the application.
5. Select the standby OKE cluster as the peer cluster. Configure image replication only for private images that need it; Full Stack DR does not replicate public images. Ensure the standby nodes can pull any public images the workload uses.
6. If using the static File Storage volume above, configure the resource modifier mapping for the standby file system and mount target.
7. Accept the plan-refresh warning and click **Add**.

Oracle's [Add an OKE Cluster to a DR Protection Group](https://docs.oracle.com/iaas/disaster-recovery/doc/add-oke-cluster-protection-group.html) reference describes the member properties and optional advanced settings.

### 5. Add the peer OKE cluster and replicated storage

Follow the OKE-specific pairing workflow and open the standby DR protection group. Add the standby OKE cluster as an **OKE Cluster** member, select the standby region's OKE backup bucket, and set its peer to the primary OKE cluster. You can also configure a backup schedule for this cluster so its configuration is backed up if the DR roles later reverse. Accept the warning and add the member.

Then, in the primary DR protection group, add the replicated stateful storage that the workload depends on:

1. Select **Add member → Volume Group**. Choose the replicated volume group and provide its destination compartment and destination backup policy if prompted.
2. Select **Add member → File system** for the replicated primary file system. Set the standby destination compartment and availability domain, and map the source `/oke` export to the Terraform-created standby mount target.
3. Accept the plan-refresh warning for each member addition.

Add only storage that has already been prepared for recovery. See [Add a Volume Group](https://docs.oracle.com/iaas/disaster-recovery/doc/add-volume-group.html) and [Add a File System](https://docs.oracle.com/en/cloud/iaas/disaster-recovery/cssgm/add-file-storage-system.html) for the member fields. The [Oracle stateful OKE tutorial](https://docs.oracle.com/en/learn/ocioke-plan-ocifsdr/index.html) shows the paired-cluster and volume-group workflow.

### 6. Create and verify DR plans

Plans are created in the currently **standby** protection group. Open the standby DR protection group's **Plans** page and create the plans needed for operations:

- **Switchover** for a planned move to the standby region.
- **Failover** for an unplanned recovery.
- **Start Drill** and **Stop Drill** to test recovery without changing the production roles.

If a plan existed before you added or changed members, refresh it and then verify it. Review the generated groups and steps against the actual OKE peer, backup buckets, storage replication, export mappings, and resource modifiers. Oracle requires a refreshed plan to be verified before use; see [Refresh a DR Plan](https://docs.oracle.com/en/cloud/iaas/disaster-recovery/cssgm/refresh-plan.html) and [Verify a DR Plan](https://docs.oracle.com/en-us/iaas/disaster-recovery/doc/verify-plan.html). If you add all members before creating plans, create the plans after step 5 so they are generated from the completed topology.

### 7. Run prechecks and a drill

Run the plan's **Prechecks** first and resolve every error or warning that affects recovery. Then execute **Start Drill**, connect to the standby cluster, and verify that the expected namespaces, pods, service endpoints, and persistent data are available. Execute **Stop Drill** when finished to clean up the drill resources. Do not use a production Switchover or Failover plan as a connectivity test; those plans perform a real DR transition.

Repeat prechecks periodically and run drills on a schedule. A paired protection-group status alone does not mean application recovery is ready: readiness depends on successful backups, replicated storage, correct peer mappings, and verified plans.

### Verify Without Deploying

With Terraform 1.7 or later, run the mocked tests. They use fake OCI providers and override the OKE modules, so no cloud resources are created and no OCI credentials are required:

```bash
terraform test -filter=tests/fsdr.tftest.hcl
```

### Cleanup

[OCI requires disassociation before deleting a DR protection group](https://docs.oracle.com/en-us/iaas/disaster-recovery/doc/delete-dr-protection-group.html). Before destroying the stack, disabling `enable_fsdr`, or replacing either DRPG, increase `fsdr_disassociate_trigger` above its previously applied value and run **Apply** first. For the first cleanup, starting from the default `0`:

```bash
terraform apply -var="fsdr_disassociate_trigger=1"
terraform destroy -var="fsdr_disassociate_trigger=1"
```

In Resource Manager, set the trigger to `1`, run an Apply job, verify that both groups are unassociated, and only then run Destroy. Keep the increased value for subsequent operations; do not reset it to `0`. If the groups were already disassociated in the Console, do not increment the trigger again. An association is a creation-time setting in the OCI provider, so re-associating an existing pair requires an explicit follow-up operation and is not achieved by resetting this trigger.

## Full Stack DR IAM

By default, `enable_fsdr_iam = true` creates:

- Dynamic group: `${name_prefix}-fsdr-resource-principals`
- Policy: `${name_prefix}-fsdr-resource-principal-policy`

The dynamic group matches DR protection groups, compute instances, and compute container instances in `compartment_ocid`. The policy is attached in the tenancy root because OCI IAM resources live there, while the service-management statements are scoped to `compartment_ocid`.

The policy grants the Full Stack DR resource principals permissions for the services used by this lab: Full Stack DR, OKE, compute instances and agent commands, compute images, networking, block volumes, File Storage, Object Storage, load balancers, network load balancers, tag namespaces, and resource discovery.

If your administrator already manages these IAM resources outside this stack, set:

```hcl
enable_fsdr_iam = false
```

## Useful Lab Adjustments

- `primary_region` and `standby_region`: change the target regions.
- `compartment_ocid`: change the compartment for all resources.
- `fsdr_iam_tenancy_ocid`: tenancy/root compartment OCID used to create Full Stack DR IAM resources. Terraform can infer this from `oci_config_file_path` and `config_file_profile` when your OCI config contains a `tenancy = ...` entry.
- `oci_config_file_path`: defaults to `~/.oci/config` and is only used as a tenancy OCID fallback for FSDR IAM.
- `home_region`: tenancy home region for IAM resources; defaults to `primary_region`.
- `enable_fsdr_iam`: set to `false` if IAM is handled separately.
- `enable_fsdr`: defaults to `true`; set to `false` to skip DRPG creation. Existing groups must be disassociated before disabling this setting.
- `fsdr_disassociate_trigger`: maintenance-only integer, initially `0`; increase and apply to disassociate the groups before cleanup.
- `primary_region_short_name` and `standby_region_short_name`: optionally override the short region labels used in OCI resource names. The defaults are `fra` for `eu-frankfurt-1` and `mad` for `eu-madrid-1`.
- `node_count`: number of worker nodes in each OKE cluster; defaults to `2`.
- `node_shape`, `node_ocpus`, and `node_memory_in_gbs`: change worker sizing for Flex shapes.
- `node_shape_config`: optional advanced object override for Flex sizing.
- `kubernetes_version`: pins both clusters to the same full OKE patch version. The default is `v1.35.2`, which Oracle announced for OKE on April 28, 2026.
- `cluster_type`: defaults to `ENHANCED_CLUSTER`.
- `node_pool_os_type` and `node_pool_os_arch`: control the OKE worker image family selected from OCI node pool options. The default is `OL8` and `X86_64`.
- `node_image_id`: optionally pin a region-local custom worker image OCID instead of selecting from OCI node pool options.
- `kube_api_allowed_cidrs`: restrict public access to the Kubernetes API endpoint. The regional VCN CIDR is always allowed.
- `load_balancer_ingress_cidrs` and `load_balancer_ingress_ports`: restrict public load balancer exposure.

## Network Security Groups

The module creates four base NSGs per region:

- API endpoint NSG: attached to the OKE Kubernetes API endpoint.
- Worker NSG: attached to worker node VNICs and configured as the default backend NSG for OKE load balancers.
- Pod NSG: attached to pod VNICs when using OCI VCN-native pod networking.
- Load balancer NSG: created with public ingress rules for `load_balancer_ingress_ports`; use its OCID in Kubernetes service annotations when you want a service load balancer to join this NSG.

When a File Storage mount target is enabled in a region, the module also creates a File Storage NSG and attaches it to the mount target.

The API endpoint NSG includes the OKE-required worker and pod registration paths to TCP/6443 and TCP/12250. The worker NSG also allows API-endpoint-to-kubelet traffic on TCP/10250 and ICMP type 3/code 4 for path MTU discovery.

The Kubernetes API endpoint has public access enabled and remains protected by the API endpoint NSG. For a safer lab, replace `0.0.0.0/0` in `kube_api_allowed_cidrs` with your workstation, VPN, or corporate egress CIDR.

OCI requires every subnet to be associated with at least one security list. To keep packet access controlled by NSGs, the module attaches a single empty security list to the subnets and places all allow rules in NSGs.

The worker and pod subnets route `0.0.0.0/0` through the NAT gateway for outbound internet access. Their private route table also keeps the service gateway route to Oracle Services Network.

For Kubernetes `Service` objects of type `LoadBalancer`, Oracle recommends NSG rule management through annotations such as `oci.oraclecloud.com/security-rule-management-mode: "NSG"`. To attach a load balancer to the Terraform-created frontend NSG, use `oci.oraclecloud.com/oci-network-security-groups` with the regional `load_balancers` NSG OCID from Terraform outputs.

## File Storage

The primary region creates one OCI File Storage file system, mount target, and export:

- File system: `${name_prefix}-${primary_region_short_name}-fss`
- Mount target: `${name_prefix}-${primary_region_short_name}-fss-mt`
- Export path: `/oke`

The standby region creates a File Storage mount target in the standby worker subnet:

- Mount target: `${name_prefix}-${standby_region_short_name}-fss-mt`

Each mount target is protected by a dedicated File Storage NSG. The NSG allows TCP ports `111`, `2048`, `2049`, `2050`, and `20048`, plus UDP ports `111`, `2048`, and `20048`, from the regional worker subnet CIDR. Mount target details are returned in `primary.file_storage` and `standby.file_storage`. The primary output also includes the export path and a sample `mount` command.

## Verify Kubernetes Volumes

After applying `k8s/primary-nginx-lab.yaml` to the primary cluster, wait for the nginx pod to be ready:

```bash
kubectl -n oke-dr-lab get pods -l app.kubernetes.io/name=nginx-lab
```

Open a shell in the nginx container:

```bash
kubectl -n oke-dr-lab exec -it deploy/nginx-lab -- sh
```

From inside the container, confirm both persistent volume mount paths exist:

```sh
df -h /data/block /data/fss
mount | grep '/data/'
```

Write and read a small test file on each volume:

```sh
date > /data/block/block-volume-test.txt
date > /data/fss/file-storage-test.txt
cat /data/block/block-volume-test.txt
cat /data/fss/file-storage-test.txt
exit
```

You can also run the same checks without opening an interactive shell:

```bash
kubectl -n oke-dr-lab exec deploy/nginx-lab -- sh -c 'df -h /data/block /data/fss'
kubectl -n oke-dr-lab exec deploy/nginx-lab -- sh -c 'date > /data/block/block-volume-test.txt && cat /data/block/block-volume-test.txt'
kubectl -n oke-dr-lab exec deploy/nginx-lab -- sh -c 'date > /data/fss/file-storage-test.txt && cat /data/fss/file-storage-test.txt'
```

## Verify Nginx Web App

The `k8s/primary-nginx-lab.yaml` manifest also deploys a lightweight nginx web app named `nginx-web`. The app uses a `ClusterIP` service and an `Ingress` with `ingressClassName: istio`, so applying the manifest does not create a new OCI load balancer.

Use the Terraform-managed load balancer to send HTTP traffic to the Istio ingress controller, then route requests with host `web.example.com` to the `nginx-web` service.

Apply the manifest:

```bash
kubectl apply -f k8s/primary-nginx-lab.yaml
```

If an older version of the manifest created the `nginx-web-lb` service, delete it so OKE removes the Kubernetes-managed OCI load balancer:

```bash
kubectl -n oke-dr-lab delete svc nginx-web-lb
```

Check that the deployment, service, and ingress exist:

```bash
kubectl -n oke-dr-lab get deploy nginx-web
kubectl -n oke-dr-lab get svc nginx-web
kubectl -n oke-dr-lab get ingress nginx-web
```

Find the Istio ingress service that your Terraform-managed load balancer should target:

```bash
kubectl -n istio-system get svc
```

Test the web app through the Terraform-managed load balancer:

```bash
curl -H 'Host: web.example.com' http://<TERRAFORM_LB_ADDRESS>/
```

You can also test directly against the Istio ingress service address:

```bash
kubectl -n istio-system get svc
```

Test the web app through Istio using the ingress address from the previous command:

```bash
curl -H 'Host: web.example.com' http://<ISTIO_INGRESS_ADDRESS>/
```

## Object Storage

Each region creates two private Object Storage buckets:

- `${name_prefix}-${region_short_name}-fsdr-logs`
- `${name_prefix}-${region_short_name}-oke-backup`

The OKE backup bucket has object versioning enabled. Bucket names are returned in the `primary.object_storage_buckets` and `standby.object_storage_buckets` outputs.

Workloads use the standard regional Object Storage endpoints and the VCN service gateway or NAT gateway paths provided by the regional network topology.

## Notes

The default worker nodes use `VM.Standard.E4.Flex` with 1 OCPU and 16 GB RAM. If you switch to a fixed-size shape, set `node_shape_config = null`.

The worker node image is selected from OCI node pool options by default. Set `node_image_id` only if you need a specific region-local worker image OCID.
