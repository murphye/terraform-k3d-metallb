terraform {
  required_providers {
    docker = {
      source = "kreuzwerker/docker"
      version = "2.11.0"
    }
  }
}

variable "k3d_cluster_name" {
  default = "k3s-default"
  type = string
}

variable "k3d_cluster_port" {
  default = 6443
  type = number
}

variable "k3d_cluster_ip" {
  default = "0.0.0.0"
  type = string
}

variable "k3d_server_count" {
  default = 1
  type = number
}

resource "null_resource" "k3d_cluster" {
  triggers = {
    name = var.k3d_cluster_name
    server_count = var.k3d_server_count
    ip = var.k3d_cluster_ip
    port = var.k3d_cluster_port
  }
  provisioner "local-exec" {
    interpreter = [
      "/bin/bash",
      "-c"
    ]
    command = <<TERM
k3d cluster create --servers ${var.k3d_server_count} --network k3d-${var.k3d_cluster_name} --api-port ${var.k3d_cluster_port} --registry-create --no-lb --k3s-server-arg '--no-deploy=traefik' ${var.k3d_cluster_name}
TERM
  }
  provisioner "local-exec" {
    command = "k3d cluster delete ${self.triggers.name}"
    when = destroy
  }
}

data external kubeconfig {
  depends_on = [
    null_resource.k3d_cluster
  ]
  program = [
    "/bin/bash",
    "-c",
<<BASH
kubectl config use-context k3d-${var.k3d_cluster_name}
BASH
  ]
}

data docker_network k3d {
  depends_on = [
    null_resource.k3d_cluster
  ]
  name = "k3d-${var.k3d_cluster_name}"
}

resource "null_resource" "metallb" {
  triggers = {
    name = var.k3d_cluster_name
  }
  depends_on = [
    null_resource.k3d_cluster
  ]
  provisioner "local-exec" {
    environment = {
      KUBECONFIG = data.external.kubeconfig.result["kubeconfig"]
    }
    command = "kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.9.5/manifests/metallb.yaml"
  }
  provisioner "local-exec" {
    command = "kubectl delete -f https://raw.githubusercontent.com/google/metallb/v0.9.5/manifests/metallb.yaml --kubeconfig=$(k3d get-kubeconfig --name='${self.triggers.name}')"
    when = destroy
  }
}

resource "local_file" "metallb_config" {
  depends_on = [
    null_resource.k3d_cluster,
    data.docker_network.k3d
  ]
  filename = "${path.module}/metallb_config.yaml"
  content = <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      avoid-buggy-ips: true
      addresses:
      %{ for subnet in data.docker_network.k3d.ipam_config.*.subnet }
      - ${cidrsubnet(subnet, 4, 3)}
      %{ endfor }
YAML
  }

resource "null_resource" "metallb_config" {
  depends_on = [
    null_resource.k3d_cluster,
    null_resource.metallb
  ]
  triggers = {
    name = var.k3d_cluster_name
    kubeconfig = data.external.kubeconfig.result["kubeconfig"]
    metallb_config = md5(local_file.metallb_config.content)
  }
  provisioner "local-exec" {
    environment = {
      KUBECONFIG = data.external.kubeconfig.result["kubeconfig"]
    }
    command = "kubectl apply -f ${local_file.metallb_config.filename}"
  }
  provisioner "local-exec" {
    command = "kubectl delete -n metallb-system configmap config"
    when = destroy
  }
}

output "kubeconfig" {
  value = file(data.external.kubeconfig.result["kubeconfig"])
  sensitive = true
}
