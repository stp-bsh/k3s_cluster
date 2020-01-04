#!/bin/bash -x
NAME=$1

cd /vagrant

# Remove all \r in files created by Windows.
sed -i 's/\r//g' tmp/*

source "tmp/$NAME"
hosts_file="tmp/hosts"

# Install and configure etcd on first master if K3S_DATASTORE_ENDPOINT is not set.
if [[ "$NAME" =~ "master01" && -z "$K3S_DATASTORE_ENDPOINT" ]]; then
  apt update && apt install -y etcd
  etcd_file=/etc/default/etcd
  [ -f $etcd_file ] && mv $etcd_file "${etcd_file}.`date +'%Y%m%d'`"
  (
  echo ETCD_ADVERTISE_CLIENT_URLS=\"http://${K3S_NODE_IP}:2379\"
  echo ETCD_LISTEN_CLIENT_URLS=\"http://${K3S_NODE_IP}:2379,http://127.0.0.1:2379\"
  echo ETCD_INITIAL_CLUSTER_TOKEN=\"k3s-cluster\"
  ) > $etcd_file
  systemctl enable etcd
  systemctl restart etcd
fi

# Adding entries in hosts file into /etc/hosts
etc_hosts=/etc/hosts
while IFS= read -r line
do
  grep -q "$line" $etc_hosts
  if [ $? -eq 1 ]; then
    echo Adding $line into $etc_hosts
    echo $line >> $etc_hosts
  fi
done < $hosts_file

# Download k3s.
wget --quiet "https://github.com/rancher/k3s/releases/download/v$K3S_VERSION/k3s" -O /usr/local/bin/k3s && chmod +x /usr/local/bin/k3s

# Use K3S_DATASTORE_ENDPOINT if set, otherwise use etcd.local as datastore endpoint
if [ "$K3S_DATASTORE_ENDPOINT" ]; then
  datastore_endpoint=$K3S_DATASTORE_ENDPOINT
else
  datastore_endpoint="http://etcd.local:2379"
fi

# Use K3S_CLUSTER_NAME if set, otherwise use k3s.local as cluster name
if [ "$K3S_CLUSTER_NAME" ]; then
  cluster_name=$K3S_CLUSTER_NAME
else
  cluster_name="k3s.local"
fi

# Create /etc/default/k3s service environment file
(
echo K3S_NODE_IP=$K3S_NODE_IP
echo K3S_TOKEN=$K3S_TOKEN
echo K3S_TLS_SAN=$cluster_name
echo K3S_DATASTORE_ENDPOINT=$datastore_endpoint
echo K3S_URL="https://${cluster_name}:6443"
) > /etc/default/k3s

# Create k3s.service
if [ "$K3S_NODE_TYPE" == "master" ]; then
  start_command="\/usr\/local\/bin\/k3s server --node-ip \$K3S_NODE_IP --tls-san \$K3S_TLS_SAN $K3S_PARAMS"
else
  start_command="\/usr\/local\/bin\/k3s agent --node-ip \$K3S_NODE_IP $K3S_PARAMS"
fi
echo $start_command
sed "s/ExecStart.*/ExecStart=$start_command/g" `pwd`/k3s.service > /lib/systemd/system/k3s.service
systemctl enable k3s
systemctl restart k3s

# Copy k3s.yaml to host
if [ "$K3S_NODE_TYPE" == "master" ]; then
  k3s_config=/etc/rancher/k3s/k3s.yaml
  [ -f $k3s_config ] && sed "s/127.0.0.1/$cluster_name/g" $k3s_config > /vagrant/k3s.yaml
fi

