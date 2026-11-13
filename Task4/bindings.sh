#!/bin/bash

printf "Existing cluster role bindings at the start:\n %s\n\n" "$(kubectl get clusterrolebindings | sort)"

for file in ./manifests/bindings/*; do
  kubectl apply -f "$file"
done

printf "\nCluster role bindings at the end:\n %s" "$(kubectl get clusterrolebindings | sort)"
