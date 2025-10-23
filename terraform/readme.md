aws eks update-kubeconfig --region eu-north-1 --name reon-eks-cluster

create service account 
kubectl get sa

apply all other deployments and service
kubectl apply -f .yml

edit frontendproxy service change to loadbalancer
now you can access the appliction using fqdn and port

now we install alb ingress controller

Setup OIDC Connector

export cluster_name=reon-eks-cluster

oidc_id=$(aws eks describe-cluster --name $cluster_name --query "cluster.identity.oidc.issuer" --output text | cut -d '/' -f 5) 

eksctl utils associate-iam-oidc-provider --cluster $cluster_name --approve


Download IAM policy

curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.11.0/docs/install/iam_policy.json


Create IAM Policy

aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json


Create IAM Role

eksctl create iamserviceaccount \
  --cluster=reon-eks-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::091234170225:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve


Deploy ALB controller
Add helm repo

helm repo add eks https://aws.github.io/eks-charts


Update the repo

helm repo update eks


Install

helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --set clusterName=reon-eks-cluster --set serviceAccount.create=false --set serviceAccount.name=aws-load-balancer-controller --set region=eu-north-1 --set vpcId=vpc-073bf1949d41aea1b


Verify that the deployments are running.

kubectl get deployment -n kube-system aws-load-balancer-controller

change frontendproxy sevice type to NodePort

then apply ingress.yml


create a hosted zone in route53
add the ns values in godaddy
change A records to your loadbalancer

now you can access your website on www.reondev.top


