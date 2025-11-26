# drewserver

## development
### Required Software
- [uv](https://docs.astral.sh/uv/reference/installer/)
- Podman
- Minikube
- Kubectl
- Nodejs
- Azure CLI
    - `curl -L https://aka.ms/InstallAzureCli | bash`

### Useful Commands
#### Locally Run Application
- `make dev-deploy`
- `kubectl get services | awk '/LoadBalancer/{ print $1}' | xargs minikube service`

#### Other
- `podman exec -it <container-name> /bin/bash`


## Appendix

