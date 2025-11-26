# dev
dev-deploy: localhost-prereqs server-publish-image-dev
	kubectl apply -f server/dev-manifest.yml
dev-destroy: localhost-destroy
	kubectl delete -f server/dev-manifest.yml; \

# sim-prod
sim-prod-deploy: localhost-prereqs server-publish-image 
	kubectl apply -f server/prod-manifest.yml

# prod
prod-deploy: server-publish-image infra-deploy-azure
# prod-stop: halts consuming resources such as webservers, microservices, etc
# prod-start: starts prod resources after stop
prod-destroy: infra-destroy-azure

# localhost
localhost-prereqs:
	./scripts/localhost-prereqs.sh
localhost-destroy:
	minikube delete; \
	podman stop "${HOSTNAME}-registry-c" | xargs podman rm

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
