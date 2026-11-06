#!/bin/bash

printf "Existing cluster roles at the start:\n %s\n\n" "$(kubectl get clusterroles | sort)"

for file in ./manifests/roles/*; do
  kubectl apply -f "$file"
done

printf "\nCluster roles at the end:\n %s" "$(kubectl get clusterroles | sort)"
