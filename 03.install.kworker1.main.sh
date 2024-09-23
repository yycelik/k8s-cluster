# set hostname 
sudo hostnamectl set-hostname "kworker1.com"

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

# enable kernel modulesMountVolume.SetUp failed for volume "memberlist"
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

# hold kubelet kubeadm and kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# get it from master instalation
#kubeadm join {dns}:{port} --token {token} --discovery-token-ca-cert-hash sha256:{key}
#kubeadm join kmaster.com:6443 --token hnkapw.ajb59nyh6doll5mu --discovery-token-ca-cert-hash sha256:9429117f4d70e2c4eba1349716bbc454fc2021befe1a9f3a721352d74cf50ab0
