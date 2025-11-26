#!/bin/bash

####
# Assumptions:
# - Target OS is RHEL based
# - Bash interface
# - Container runtime is podman
# 
# Sources:
# - https://gist.github.com/trisberg/37c97b6cc53def9a3e38be6143786589
####


# Install software

# Configure Local Docker Registry
## Start local podman image registry
echo "CONFIGURE CONTAINER REGISTRY"
if podman ps --filter "ancestor=registry:2" --filter "status=running" --quiet | grep -q .; then
    echo "Registry container is already running"
else
    echo "Registry container is not running. Starting it now..."
    podman run -d -p 5000:5000 --name "$HOSTNAME-registry-c" --restart=always registry:2
    
    if [ $? -eq 0 ]; then
        echo "Registry container started successfully"
    else
        echo "Failed to start registry container"
        exit 1
    fi
fi

## Validate registry configuration
echo "VALIDATE REGISTRY CREATION"
registry_catalog=$(curl -s 0.0.0.0:5000/v2/_catalog)
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to connect to registry at 0.0.0.0:5000"
    exit 1
else
    echo "Registry Catalog:"
    echo $registry_catalog
fi

# Start and Configure Minikube
## Start Minikube
echo "START MINIKUBE"
MINIKUBE_STATUS=$(minikube status --format="{{.Host}}" 2>/dev/null)

minikube config set rootless true

if [ "$MINIKUBE_STATUS" = "Running" ]; then
    echo "Minikube is already running"
else
    echo "Minikube is not running. Starting it now..."
    minikube start --insecure-registry "host.minikube.internal:5000" --container-runtime=containerd --driver podman --cpus 4 --memory 4096 
    
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

