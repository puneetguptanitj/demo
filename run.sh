 #!/bin/bash -x

 DEMO_RUN_FAST=1
 . utils.sh

 clear

 SSH="ssh"
 export KUBECONFIG=./admin.conf

 public_ips=(`cat testbed.json| grep "\"private_ip\"" | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | tr '\n' ' '`)
 all_ips=(`cat testbed.json| grep "\"ip\"" | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | tr '\n' ' '`)

 MASTER0="$SSH root@${public_ips[0]}"
 CCTL_VERSION_BASELINE="v0.0.5"
 CCTL_VERSION_NEW="v0.0.6"
 VIP=${all_ips[5]}
 NODE_INDEX=2

 desc "[PRE-UPGRADE] Install both installers "
 desc "Contents of var cache for ssh-provider"
 run "$MASTER0 find /var/cache/ssh-provider"
 desc "Contents of var cache for nodeadm"
 run "$MASTER0 find /var/cache/nodeadm"
 desc "Contents of var cache for etcdadm"
 run "$MASTER0 find /var/cache/etcdadm"

 #desc "Tools how have version information"
 #run "$MASTER0 /var/cache/ssh-provider/nodeadm/${CCTL_VERSION_BASELINE}/nodeadm version --output json"
 #run "$MASTER0 /var/cache/ssh-provider/etcdadm/${CCTL_VERSION_BASELINE}/etcdadm version --output json"

 desc "[CREATE CLUSTER] Create cluster using ${CCTL_VERSION_BASELINE}"
 run "$MASTER0 /var/cache/cctl/${CCTL_VERSION_BASELINE}/cctl create cluster --vip $VIP --routerID 129"

 desc "[CREATE CLUSTER] Create credential"
 run "$MASTER0 /var/cache/cctl/${CCTL_VERSION_BASELINE}/cctl create credential --user root --privateKey ~/.ssh/id_rsa"

 desc "[CREATE CLUSTER] Create masters"
 run "$MASTER0 /var/cache/cctl/${CCTL_VERSION_BASELINE}/cctl create machine --ip ${public_ips[0]} --role master"
 run "$MASTER0 /var/cache/cctl/${CCTL_VERSION_BASELINE}/cctl create machine --ip ${public_ips[1]} --role master"
 run "$MASTER0 /var/cache/cctl/${CCTL_VERSION_BASELINE}/cctl create machine --ip ${public_ips[2]} --role master"

 desc "[CREATE CLUSTER] Create workers"
 run "$MASTER0 /var/cache/cctl/${CCTL_VERSION_BASELINE}/cctl create machine --ip ${public_ips[3]} --role node"
 run "$MASTER0 /var/cache/cctl/${CCTL_VERSION_BASELINE}/cctl create machine --ip ${public_ips[4]} --role node"

 scp root@${public_ips[0]}:/etc/kubernetes/admin.conf . > /dev/null

 desc "[CREATE CLUSTER] Get nodes"
 run "kubectl get nodes"

 kubectl label nodes ${public_ips[0]} testlabel- > /dev/null
 desc "[NODE LABEL] Add node label"
 run "kubectl label nodes ${public_ips[0]} testlabel=testvalue "

 desc "[NODE LABEL] Show node label"
 run "kubectl get node ${public_ips[0]} --show-labels"

 desc "[DEMO WORKLOAD] Add workload"
 run "kubectl run nginx --image=nginx:v1 --replicas=10"

 desc "[NODE NOTREADY] Stop kubelet on one master to make it NotReady"
 run "$MASTER0 systemctl stop kubelet"

 desc "[NODE NOTREADY] Get nodes"
 run "kubectl get nodes"

 desc "[DEMO PREFLIGH CHECK] Should fail"
 run "$MASTER0 /var/cache/cctl/${CCTL_VERSION_NEW}/cctl upgrade cluster "

 desc "[NODE READY] Restart kubelet on the master"
 run "$MASTER0 systemctl start kubelet"

 desc "[NODE READY] Get nodes"
 run "kubectl get nodes"

 desc "[UPGRADE] Upgrade the cluster"
 run "$MASTER0 /var/cache/cctl/${CCTL_VERSION_NEW}/cctl upgrade cluster "

 desc "[UPGRADE] Cluster has been upgraded"
 run "kubectl  get nodes"

 desc "[NODE LABEL] Node label is retained"
 run "kubectl get node ${public_ips[0]} --show-labels"

 desc "[WORKLOAD] Workload is retained"
 run "kubectl get pods"

 desc "[CLEANUP] Remove node label"
 run "kubectl label nodes ${public_ips[0]} testlabel-"

 desc "[CLEANUP] Cleanup workload"
 run "kubectl delete deployment nginx"

 desc "[CLEANUP] Rollback the cluster"
 run "$MASTER0 /var/cache/cctl/${CCTL_VERSION_BASELINE}/cctl upgrade cluster "

 #desc "Update using the same cli ${CCTL_VERSION_NEW} will be a no-op"
 #run "$MASTER0 /var/cache/cctl/${CCTL_VERSION_NEW}/cctl upgrade machine --ip ${public_ips[${NODE_INDEX}]} "

 #desc "Check cluster state file check for versions for ${public_ips[${NODE_INDEX}]}"
 #$MASTER0  cat /etc/cctl-state.yaml  |  yq ".machineList.items[]  | select (.metadata.name == \"${public_ips[${NODE_INDEX}]}\") | .spec.providerConfig"
 #read -s


 #desc "Update using the same cli v1.0.0upgradea will only update the state file"
 #run "$MASTER0 /var/cache/cctl/v1.0.0upgradea/cctl upgrade machine --ip ${public_ips[${NODE_INDEX}]} "

 #desc "Check cluster state file check for versions for ${public_ips[${NODE_INDEX}]}"
 #$MASTER0  cat /etc/cctl-state.yaml  |  yq ".machineList.items[]  | select (.metadata.name == \"${public_ips[${NODE_INDEX}]}\") | .spec.providerConfig"
 #read -s

 #desc "Update using the same cli v1.0.0upgradeb will delete and recreate the node with correct version"
 #run "$MASTER0 /var/cache/cctl/v1.0.0upgradeb/cctl upgrade machine --ip ${public_ips[${NODE_INDEX}]} "


