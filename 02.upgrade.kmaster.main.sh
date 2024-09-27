sudo add-apt-repository --remove "deb http://apt.kubernetes.io/ kubernetes-xenial main"

sudo apt update

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

sudo apt update

sudo apt upgrade kubeadm kubectl kubelet

sudo systemctl daemon-reload

sudo systemctl restart kubelet



kubectl -n kube-system get cm kubeadm-config -o yaml

apt list -a kubeadm

sudo apt-get install -y kubeadm=1.30.5-1.1

kubeadm upgrade plan