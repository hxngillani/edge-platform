.PHONY: ping k8s-install generate flux status

ping:
	ansible all -m ping

k8s-install:
	ansible-playbook bootstrap/site.yml

generate:
	ansible-playbook bootstrap/render-blueprint.yml

flux:
	flux reconcile kustomization flux-system -n flux-system
status:
	export KUBECONFIG=/etc/rancher/rke2/rke2.yaml; kubectl get pods -A
