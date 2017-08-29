###############################################################################
#
# A simple K8s cluster in DO
#
###############################################################################


###############################################################################
#
# Get variables from command line or environment
#
###############################################################################


variable "do_token" {}
variable "do_region" {
    default = "nyc3"
}
variable "ssh_fingerprint" {}
variable "ssh_private_key" {
    default = "~/.ssh/id_rsa"
}

variable "number_of_workers" {}
variable "hyperkube_version" {
    default = "v1.7.3_coreos.0"
}

variable "prefix" {
    default = ""
}

variable "size_etcd" {
    default = "512mb"
}

variable "size_master" {
    default = "1gb"
}

variable "size_worker" {
    default = "512mb"
}

###############################################################################
#
# Specify provider
#
###############################################################################

provider "digitalocean" {
  token = "${var.do_token}"
}


###############################################################################
#
# Etcd host
#
###############################################################################


resource "digitalocean_droplet" "k8s_etcd" {
    image = "coreos-stable"
    name = "${var.prefix}k8s-etcd"
    region = "${var.do_region}"
    private_networking = true
    size = "${var.size_etcd}"
    user_data = "${file("${path.module}/00-etcd.yaml")}"
    ssh_keys = ["${split(",", var.ssh_fingerprint)}"]

    # Generate the Certificate Authority
    provisioner "local-exec" {
        command = <<EOF
            ${path.module}/cfssl/generate_ca.sh
EOF
    }

    # Generate k8s-etcd server certificate
    provisioner "local-exec" {
        command = <<EOF
            ${path.module}/cfssl/generate_server.sh k8s_etcd ${digitalocean_droplet.k8s_etcd.ipv4_address_private}
EOF
    }

    # Provision k8s_etcd server certificate
    provisioner "file" {
        source = "./secrets/ca.pem"
        destination = "/home/core/ca.pem"
        connection {
            type = "ssh",
            user = "core",
            private_key = "${file(var.ssh_private_key)}"
        }
    }
    provisioner "file" {
        source = "./secrets/k8s_etcd.pem"
        destination = "/home/core/etcd.pem"
        connection {
            type = "ssh",
            user = "core",
            private_key = "${file(var.ssh_private_key)}"
        }
    }
    provisioner "file" {
        source = "./secrets/k8s_etcd-key.pem"
        destination = "/home/core/etcd-key.pem"
        connection {
            type = "ssh",
            user = "core",
            private_key = "${file(var.ssh_private_key)}"
        }
    }

    # TODO: figure out etcd2 user and chown, chmod key.pem files
    provisioner "remote-exec" {
        inline = [
            "sudo mkdir -p /etc/kubernetes/ssl",
            "sudo mv /home/core/{ca,etcd,etcd-key}.pem /etc/kubernetes/ssl/."
        ]
        connection {
            type = "ssh",
            user = "core",
            private_key = "${file(var.ssh_private_key)}"
        }
    }

    # Start etcd2
    provisioner "remote-exec" {
        inline = [
            "sudo systemctl start etcd2",
            "sudo systemctl enable etcd2",
        ]
        connection {
            type = "ssh",
            user = "core",
            private_key = "${file(var.ssh_private_key)}"
        }
    }
}

###############################################################################
#
# Master host's user data template
#
###############################################################################

data "template_file" "master_yaml" {
    template = "${file("${path.module}/01-master.yaml")}"
    vars {
        DNS_SERVICE_IP = "10.3.0.10"
        ETCD_IP = "${digitalocean_droplet.k8s_etcd.ipv4_address_private}"
        POD_NETWORK = "10.2.0.0/16"
        SERVICE_IP_RANGE = "10.3.0.0/24"
        HYPERKUBE_VERSION = "${var.hyperkube_version}"
    }
}

###############################################################################
#
# Master host
#
###############################################################################

resource "digitalocean_droplet" "k8s_master" {
    image = "coreos-stable"
    name = "${var.prefix}k8s-master"
    region = "${var.do_region}"
    private_networking = true
    size = "${var.size_master}"
    user_data = "${data.template_file.master_yaml.rendered}"
    ssh_keys = ["${split(",", var.ssh_fingerprint)}"]

    # Generate k8s_master server certificate
    provisioner "local-exec" {
        command = <<EOF
            ${path.module}/cfssl/generate_server.sh k8s_master "${digitalocean_droplet.k8s_master.ipv4_address},${digitalocean_droplet.k8s_master.ipv4_address_private},10.3.0.1,kubernetes.default,kubernetes"
EOF
    }

    # Provision k8s_etcd server certificate
    provisioner "file" {
        source = "./secrets/ca.pem"
        destination = "/home/core/ca.pem"
        connection {
            type = "ssh",
            user = "core",
            private_key = "${file(var.ssh_private_key)}"
        }
    }
    provisioner "file" {
        source = "./secrets/k8s_master.pem"
        destination = "/home/core/apiserver.pem"
        connection {
            type = "ssh",
            user = "core",
            private_key = "${file(var.ssh_private_key)}"
        }
    }
    provisioner "file" {
        source = "./secrets/k8s_master-key.pem"
        destination = "/home/core/apiserver-key.pem"
        connection {
            type = "ssh",
            user = "core",
            private_key = "${file(var.ssh_private_key)}"
        }
    }

    # Generate k8s_master client certificate
    provisioner "local-exec" {
        command = <<EOF
            ${path.module}/cfssl/generate_client.sh k8s_master
EOF
    }

    # Provision k8s_master client certificate
    provisioner "file" {
        source = "./secrets/client-k8s_master.pem"
        destination = "/home/core/client.pem"
        connection {
            type = "ssh",
            user = "core",
            private_key = "${file(var.ssh_private_key)}"
        }
    }
    provisioner "file" {
        source = "./secrets/client-k8s_master-key.pem"
        destination = "/home/core/client-key.pem"
        connection {
            type = "ssh",
            user = "core",
            private_key = "${file(var.ssh_private_key)}"
        }
    }

    # TODO: figure out permissions and chown, chmod key.pem files
    provisioner "remote-exec" {
        inline = [
            "sudo mkdir -p /etc/kubernetes/ssl",
            "sudo cp /home/core/{ca,apiserver,apiserver-key,client,client-key}.pem /etc/kubernetes/ssl/.",
            "rm /home/core/{apiserver,apiserver-key}.pem",
            "sudo mkdir -p /etc/ssl/etcd",
            "sudo mv /home/core/{ca,client,client-key}.pem /etc/ssl/etcd/.",
        ]
        connection {
            type = "ssh",
            user = "core",
            private_key = "${file(var.ssh_private_key)}"
        }
    }

    # Start kubelet and create kube-system namespace
    provisioner "remote-exec" {
        inline = [
            "sudo systemctl daemon-reload",
            "curl --cacert /etc/kubernetes/ssl/ca.pem --cert /etc/kubernetes/ssl/client.pem --key /etc/kubernetes/ssl/client-key.pem -X PUT -d 'value={\"Network\":\"10.2.0.0/16\",\"Backend\":{\"Type\":\"vxlan\"}}' https://${digitalocean_droplet.k8s_etcd.ipv4_address_private}:2379/v2/keys/coreos.com/network/config",
            "sudo systemctl start flanneld",
            "sudo systemctl enable flanneld",
            "sudo systemctl start kubelet",
            "sudo systemctl enable kubelet"
        ]
        connection {
            type = "ssh",
            user = "core",
            private_key = "${file(var.ssh_private_key)}"
        }
    }
}

###############################################################################
#
# Worker host's user data template
#
###############################################################################


data "template_file" "worker_yaml" {
    template = "${file("${path.module}/02-worker.yaml")}"
    vars {
        DNS_SERVICE_IP = "10.3.0.10"
        ETCD_IP = "${digitalocean_droplet.k8s_etcd.ipv4_address_private}"
        MASTER_HOST = "${digitalocean_droplet.k8s_master.ipv4_address_private}"
        HYPERKUBE_VERSION = "${var.hyperkube_version}"
    }
}


###############################################################################
#
# Worker hosts
#
###############################################################################

resource "digitalocean_droplet" "k8s_worker" {
    count = "${var.number_of_workers}"
    image = "coreos-stable"
    name = "${var.prefix}${format("k8s-worker-%02d", count.index + 1)}"
    region = "${var.do_region}"
    size = "${var.size_worker}"
    private_networking = true
    user_data = "${data.template_file.worker_yaml.rendered}"
    ssh_keys = ["${split(",", var.ssh_fingerprint)}"]



    # Generate k8s_worker client certificate
    provisioner "local-exec" {
        command = <<EOF
            ${path.module}/cfssl/generate_client.sh k8s_worker
EOF
    }

    # Provision k8s_master client certificate
    provisioner "file" {
        source = "./secrets/ca.pem"
        destination = "/home/core/ca.pem"
        connection {
            type = "ssh",
            user = "core",
            private_key = "${file(var.ssh_private_key)}"
        }
    }
    provisioner "file" {
        source = "./secrets/client-k8s_worker.pem"
        destination = "/home/core/worker.pem"
        connection {
            type = "ssh",
            user = "core",
            private_key = "${file(var.ssh_private_key)}"
        }
    }
    provisioner "file" {
        source = "./secrets/client-k8s_worker-key.pem"
        destination = "/home/core/worker-key.pem"
        connection {
            type = "ssh",
            user = "core",
            private_key = "${file(var.ssh_private_key)}"
        }
    }

    # TODO: permissions on these keys
    provisioner "remote-exec" {
        inline = [
            "sudo mkdir -p /etc/kubernetes/ssl",
            "sudo cp /home/core/{ca,worker,worker-key}.pem /etc/kubernetes/ssl/.",
            "sudo mkdir -p /etc/ssl/etcd/",
            "sudo mv /home/core/{ca,worker,worker-key}.pem /etc/ssl/etcd/."
        ]
        connection {
            type = "ssh",
            user = "core",
            private_key = "${file(var.ssh_private_key)}"
        }
    }

    # Start kubelet
    provisioner "remote-exec" {
        inline = [
            "sudo systemctl daemon-reload",
            "sudo systemctl start flanneld",
            "sudo systemctl enable flanneld",
            "sudo systemctl start kubelet",
            "sudo systemctl enable kubelet"
        ]
        connection {
            type = "ssh",
            user = "core",
            private_key = "${file(var.ssh_private_key)}"
        }
    }
}

###############################################################################
#
# etcd host firewall
#
###############################################################################

resource "digitalocean_firewall" "k8s_etcd" {
  name = "${var.prefix}k8s-etcd-fw"

  droplet_ids = ["${digitalocean_droplet.k8s_etcd.id}"]

  inbound_rule = [
    {
      protocol           = "tcp"
      port_range         = "22"
      source_addresses   = ["${digitalocean_droplet.k8s_master.ipv4_address_private}"]
    },
    {
      protocol           = "tcp"
      port_range         = "2379-2380"
      source_addresses   = ["${digitalocean_droplet.k8s_master.ipv4_address_private}", "${digitalocean_droplet.k8s_worker.*.ipv4_address_private}"]
    },
  ]

  outbound_rule = [
    {
      protocol                = "tcp"
      port_range              = "all"
      destination_addresses   = ["0.0.0.0/0", "::/0"]
    },
    {
      protocol                = "udp"
      port_range              = "all"
      destination_addresses   = ["0.0.0.0/0", "::/0"]
    },
  ]

}

###############################################################################
#
# worker host firewall
#
###############################################################################

resource "digitalocean_firewall" "k8s_worker" {
  name = "${var.prefix}k8s-worker-fw"

  droplet_ids = ["${digitalocean_droplet.k8s_worker.*.id}"]

  inbound_rule = [
    {
      protocol           = "tcp"
      port_range         = "all"
      source_addresses   = ["${digitalocean_droplet.k8s_master.ipv4_address_private}", "${digitalocean_droplet.k8s_worker.*.ipv4_address_private}"]
    },
    {
      protocol           = "tcp"
      port_range         = "10250"
      source_addresses   = ["${digitalocean_droplet.k8s_master.ipv4_address_private}", "${digitalocean_droplet.k8s_worker.*.ipv4_address_private}"]
    },
    {
      protocol           = "tcp"
      port_range         = "10255"
      source_addresses   = ["${digitalocean_droplet.k8s_master.ipv4_address_private}"]
    },
    {
      protocol           = "udp"
      port_range         = "8285"
      source_addresses   = ["${digitalocean_droplet.k8s_master.ipv4_address_private}", "${digitalocean_droplet.k8s_worker.*.ipv4_address_private}"]
    },
    {
      protocol           = "udp"
      port_range         = "8472"
      source_addresses   = ["${digitalocean_droplet.k8s_master.ipv4_address_private}", "${digitalocean_droplet.k8s_worker.*.ipv4_address_private}"]
    },
    {
      protocol           = "tcp"
      port_range         = "80"
      source_addresses = ["0.0.0.0/0"]
    },
  ]

  outbound_rule = [
    {
      protocol                = "tcp"
      port_range              = "all"
      destination_addresses   = ["0.0.0.0/0", "::/0"]
    },
    {
      protocol                = "udp"
      port_range              = "all"
      destination_addresses   = ["0.0.0.0/0", "::/0"]
    },
  ]
}

###############################################################################
#
# master host firewall
#
###############################################################################

resource "digitalocean_firewall" "k8s_master" {
  name = "${var.prefix}k8s-master-fw"

  droplet_ids = ["${digitalocean_droplet.k8s_master.id}"]

  inbound_rule = [
    {
      protocol           = "tcp"
      port_range         = "22"
      source_addresses = ["0.0.0.0/0"]
    },

    {
      protocol           = "tcp"
      port_range         = "443"
      source_addresses = ["0.0.0.0/0"]
    },
    {
      protocol           = "tcp"
      port_range         = "8285"
      source_addresses   = ["${digitalocean_droplet.k8s_worker.*.ipv4_address_private}"]
    },
    {
      protocol           = "udp"
      port_range         = "8472"
      source_addresses   = ["${digitalocean_droplet.k8s_worker.*.ipv4_address_private}"]
    },
  ]
  outbound_rule = [
    {
      protocol                = "tcp"
      port_range              = "all"
      destination_addresses   = ["0.0.0.0/0", "::/0"]
    },
    {
      protocol                = "udp"
      port_range              = "all"
      destination_addresses   = ["0.0.0.0/0", "::/0"]
    },
  ]
}

###############################################################################
#
# Make config file and export variables for kubectl
#
###############################################################################

resource "null_resource" "make_admin_key" {
    depends_on = ["digitalocean_droplet.k8s_worker"]
    provisioner "local-exec" {
        command = <<EOF
            ${path.module}/cfssl/generate_admin.sh
EOF
    }
}

resource "null_resource" "setup_kubectl" {
    depends_on = ["null_resource.make_admin_key"]
    provisioner "local-exec" {
        command = <<EOF
            echo export MASTER_HOST=${digitalocean_droplet.k8s_master.ipv4_address} > $PWD/secrets/setup_kubectl.sh
            echo export CA_CERT=$PWD/secrets/ca.pem >> $PWD/secrets/setup_kubectl.sh
            echo export ADMIN_KEY=$PWD/secrets/admin-key.pem >> $PWD/secrets/setup_kubectl.sh
            echo export ADMIN_CERT=$PWD/secrets/admin.pem >> $PWD/secrets/setup_kubectl.sh
            . $PWD/secrets/setup_kubectl.sh
            kubectl config set-cluster default-cluster \
                --server=https://$MASTER_HOST --certificate-authority=$CA_CERT
            kubectl config set-credentials default-admin \
                 --certificate-authority=$CA_CERT --client-key=$ADMIN_KEY --client-certificate=$ADMIN_CERT
            kubectl config set-context default-system --cluster=default-cluster --user=default-admin
            kubectl config use-context default-system
EOF
    }
}

resource "null_resource" "deploy_dns_addon" {
    depends_on = ["null_resource.setup_kubectl"]
    provisioner "local-exec" {
        command = <<EOF
            until kubectl get pods 2>/dev/null; do printf '.'; sleep 5; done
            kubectl create -f ${path.module}/03-dns-addon.yaml
EOF
    }
}

resource "null_resource" "deploy_microbot" {
    depends_on = ["null_resource.setup_kubectl"]
    provisioner "local-exec" {
        command = <<EOF
            sed -e "s/\$EXT_IP1/${digitalocean_droplet.k8s_worker.0.ipv4_address}/" < ${path.module}/04-microbot.yaml > ./secrets/04-microbot.rendered.yaml
            until kubectl get pods 2>/dev/null; do printf '.'; sleep 5; done
            kubectl create -f ./secrets/04-microbot.rendered.yaml

EOF
    }
}
