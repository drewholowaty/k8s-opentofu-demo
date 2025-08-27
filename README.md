# drewserver

## development
- `make dev-deploy`
- `kubectl get services | awk '/LoadBalancer/{ print $1}' | xargs minikube service`

### Required Software
- Docker
- Minikube
- Kubectl
- Nodejs
- Azure CLI
    - `curl -L https://aka.ms/InstallAzureCli | bash`
