# Local kubernetes cluster powered by k3d

This terraform module intend to create a local kubernetes cluster using k3d and provide with MetalLB a Layer 2 loadbalancer with the last 4th part of the created docker network.

## Requirements

* terraform 0.12+: 
* kubectl 1.15+: https://kubernetes.io/docs/tasks/tools/install-kubectl/
* jq: https://stedolan.github.io/jq/download/
* docker: https://docs.docker.com/install/
* k3d: https://github.com/rancher/k3d

```
terraform apply -var-file=example.tfvars
terraform destroy -var-file=example.tfvars
```
TODO

Getting error

```
null_resource.k3d_cluster (local-exec): INFO[0009] You can now use it like this:
null_resource.k3d_cluster (local-exec): kubectl config use-context k3d-testing
null_resource.k3d_cluster (local-exec): kubectl cluster-info
null_resource.k3d_cluster: Creation complete after 9s [id=4831948376182366053]
data.external.kubeconfig: Reading...
data.docker_network.k3d: Reading...
data.docker_network.k3d: Read complete after 0s [id=4b9778fc55af0cf603af4818596e807685d1a3fbf05e877120734a84a4cbeaa5]
local_file.metallb_config: Creating...
local_file.metallb_config: Creation complete after 0s [id=7042e5b1707625b88f79d009c32cef467d9c21e8]

Error: command "/bin/bash" produced invalid JSON: invalid character 'S' looking for beginning of value
```