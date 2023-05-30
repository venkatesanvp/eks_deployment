#!/bin/bash

# Replace these values with your own
CLUSTER_NAME="cad-sh-eksdemo2"
AWS_REGION="us-east-1"
NODE_GROUP_NAME="cad-sh-eksdemo2-ng-public1"
NODE_GROUP_TYPE="t3.medium"
ZONES_LIST="us-east-1a,us-east-1b,us-east-1c"
NODE_GROUP_MIN_SIZE=2
NODE_GROUP_MAX_SIZE=4
NODE_GROUP_DESIRED_CAPACITY=2
KEY_PARI_NAME="cad-demo2"
 
# Install eksctl
install_eksctl () {
  curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
  sudo mv /tmp/eksctl /usr/local/bin
}

# Create EKS cluster
create_cluster () {
  eksctl create cluster \
    --name=$CLUSTER_NAME \
    --region=$AWS_REGION \
    --zones=$ZONES_LIST \
    --without-nodegroup

  eksctl get clusters 

  aws eks --region $AWS_REGION update-kubeconfig --name $CLUSTER_NAME
}
#Create Key pair 
create_key_pair(){

  aws ec2 create-key-pair --key-name $KEY_PARI_NAME --query 'KeyMaterial' --output text > $KEY_PARI_NAME.pem

}
# Create node group
create_node_group () {
  eksctl create nodegroup \
    --cluster=$CLUSTER_NAME \
    --region=$AWS_REGION \
    --name=$NODE_GROUP_NAME \
    --node-type=$NODE_GROUP_TYPE \
    --nodes=$NODE_GROUP_DESIRED_CAPACITY \
    --nodes-min=$NODE_GROUP_MIN_SIZE \
    --nodes-max=$NODE_GROUP_MAX_SIZE \
    --node-volume-size=20 \
    --ssh-access \
    --ssh-public-key=kube-demo \
    --managed \
    --asg-access \
    --external-dns-access \
    --full-ecr-access \
    --appmesh-access \
    --alb-ingress-access \
    --node-private-networking


  eksctl get nodegroup --cluster=$CLUSTER_NAME
}

# Associate IAM role with Kubernetes OIDC provider
associate_oidc_provider () {
  eksctl utils associate-iam-oidc-provider \
    --region $AWS_REGION \
    --cluster $CLUSTER_NAME \
    --approve


}
carete_eks_storage_class(){
  #Create IAM Policy
  aws iam create-policy \
    --policy-name Amazon_EBS_CSI_Driver \
    --policy-document file://Amazon_EBS_CSI_Driver.json

  # Get worker node IAM Role ARN
  ROLE_NAME=$(kubectl -n kube-system describe configmap aws-auth | grep rolearn | cut -d'/' -f2)
  echo "ROLE NAME: $ROLE_NAME"

  aws iam attach-role-policy \
  --policy-arn Amazon_EBS_CSI_Driver \
  --role-name $ROLE_NAME 

  # Deploy EBS CSI Driver
  kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=master"

  # Verify ebs-csi pods running
  kubectl get pods -n kube-system

  kubectl apply -f kube-manifests-sc/

}

create_alb_sa(){
  eksctl create iamserviceaccount \
    --cluster $CLUSTER_NAME \
    --region $AWS_REGION \
    --namespace kube-system \
    --name aws-load-balancer-controller \
    --attach-policy-arn "arn:aws:iam::aws:policy/AWSLoadBalancerControllerIAMPolicy" \
    --override-existing-serviceaccounts \
    --approve
}
install_aws_load_balancer_controller(){
  # Download IAM Policy
  ## Download latest
  curl -o iam_policy_latest.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
  ## Verify latest
  ls -lrta 

  # Create IAM Policy using policy downloaded 
  aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy_latest.json
  
  PolicyARN="arn:aws:iam::749755283560:policy/AWSLoadBalancerControllerIAMPolicy"

  # cluster and policy arn (Policy arn we took note in step-02)
  eksctl create iamserviceaccount \
    --cluster=$CLUSTER_NAME \
    --namespace=kube-system \
    --name=aws-load-balancer-controller \
    --attach-policy-arn=$PolicyName \
    --override-existing-serviceaccounts \
    --approve

  # Get IAM Service Account
  eksctl  get iamserviceaccount --cluster eksdemo1

  #Install the AWS Load Balancer Controller using Helm V3
  # Add the eks-charts repository.
  helm repo add eks https://aws.github.io/eks-charts

  # Update your local repo to make sure that you have the most recent charts.
  helm repo update

  AWS_VPC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME | jq -r '.cluster.resourcesVpcConfig.vpcId')
  echo "AWS VPC ID: $AWS_VPC_ID"

  ## Replace Cluster Name, Region Code, VPC ID, Image Repo Account ID and Region Code  
  helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName=$CLUSTER_NAME \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller \
    --set region=$AWS_REGION \
    --set vpcId=$AWS_VPC_ID \
    --set image.repository=602401143452.dkr.ecr.us-east-1.amazonaws.com/amazon/aws-load-balancer-controller

  # Verify that the controller is installed.
  kubectl -n kube-system get deployment 
  kubectl -n kube-system get deployment aws-load-balancer-controller
  kubectl -n kube-system describe deployment aws-load-balancer-controller

  #Create IngressClass Resource
  # Create IngressClass Resource
  kubectl apply -f kube-manifests-ic/

  # Verify IngressClass Resource
  kubectl get ingressclass
}

# Test kubectl
test_kubectl () {
  kubectl get nodes
  kubectl get pods -n kube-system
}

# Execute functions
#install_eksctl
create_cluster
create_key_pair
create_node_group
associate_oidc_provider
carete_eks_storage_class
install_aws_load_balancer_controller
test_kubectl
