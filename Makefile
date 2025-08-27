# dev
dev-deploy: localhost-prereqs server-publish-image-dev
	kubectl apply -f server/dev-manifest.yml

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

# server
server-install:
	cd server && npm install
server-publish-image-dev: server-install
	cd server && \
	docker build -t "localhost:5000/drewserver-server-i:latest" . && \
	docker push "localhost:5000/drewserver-server-i:latest" 
server-publish-image: server-install
	cd server && \
	docker build -t "drewserver-server-i:latest" . && \
	docker tag "drewserver-server-i:latest" "drewholowaty/drewholowaty:drewserver-server-i" && \
	docker login --username "drewholowaty" && \
	docker push "drewholowaty/drewholowaty:drewserver-server-i"

# infra
infra-install-azure:
	cd infra/azure && tofu init -upgrade
infra-deploy-azure: infra-install-azure
	cd infra/azure && tofu apply 
infra-destroy-azure:
	cd infra/azure && \
	tofu destroy && \
	az ad sp delete --id $(tofu output -raw sp)
