# K8s - Digital Ocean - Terraform

My study on `How to deploy the K8s cluster in DO using terraform`. Lowering the entry barrier one step at a time.

## Disclaimer

This is an experimental configuration to study infrastructures. Under no circumstances should be used in production.

## Credits

I learned a lot from [this guide from Livewyer](https://www.livewyer.com/blog/2015/05/20/deploying-kubernetes-digitalocean), and [its repo](https://github.com/livewyer-ops/kubernetes-coreos-digitalocean). Also, I replicated the steps from [the official guide of coreos/kubernetes](https://coreos.com/kubernetes/docs/latest/getting-started.html).

## Requirements

* Digital Ocean account
* DO Token [Here](https://cloud.digitalocean.com/settings/tokens/new)
* Terraform installed

Do all the following steps from a development machine. It does not matter _where_ is it, as long as it is connected to the internet. This one will be subsequently used to access the cluster.

## Generate private / public keys

```
ssh-keygen -t rsa -b 4096
```

System will prompt you for a file to save the key, we will go by `~/.ssh/id_rsa` in this tutorial.

## Add your public key in Digital Ocean control panel

[Do it here](https://cloud.digitalocean.com/settings/security). Name it,paste the public key just below `Add SSH Key`.

* TODO: Find a way to do this via API. So we don't access the control panel.

## Add this key to your ssh agent

```bash
eval `ssh-agent -s`
ssh-add ~/.ssh/id_rsa
```

## Invoke terraform

We put our Digitalocean token in the file `DO_TOKEN` (mentioned in `.gitignore`, of course, so we don't leak it)

Then we export our variables (step into `this repository` root)

```bash
export TF_VAR_do_token=$(cat ./secrets/DO_TOKEN)
export TF_VAR_pub_key="~/.ssh/id_rsa.pub"
export TF_VAR_pvt_key="~/.ssh/id_rsa"
export TF_VAR_ssh_fingerprint=$(ssh-keygen -lf ~/.ssh/id_rsa.pub | awk '{print $2}')
```

Let's use this `setup-ssh-env.sh` script

```
source setup-ssh-env.sh
```

Which adds the `ssh` key and the `env` variables...

Finally we call `terraform apply`
e

```bash
terraform apply
```

## Deploy details

### K8s etcd host

#### Cloud config

The following unit is being configured and started

* `etcd2`

### K8s master

#### Cloud config

##### Files

The following files are kubernetes manifests to be loaded by `kubelet`

* `/etc/kubernetes/manifests/kube-apiserver.yaml`
* `/etc/kubernetes/manifests/kube-proxy.yaml`
* `/etc/kubernetes/manifests/kube-podmaster.yaml`
* `/srv/kubernetes/manifests/kube-controller-manager.yaml`
* `/srv/kubernetes/manifests/kube-scheduler.yaml`

##### Units

The following units are being configured and started

* `flanneld`: Specifying that it will use the `k8s-etcd` host's `etcd` service
* `docker`: Dependent on this host's `flannel`
* `kubelet`: The lowest level kubernetes element.

#### Provisions

Once we create this droplet (and get its `IP`),the TLS assets will be created locally (i.e. the development machine from we run `terraform`), and put into the directory `secrets`.

The following files will be placed

```
/etc/kubernetes/ssl/ca.pem
/etc/kubernetes/ssl/apiserver.pem
/etc/kubernetes/ssl/apiserver-key.pem
```

With some modifications to be run

```bash
sudo chmod 600 /etc/kubernetes/ssl/*-key.pem
sudo chown root:root /etc/kubernetes/ssl/*-key.pem
```

Finally, we start `kubelet`, _enable_ it and create the namespace

```bash
sudo systemctl start kubelet
sudo systemctl enable kubelet
until $(curl --output /dev/null --silent --head --fail http://127.0.0.1:8080); do printf '.'; sleep 5; done
curl -XPOST -d'{\"apiVersion\":\"v1\",\"kind\":\"Namespace\",\"metadata\":{\"name\":\"kube-system\"}}' http://127.0.0.1:8080/api/v1/namespaces
```

