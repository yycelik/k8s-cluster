# set hostname 
sudo hostnamectl set-hostname "kmaster.com"

# update server
sudo apt update

sudo apt -y full-upgrade

[ -f /var/run/reboot-required ] && sudo reboot -f

# add dns for all nodes
sudo cat >>/etc/hosts<<EOF
192.168.0.240 kmaster kmaster.com
192.168.0.241 kworker1 kworker1.com
192.168.0.242 kworker2 kworker2.com
EOF

# disable swap
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
sudo sed -i '/swap/d' /etc/fstab

# enable kernel modules
sudo tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# add some settings to sysctl
sudo tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

# reload sysctl
sudo sysctl --system

# install containerd
sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates

# enable docker repository
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/docker.gpg
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# before install containerd
sudo apt update

# install containerd
sudo apt install -y containerd.io

# configure containerd so that it starts using systemd as cgroup.
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

# restart containerd service
sudo systemctl restart containerd

# enable containerd service
sudo systemctl enable containerd

# add apt repository
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# before install kubelet kubeadm and kubectl
sudo apt update

# install kubelet kubeadm and kubectl
sudo apt install -y kubelet kubeadm kubectl

# get current statu and version
#kubectl -n kube-system get cm kubeadm-config -o yaml

# list version
#apt list -a kubeadm

# install spespfic version
#sudo apt-get install -y kubeadm=1.30.5-1.1 --allow-downgrades

# get upgrade plan
#kubeadm upgrade plan

# hold kubelet kubeadm and kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# initialize Kubernetes cluster
sudo kubeadm init --control-plane-endpoint=kmaster.com --pod-network-cidr=92.68.0.0/16

# start interacting with cluster
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# get cluster status
kubectl cluster-info

# create token for cluster node(s)
kubeadm token list
sudo kubeadm token delete {id from list}
kubeadm token create --print-join-command

# install Calico Pod Network Add-on 
#wget https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml
#sed -i 's/#   value/  value/g' calico.yaml
#sed -i 's/# - name: CALICO_IPV4POOL_CIDR/- name: CALICO_IPV4POOL_CIDR/g' calico.yaml
#sed -i 's/192.168.0.0/92.68.0.0/g' calico.yaml
#kubectl apply -f calico.yaml

# install flannel Pod Network Add-on
helm repo add flannel https://flannel-io.github.io/flannel/
kubectl create namespace kube-flannel
helm install flannel --set podCidr="92.68.0.0/16" --namespace kube-flannel flannel/flannel

# confirm that all of the pods are running
watch kubectl get pods --all-namespaces -o wide

# confirm master node is ready
watch kubectl get nodes -o wide

# config or Jenkins Secret that will use on jenkins kubernates plugin configuration"
kubectl config view --flatten=true

#
kubectl get serviceaccount --all-namespaces