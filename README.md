# Microservices Deployment Guide

This guide provides step-by-step instructions for deploying the microservices application in different environments.

## 📋 Deployment Options

1. **Local Development** - Using Docker Compose
2. **Cloud Development** - Using Terraform and AWS EKS
3. **Production** - Using EKS with ALB and Custom Domain

## 🐳 Local Development with Docker Compose

### System Requirements
- Docker Engine 20.10.0 or higher
- Docker Compose v2.0.0 or higher
- 4GB RAM minimum (8GB recommended)
- 10GB free disk space

### Available Compose Files
- `docker-compose.yml` - Full development setup
- `docker-compose.minimal.yml` - Minimal setup for testing
- `docker-compose-tests.yml` - Testing environment

### Quick Start
```bash
# Full development setup
docker compose up -d

# Minimal setup
docker compose -f docker-compose.minimal.yml up -d

# Run tests
docker compose -f docker-compose-tests.yml up
```

### Access Points
- Frontend: `http://localhost:8080`
- Grafana: `http://localhost:3000`
- OpenSearch: `http://localhost:5601`

### Management Commands
```bash
# Stop all services
docker compose down

# View logs
docker compose logs -f

# Rebuild services
docker compose build

# Check service status
docker compose ps
```

## 🏗️ Cloud Deployment with Terraform

### Prerequisites
- Terraform >= 1.0.0
- AWS CLI with configured credentials
- AWS Account with sufficient permissions
- Route53 Hosted Zone (for custom domain)

### Infrastructure Setup
1. **Configure AWS Credentials**
   ```bash
   aws configure
   ```

2. **Initialize Backend**
   ```bash
   # Create S3 bucket for state
   aws s3 mb s3://<YOUR_BUCKET_NAME>

   # Create DynamoDB table for locking
   aws dynamodb create-table \
     --table-name terraform-state-lock \
     --attribute-definitions AttributeName=LockID,AttributeType=S \
     --key-schema AttributeName=LockID,KeyType=HASH \
     --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5
   ```

3. **Configure Backend** (in `terraform/main.tf`)
   ```hcl
   terraform {
     backend "s3" {
       bucket         = "<YOUR_BUCKET_NAME>"
       key            = "terraform.tfstate"
       region         = "<YOUR_REGION>"
       dynamodb_table = "terraform-state-lock"
       encrypt        = true
     }
   }
   ```

### Deployment Commands
```bash
# Initialize Terraform
terraform init

# Plan the infrastructure changes
terraform plan

# Apply the changes
terraform apply -auto-approve

# To destroy the infrastructure
terraform destroy -auto-approve
```

## 🚀 Production Deployment on EKS

### Overview
This section covers deploying the application to AWS EKS with:
- Application Load Balancer (ALB) Ingress
- Custom domain with SSL/TLS
- Monitoring and logging setup

### System Prerequisites

Before you begin, ensure you have:
- AWS CLI configured with admin access  
- `kubectl` installed and configured  
- `eksctl` and `helm` installed  
- A running **EKS cluster**
- A **VPC ID** and **AWS account ID**
- A **registered domain name** (e.g., via GoDaddy)

---

## 🧩 Step 1: Configure kubectl for the EKS Cluster

```bash
aws eks update-kubeconfig --region <YOUR_REGION> --name <YOUR_CLUSTER_NAME>
````

This updates your local kubeconfig to interact with the `reon-eks-cluster`.

---

## 🧠 Step 2: Create and Verify Service Accounts

```bash
kubectl get sa
```

Check for existing service accounts. You can create new ones as needed for your deployments.

---

## 📦 Step 3: Apply Deployments and Services

Apply all your application manifests (Deployments, Services, ConfigMaps, etc.):

```bash
kubectl apply -f .yml
```

Then, update your frontend service (`frontendproxy`) to **LoadBalancer** type for initial access:

```bash
kubectl edit service frontendproxy
# Change `type: ClusterIP` to `type: LoadBalancer`
```

Once applied, you can access your app using the generated **FQDN** and **port**.

---

## ⚙️ Step 4: Install AWS ALB Ingress Controller

### 4.1 Setup OIDC Connector

```bash
export cluster_name=<YOUR_CLUSTER_NAME>

oidc_id=$(aws eks describe-cluster --name $cluster_name --query "cluster.identity.oidc.issuer" --output text | cut -d '/' -f 5)

eksctl utils associate-iam-oidc-provider --cluster $cluster_name --approve
```

This associates an **OIDC provider** with your EKS cluster, enabling service accounts to assume IAM roles.

---

### 4.2 Download IAM Policy for ALB Controller

```bash
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.11.0/docs/install/iam_policy.json
```

Create the IAM policy:

```bash
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json
```

---

### 4.3 Create IAM Role and Service Account

```bash
eksctl create iamserviceaccount \
  --cluster=<YOUR_CLUSTER_NAME> \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::091234170225:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve
```

---

### 4.4 Deploy the ALB Ingress Controller using Helm

Add the Helm repo and install the controller:

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update eks

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=<YOUR_CLUSTER_NAME> \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=<YOUR_REGION> \
  --set vpcId=<YOUR_VPC_ID>
```

Verify deployment:

```bash
kubectl get deployment -n kube-system aws-load-balancer-controller
```

---

## 🌐 Step 5: Configure Ingress and Load Balancer

Change your frontend service type to **NodePort**:

```bash
kubectl edit service frontendproxy
# Change `type: LoadBalancer` to `type: NodePort`
```

Then apply the ingress configuration:

```bash
kubectl apply -f ingress.yml
```

The ALB Ingress Controller will automatically provision an **Application Load Balancer (ALB)**.

---

## 🌍 Step 6: Configure Custom Domain with Route 53 & GoDaddy

1. **Create a Hosted Zone** in Route 53 using your domain (e.g., `yourdomain.com`).
2. Copy the **NS (Name Server)** records provided by Route 53.
3. Update your **GoDaddy domain settings** to use these NS records.
4. In Route 53, add an **A Record** pointing to your ALB’s DNS name.

---

## ✅ Step 7: Access Your Application

Once DNS propagation completes, your application will be available at:

```
http://www.reondev.top
```

---

## 🧰 Troubleshooting

* To check the ingress and ALB status:

  ```bash
  kubectl get ingress
  kubectl describe ingress <ingress-name>
  ```
* To verify ALB logs:

  ```bash
  kubectl logs -n kube-system deployment/aws-load-balancer-controller
  ```
* To get the ALB DNS name:

  ```bash
  kubectl get ingress -A
  ```

---

## 🏁 Summary

You’ve successfully:

* Configured an EKS cluster and deployed your app
* Installed and configured the AWS ALB Ingress Controller
* Integrated Route 53 DNS with GoDaddy
* Deployed your app to a public domain with HTTPS access

Your website is now live at:
**👉 [www.yourdomain.com](https://www.yourdomain.com)**

---

## 🔄 Setting up GitOps with ArgoCD

### Prerequisites
- Kubernetes cluster with kubectl access
- Admin access to the cluster

### ArgoCD Installation and Setup

1. **Create ArgoCD Namespace**
```bash
kubectl create namespace argocd
```

2. **Install ArgoCD**
```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

3. **Access ArgoCD UI**
```bash
# Get ArgoCD Services
kubectl get svc -n argocd

# Edit the argocd-server service to expose it
kubectl edit svc argocd-server -n argocd
# Change type: ClusterIP to type: LoadBalancer

# Verify the change
kubectl get svc -n argocd
```

4. **Get Admin Credentials**
```bash
# View the admin password secret
kubectl get secret -n argocd

# Access the initial admin password
kubectl edit secret argocd-initial-admin-secret -n argocd
# The password is base64 encoded in the 'password' field
```

### Next Steps
- Use the LoadBalancer IP/URL to access ArgoCD UI
- Login with username: admin and the decoded password
- Configure your Git repositories
- Set up your applications for GitOps deployment


