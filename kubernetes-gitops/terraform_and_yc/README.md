# Prepare with yc for terraform (before Kubernetes cluster creating):

(You should replace <values> with your values on README.md and locals.tf files and then run these actions) 

- yc:

```bash
yc init
yc config list
```

- Service Account:

```bash
yc iam service-account create --name my-admin-sa
yc iam service-account get my-admin-sa
yc iam service-account list
```

- Roles for Service Accounts:

```bash
yc iam role list
yc iam service-account list
yc config list
yc resource-manager folder list-access-bindings <folder-id>
```

```bash
yc resource-manager folder add-access-binding <folder-id> --subject serviceAccount:<my-admin-sa-id> --role admin
yc resource-manager folder list-access-bindings <folder-id>
```

- Create authorized key for my-admin-sa:

```bash
yc iam key create \
  --service-account-id <my-admin-sa-id> \
  --folder-id <folder-id> \
  --output my-admin-sa-key.json
```

- Create CLI profile for my-admin-sa:

```bash
yc config profile create my-admin-sa-profile
```

- Set my-admin-sa-profile configuration:

```bash
yc config set service-account-key my-admin-sa-key.json
yc config set cloud-id <cloud-id>
yc config set folder-id <folder-id>
yc config list
```

- Set ENV variables:

```bash
export YC_TOKEN=$(yc iam create-token)
export YC_CLOUD_ID=$(yc config get cloud-id)
export YC_FOLDER_ID=$(yc config get folder-id)
yc config list
echo $YC_TOKEN
echo $YC_CLOUD_ID
echo $YC_FOLDER_ID
```

# Terraform:

```bash
terraform --version
touch ./my-k8s-cluster.tf
touch ./locals.tf
nano ~/.terraformrc
```

- Contents of ~/.terraformrc: 

```
provider_installation {
  network_mirror {
    url = "https://terraform-mirror.yandexcloud.net/"
    include = ["registry.terraform.io/*/*"]
  }
  direct {
    exclude = ["registry.terraform.io/*/*"]
  }
}
```

- Contents of locals.tf:

```
locals {
  cloud_id    = "<cloud-id>"
  folder_id   = "<folder-id>"
  k8s_version = "1.28"
  sa_name     = "my-cluster-sa"
  zone        = "ru-central1-a"
  allowed_ips = ["my.ip.ad.dr/32"]
}
```

```bash
nano ./my-k8s-cluster.tf
```

- Begin of ./my-k8s-cluster.tf file: 

```
terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

provider "yandex" {
  zone = local.zone
  folder_id = local.folder_id
  service_account_key_file = file("my-admin-sa-key.json")
}
```

Ant then we describe our cluster. Example of K8s cluster is [here](https://terraform-provider.yandexcloud.net//Resources/kubernetes_cluster) and [here](https://cloud.yandex.ru/ru/docs/managed-kubernetes/operations/kubernetes-cluster/kubernetes-cluster-create#tf_1). 

```bash
nano ./my-k8s-cluster.tf
```

## init, validate, plan, apply:

```bash
terraform init
terraform validate
terraform plan
terraform apply
```

## at the end of education or after errors:

```bash
terraform destroy
```

