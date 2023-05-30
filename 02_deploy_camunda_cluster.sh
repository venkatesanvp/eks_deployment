#!/bin/bash

# Set the desired release name and namespace
RELEASE_NAME="camunda-platform"
NAMESPACE="camunda"

# Set the path to the custom values.yaml file
VALUES_FILE="/values/minimal_values.yaml"

# Add the Camunda Helm repository
helm repo add camunda https://helm.camunda.io

# Update the Helm repositories
helm repo update

# Create the namespace if it doesn't exist
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Deploy Camunda Platform using Helm
helm upgrade --install $RELEASE_NAME camunda/camunda-platform -n $NAMESPACE --values $VALUES_FILE

# Wait for the deployment to be ready
kubectl rollout status deployment.apps/$RELEASE_NAME-camunda-platform-webapp -n $NAMESPACE

# Print the service URL
echo "Camunda Platform is deployed and accessible at:"
echo "http://$(kubectl get ingress -n $NAMESPACE -o jsonpath='{.items[0].spec.rules[0].host}')"

# Print the Operate URL
echo "Camunda Operate is deployed and accessible at:"
echo "http://$(kubectl get ingress -n $NAMESPACE -o jsonpath='{.items[0].spec.rules[1].host}')"

#Make sure to replace /path/to/values.yaml in the script with the actual path to your customized values.yaml file.

#This script performs the following steps:

#1. Adds the Camunda Helm repository.
#2. Updates the Helm repositories.
#3. Creates the namespace if it doesn't exist.
#4. Deploys Camunda Platform using the Helm chart, specifying the release name, namespace, and custom values file.
#5. Waits for the deployment to be ready.
#6. Prints the URL to access Camunda Platform.
#7. Prints the URL to access Camunda Operate.
#Save the script to a file, make it executable (chmod +x script.sh), and execute it to deploy Camunda Platform.