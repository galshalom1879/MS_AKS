#!/bin/bash

# variables
resourceGroupName="gs-reasources"
location="israelcentral"
aksClusterName="gs-cluster-1"
acrName="galshaacr"

# Set the subscription
# subscriptionID="paste here your subscription ID"
# az account set --subscription "$subscriptionID"

# Create a resource group
az group create --name $resourceGroupName --location $location
echo "Successfully created resource group"

# Create ACR and get access
az acr create --name $acrName --resource-group $resourceGroupName --location $location --sku Basic
az acr login --name $acrName
echo "ACR Created!"

# Build app images and loading to ACR registry
docker build -t galshaacr.azurecr.io/bitcoinapp:latest ./serivce-a-src
docker build -t galshaacr.azurecr.io/hello:latest ./serivce-b-src

docker push galshaacr.azurecr.io/bitcoinapp:latest
docker push galshaacr.azurecr.io/hello:latest

# cluster deployment
az deployment group create \
  --name AKSDeployment \
  --resource-group $resourceGroupName \
  --template-file template.json \
  --parameters parameters.json

# get access to cluster using Kubectl
az aks get-credentials --resource-group $resourceGroupName --name $aksClusterName
kubectl config use-context $aksClusterName
export KUBECONFIG=/mnt/c/Users/Rachel/.kube/config

# install ingress controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginxq
helm install my-nginx ingress-nginx/ingress-nginx \
    --namespace ingress-basic \
    --create-namespace \
    --set controller.replicaCount=2 \
    --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux
echo "Ingress installed"

# Assign owner role for cluster+agentpool within the scope of the ACR
clusterID=$(az aks show --resource-group "$resourceGroupName" --name $aksClusterName --query identity.principalId -o tsv)
agentpoolID=$(az aks show --resource-group "$resourceGroupName" --name $aksClusterName --query identityProfile.kubeletidentity.objectId -o tsv)
roleScope=$(az acr show --name $acrName --resource-group $resourceGroupName --query id --output tsv)

clusterID=$(echo "$clusterID" | tr -d '\r')
roleScope=$(echo "$roleScope" | tr -d '\r')

az role assignment create --assignee-object-id $clusterID --assignee-principal-type ServicePrincipal --role "Owner" --scope $roleScope
az role assignment create --assignee-object-id $agentpoolID --assignee-principal-type ServicePrincipal --role "Owner" --scope $roleScope

kubectl apply -f k8s/ingress.yaml -f k8s/NetworkPolicy.yaml -f k8s/service-a-deployment.yaml -f k8s/service-a-service.yaml -f k8s/service-b-deployment.yaml -f k8s/service-b-service.yaml 