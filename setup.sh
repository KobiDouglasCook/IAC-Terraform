#!/bin/bash
set -e
set -o pipefail

echo ">>> Running pre-flight checks..."

# Check for required commands
command -v terraform >/dev/null 2>&1 || { echo >&2 "Terraform is required but not installed. Aborting."; exit 1; }

command -v aws >/dev/null 2>&1 || { echo >&2 "AWS CLI is required but not installed. Aborting."; exit 1; }

command -v kubectl >/dev/null 2>&1 || { echo >&2 "kubectl is required but not installed. Aborting."; exit 1; }

# Check AWS credentials
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "AWS credentials are not configured or are expired. Aborting."
    exit 1
fi

echo "Pre-flight checks passed."

# Step 1: Bootstrap
echo ">>> Bootstrapping Terraform backend..."
cd bootstrap
terraform init -input=false
terraform apply -auto-approve
cd ..

# Step 2: Init infrastructure
echo ">>> Initializing Terraform in infrastructure..."
cd infrastructure
terraform init -input=false

# Step 3: Apply EKS module
echo ">>> Applying EKS module..."
terraform apply -auto-approve -target=module.eks

# Step 4: Update kubeconfig
echo ">>> Updating kubeconfig for EKS cluster..."
aws eks update-kubeconfig --region us-east-1 --name fuego-eks


# Step 5: Apply Kubernetes manifests
echo ">>> Applying Kubernetes manifests..."
kubectl apply -f ../k8s/

echo ">>> Waiting for Load Balancer hostname to become available..."

LB_DNS=""
for i in {1..20}; do
    LB_DNS=$(kubectl get svc \
        -n default \
        -o jsonpath="{.items[?(@.metadata.name=='my-nginx-service')].status.loadBalancer.ingress[0].hostname}")
    
    if [[ -n "$LB_DNS" ]]; then
        echo "Load Balancer DNS found: $LB_DNS"
        break
    fi

    echo "Still waiting... Attempt $i"
    sleep 20
done

if [[ -z "$LB_DNS" ]]; then
    echo "Timed out waiting for Load Balancer. Aborting."
    exit 1
fi

# Step 6: Get Load Balancer DNS and Zone ID
echo ">>> Extracting Load Balancer DNS and Zone ID..."

LB_DNS_PREFIX=$(echo "$LB_DNS" | cut -d'.' -f1)

# query for class elbs
LB_NAME=$(aws elb describe-load-balancers --region us-east-1 \
  --query "LoadBalancerDescriptions[?contains(DNSName, '$LB_DNS_PREFIX')].LoadBalancerName" \
  --output text)

LB_ZONE_ID=$(aws elb describe-load-balancers --region us-east-1 \
  --query "LoadBalancerDescriptions[?contains(DNSName, '$LB_DNS_PREFIX')].CanonicalHostedZoneNameID" \
  --output text)

if [[ -z "$LB_NAME" || -z "$LB_ZONE_ID" ]]; then
  echo "Could not find Classic Load Balancer by DNS prefix: $LB_DNS_PREFIX. Aborting."
  exit 1
fi

echo "Load Balancer DNS: $LB_DNS"
echo "Load Balancer Name: $LB_NAME"
echo "Load Balancer Zone ID: $LB_ZONE_ID"


# Step 7: Inject variables into DNS module (via tfvars)
echo ">>> Writing dns_override.auto.tfvars..."
rm -f dns_override.auto.tfvars

cat <<EOF > dns_override.auto.tfvars
alb_dns_name = "${LB_DNS}"
alb_zone_id  = "${LB_ZONE_ID}"
EOF

echo ">>> dns_override.auto.tfvars created."

# Step 8: Apply DNS module
echo ">>> Applying DNS module..."
terraform apply -auto-approve -target=module.dns

# Step 8.5: Clean up existing k8 resources (if any)
echo ">>> Cleaning up existing Kubernetes resources to avoid duplicate creation..."

kubectl delete deployment my-nginx-app -n default --ignore-not-found --grace-period=0 --force
kubectl delete service my-nginx-service -n default --ignore-not-found --grace-period=0 --force

# give Kubernetes a moment to fully process the deletion
sleep 5

# Step 9: Apply remaining resources
echo ">>> Applying all remaining Terraform resources..."
terraform apply -auto-approve

echo "Terraform setup complete!"