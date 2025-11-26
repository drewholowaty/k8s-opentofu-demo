# dev
dev-deploy: localhost-setup server-publish-image-dev
	kubectl apply -f server/dev-manifest.yml
dev-destroy: localhost-teardown

# sim-prod
sim-prod-deploy: localhost-prereqs server-publish-image-prod 
	kubectl apply -f server/prod-manifest.yml

# prod
prod-deploy: server-publish-image-prod infra-deploy-azure
# prod-stop: halts consuming resources such as webservers, microservices, etc
# prod-start: starts prod resources after stop
prod-destroy: infra-destroy-azure

# localhost
localhost-setup:
	cd infra/ansible/ && \
	uv sync --upgrade && \
	uv run ansible-playbook -K playbooks/localhost-setup.yml
localhost-teardown:
	cd infra/ansible/ && \
	uv run ansible-playbook playbooks/localhost-teardown.yml


# server
server-install:
	cd server && npm install
server-publish-image-dev: server-install
	cd server && \
	podman build -t "localhost:5000/drewserver-server-i:latest" . && \
	podman push --tls-verify=false "localhost:5000/drewserver-server-i:latest" 
server-publish-image: server-install
	cd server && \
	podman build -t "drewserver-server-i:latest" . && \
	podman tag "drewserver-server-i:latest" "drewholowaty/drewholowaty:drewserver-server-i" && \
	podman login --username "drewholowaty" && \
	podman push "drewholowaty/drewholowaty:drewserver-server-i"

# infra
infra-install-azure:
	cd infra/azure && tofu init -upgrade
infra-deploy-azure: infra-install-azure
	cd infra/azure && tofu apply 
infra-destroy-azure:
	cd infra/azure && \
	tofu destroy && \
	az ad sp delete --id $(tofu output -raw sp)
