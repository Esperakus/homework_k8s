[k8s-nodes]
%{ for hostname in k8s-nodes ~}
${hostname}
%{ endfor ~}

[ansible-host]
localhost