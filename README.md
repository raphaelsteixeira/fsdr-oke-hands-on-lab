# OKE DR Hands-on Lab: Dual-Region OKE with Terraform

[![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/raphaelsteixeira/fsdr-oke-hands-on-lab/archive/refs/heads/main.zip)

This Terraform creates two independent Oracle Kubernetes Engine (OKE) environments:

- One OKE cluster in the primary region.
- One OKE cluster in the standby region.
- Two worker nodes per cluster by default.
- A standard public/private OKE network topology per region.
- Two private Object Storage buckets per region: one for FSDR logs and one for OKE backup.
- One OCI File Storage file system on the primary side, with its mount target in the primary worker node subnet.

Each region gets its own VCN, public Kubernetes API endpoint subnet, private worker subnet, private pod subnet for OCI VCN-native pod networking, public load balancer subnet, internet gateway, NAT gateway, service gateway, route tables, Network Security Groups (NSGs), and Object Storage buckets. The primary region also gets File Storage.

## Files

- `versions.tf` pins Terraform and the OCI provider requirements.
- `providers.tf` configures separate OCI provider aliases for the primary and standby regions.
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
- Keep **Run apply** selected if you want Resource Manager to deploy immediately after stack creation.

The deploy button uses the `main` branch zip file. For a fixed classroom version, create a GitHub release and update the button `zipUrl` to the release zip.

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
```

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

The outputs also include the regional Object Storage bucket names and namespaces for FSDR logs and OKE backup, plus the primary File Storage mount target details.

## Useful Lab Adjustments

- `primary_region` and `standby_region`: change the target regions.
- `compartment_ocid`: change the compartment for all resources.
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

When File Storage is enabled on the primary region, the module also creates a File Storage NSG and attaches it to the mount target.

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

The mount target is created in the primary worker subnet and is protected by a dedicated File Storage NSG. The NSG allows TCP ports `111`, `2048`, `2049`, `2050`, and `20048`, plus UDP ports `111`, `2048`, and `20048`, from the worker subnet CIDR. Mount target IP, export path, and a sample `mount` command are returned in `primary.file_storage`.

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
