.PHONY: ping bootstrap status

ping:
	ansible all -m ping

bootstrap:
	ansible-playbook bootstrap/site.yml

status:
	ansible all -m command -a "uname -a"
