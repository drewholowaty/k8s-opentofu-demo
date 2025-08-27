#!/bin/bash

####
# Assumptions:
# - Target OS is RHEL based
# - Bash interface
# - Container runtime is docker
# 
# Sources:
# - https://gist.github.com/trisberg/37c97b6cc53def9a3e38be6143786589
####


# Install software

# Configure Local Docker Registry
## Start local docker image registry
echo "CONFIGURE DOCKER REGISTRY"
if docker ps --filter "ancestor=registry:2" --filter "status=running" --quiet | grep -q .; then
    echo "Registry container is already running"
else
    echo "Registry container is not running. Starting it now..."
    docker run -d -p 5000:5000 --restart=always --volume ~/.registry/storage:/var/lib/registry registry:2
    
    if [ $? -eq 0 ]; then
        echo "Registry container started successfully"
    else
        echo "Failed to start registry container"
        exit 1
    fi
fi

## configure /etc/hosts
echo "CONFIGURE /etc/hosts"
if ! grep -q "registry.dev.svc.cluster.local" /etc/hosts; then
    echo "Adding registry.dev.svc.cluster.local to /etc/hosts..."
    sudo sed -i 's/127.0.0.1\s*localhost/127.0.0.1    localhost registry.dev.svc.cluster.local/' /etc/hosts
else
    echo "registry.dev.svc.cluster.local already exists in /etc/hosts"
fi

## Validate registry configuration
echo "VALIDATE REGISTRY CREATION"
registry_catalog=$(curl -s registry.dev.svc.cluster.local:5000/v2/_catalog)
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to connect to registry at registry.dev.svc.cluster.local:5000"
    exit 1
else
    echo "Registry Catalog:"
    echo $registry_catalog
fi

## Configure docker daemon with insecure registry
echo "CONFIGURE DOCKER DAEMON"
if [ ! -f /etc/docker/daemon.json ]; then
    echo "Creating /etc/docker/daemon.json..."
    sudo mkdir -p /etc/docker
    sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "insecure-registries": ["registry.dev.svc.cluster.local:5000"]
}
EOF
    
    echo "/etc/docker/daemon.json created successfully"
else
    echo "/etc/docker/daemon.json already exists"
    echo "Current contents:"
    cat /etc/docker/daemon.json
fi

# Start and Configure Minikube
## Start Minikube
echo "START MINIKUBE"
MINIKUBE_STATUS=$(minikube status --format="{{.Host}}" 2>/dev/null)

if [ "$MINIKUBE_STATUS" = "Running" ]; then
    echo "Minikube is already running"
else
    echo "Minikube is not running. Starting it now..."
    minikube start --cpus 4 --memory 4096 --insecure-registry registry.dev.svc.cluster.local:5000
    
    if [ $? -eq 0 ]; then
        echo "Minikube started successfully"
    else
        echo "Failed to start minikube"
        exit 1
    fi
fi

## Configure fixed ip address on local machine
echo "CONFIGURE FIXED IP ON LOCAL MACHINE"
DEV_IP=172.16.1.1
if ifconfig lo:0 2>/dev/null | grep -q "inet $DEV_IP"; then
    echo "Loopback alias lo:0 with IP $DEV_IP already exists"
else
    echo "Setting up loopback alias lo:0 with IP $DEV_IP..."
    sudo ifconfig lo:0 $DEV_IP
    
    if [ $? -eq 0 ]; then
        echo "Loopback alias created successfully"
    else
        echo "Failed to create loopback alias"
        exit 1
    fi
fi

## Congiure fixed ip address on minikube vm
echo "CONFIGURE FIXED IP ON MINIKUBE VM"
if minikube ssh "grep -q 'registry.dev.svc.cluster.local' /etc/hosts" 2>/dev/null; then
    echo "registry.dev.svc.cluster.local already exists in minikube VM's /etc/hosts"
    echo "Current entry:"
    minikube ssh "grep 'registry.dev.svc.cluster.local' /etc/hosts"
else
    echo "Adding registry.dev.svc.cluster.local to minikube VM's /etc/hosts..."
    minikube ssh "echo \"$DEV_IP       registry.dev.svc.cluster.local\" | sudo tee -a  /etc/hosts"
    
    if [ $? -eq 0 ]; then
        echo "Entry added successfully"
    else
        echo "Failed to add entry to minikube VM's /etc/hosts"
        exit 1
    fi
fi

## Configure k8s service endpoint for local docker image registry
echo "CONFIGURE K8S SERVICE ENDPOINT"
if ! kubectl get namespace dev >/dev/null 2>&1; then
    echo "Creating namespace 'dev'..."
    kubectl create namespace dev
else
    echo "Namespace 'dev' already exists"
fi

SERVICE_EXISTS=$(kubectl get service registry -n dev >/dev/null 2>&1 && echo "true" || echo "false")
ENDPOINT_EXISTS=$(kubectl get endpoints registry -n dev >/dev/null 2>&1 && echo "true" || echo "false")

if [ "$SERVICE_EXISTS" = "true" ] && [ "$ENDPOINT_EXISTS" = "true" ]; then
    echo "Registry service and endpoint already exist in dev namespace"
    echo "Current service:"
    kubectl get service registry -n dev
    echo "Current endpoint:"
    kubectl get endpoints registry -n dev -o wide
else
    echo "Creating registry service and endpoint in dev namespace..."
    
    cat <<EOF | kubectl apply -n dev -f -
---
kind: Service
apiVersion: v1
metadata:
  name: registry
spec:
  ports:
  - protocol: TCP
    port: 5000
    targetPort: 5000
---
kind: Endpoints
apiVersion: v1
metadata:
  name: registry
subsets:
  - addresses:
      - ip: $DEV_IP
    ports:
      - port: 5000
EOF

    if [ $? -eq 0 ]; then
        echo "Registry service and endpoint created successfully"
        echo "Registry should now be accessible at registry.dev.svc.cluster.local:5000"
    else
        echo "Failed to create registry service and endpoint"
        exit 1
    fi
fi
