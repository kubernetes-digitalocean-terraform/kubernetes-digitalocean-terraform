#!/usr/bin/bash
set -o nounset -o errexit

RELEASE="$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)"
CNI_VERSION="v0.6.0"

mkdir -p /opt/bin
cd /opt/bin
curl -L --remote-name-all https://storage.googleapis.com/kubernetes-release/release/${RELEASE}/bin/linux/amd64/{kubeadm,kubelet,kubectl}
chmod +x {kubeadm,kubelet,kubectl}

mkdir -p /opt/cni/bin
curl -L "https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-amd64-${CNI_VERSION}.tgz" | tar -C /opt/cni/bin -xz

BRANCH="release-$(cut -f1-2 -d .<<< "${RELEASE##v}")"
cd "/etc/systemd/system/"
curl -L "https://raw.githubusercontent.com/kubernetes/kubernetes/${BRANCH}/build/debs/kubelet.service" | sed 's:/usr/bin:/opt/bin:g' > kubelet.service
mkdir -p "/etc/systemd/system/kubelet.service.d"
cd "/etc/systemd/system/kubelet.service.d"
curl -L "https://raw.githubusercontent.com/kubernetes/kubernetes/${BRANCH}/build/debs/10-kubeadm.conf" | sed 's:/usr/bin:/opt/bin:g' > 10-kubeadm.conf