[all]
${connection_strings_master}
${connection_strings_worker}

[all:vars]
#supplementary_addresses_in_ssl_keys='["84.201.153.255","84.201.180.43","84.201.174.174"]'

[kube-master]
${list_masters}

[etcd]
${list_masters}

[kube-node]
${list_workers}

[k8s-cluster:children]
kube-master
kube-node
