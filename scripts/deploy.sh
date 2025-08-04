#!/bin/bash

# Stock Trading App Deployment Script
# This script builds the Docker image and deploys the application to OpenShift

set -e  # Exit on any error

# Configuration
APP_NAME="stock-trading-app"
NAMESPACE="stock-trading"
REGION=${AWS_REGION:-us-east-1}
ENVIRONMENT=${ENVIRONMENT:-dev}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if required tools are installed
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    command -v docker >/dev/null 2>&1 || { print_error "Docker is required but not installed. Aborting."; exit 1; }
    command -v aws >/dev/null 2>&1 || { print_error "AWS CLI is required but not installed. Aborting."; exit 1; }
    command -v oc >/dev/null 2>&1 || { print_warning "OpenShift CLI (oc) not found. Some features may not work."; }
    
    print_success "Prerequisites check completed"
}

# Function to build Docker image
build_docker_image() {
    print_status "Building Docker image..."
    
    docker build -t ${APP_NAME}:latest .
    docker build -t ${APP_NAME}:${ENVIRONMENT} .
    
    print_success "Docker image built successfully"
}

# Function to push image to ECR
push_to_ecr() {
    print_status "Pushing image to ECR..."
    
    # Get ECR repository URI from CloudFormation
    ECR_URI=$(aws cloudformation describe-stacks \
        --stack-name stock-trading-rosa-cluster \
        --query 'Stacks[0].Outputs[?OutputKey==`ECRRepositoryURI`].OutputValue' \
        --output text \
        --region ${REGION} 2>/dev/null || echo "")
    
    if [ -z "$ECR_URI" ]; then
        print_error "ECR repository URI not found. Make sure the ROSA cluster CloudFormation stack is deployed."
        exit 1
    fi
    
    # Login to ECR
    aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${ECR_URI%/*}
    
    # Tag and push images
    docker tag ${APP_NAME}:latest ${ECR_URI}:latest
    docker tag ${APP_NAME}:${ENVIRONMENT} ${ECR_URI}:${ENVIRONMENT}
    
    docker push ${ECR_URI}:latest
    docker push ${ECR_URI}:${ENVIRONMENT}
    
    print_success "Image pushed to ECR: ${ECR_URI}"
    echo "ECR_URI=${ECR_URI}" > .env
}

# Function to deploy CloudFormation stacks
deploy_cloudformation() {
    print_status "Deploying CloudFormation stacks..."
    
    # Check if VPC and subnets exist
    read -p "Enter VPC ID: " VPC_ID
    read -p "Enter subnet IDs (comma-separated): " SUBNET_IDS
    
    # Deploy ROSA cluster stack
    print_status "Deploying ROSA cluster stack..."
    aws cloudformation deploy \
        --template-file cloudformation/rosa-cluster.yaml \
        --stack-name stock-trading-rosa-cluster \
        --parameter-overrides \
            ClusterName=stock-trading-cluster \
            Environment=${ENVIRONMENT} \
            VpcId=${VPC_ID} \
            SubnetIds=${SUBNET_IDS} \
        --capabilities CAPABILITY_NAMED_IAM \
        --region ${REGION}
    
    print_success "ROSA cluster stack deployed"
    
    # Get cluster information
    CLUSTER_NAME=$(aws cloudformation describe-stacks \
        --stack-name stock-trading-rosa-cluster \
        --query 'Stacks[0].Outputs[?OutputKey==`ClusterName`].OutputValue' \
        --output text \
        --region ${REGION})
    
    print_status "Cluster name: ${CLUSTER_NAME}"
    
    # Create ROSA cluster (this is done outside CloudFormation)
    print_warning "Please run the ROSA create command from the CloudFormation output to create the actual cluster."
    
    aws cloudformation describe-stacks \
        --stack-name stock-trading-rosa-cluster \
        --query 'Stacks[0].Outputs[?OutputKey==`ROSACreateCommand`].OutputValue' \
        --output text \
        --region ${REGION}
}

# Function to deploy application to OpenShift
deploy_to_openshift() {
    print_status "Deploying application to OpenShift..."
    
    # Check if oc is available and logged in
    if ! command -v oc >/dev/null 2>&1; then
        print_error "OpenShift CLI (oc) is required for deployment"
        exit 1
    fi
    
    # Check if logged in
    if ! oc whoami >/dev/null 2>&1; then
        print_error "Please login to OpenShift using 'oc login'"
        exit 1
    fi
    
    # Apply OpenShift manifests
    print_status "Applying OpenShift manifests..."
    
    oc apply -f openshift/namespace.yaml
    oc apply -f openshift/deployment.yaml
    oc apply -f openshift/service.yaml
    oc apply -f openshift/route.yaml
    
    # Wait for deployment to be ready
    print_status "Waiting for deployment to be ready..."
    oc rollout status deployment/stock-trading-app -n ${NAMESPACE} --timeout=300s
    
    # Get application URL
    APP_URL=$(oc get route stock-trading-app-route -n ${NAMESPACE} -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
    
    if [ -n "$APP_URL" ]; then
        print_success "Application deployed successfully!"
        print_success "Application URL: https://${APP_URL}"
        print_success "WebSocket URL: wss://${APP_URL}/ws"
    else
        print_warning "Deployment completed but could not retrieve application URL"
    fi
}

# Function to show application status
show_status() {
    print_status "Application Status:"
    
    if command -v oc >/dev/null 2>&1 && oc whoami >/dev/null 2>&1; then
        echo
        print_status "Pods:"
        oc get pods -n ${NAMESPACE} -l app=stock-trading-app
        
        echo
        print_status "Services:"
        oc get services -n ${NAMESPACE}
        
        echo
        print_status "Routes:"
        oc get routes -n ${NAMESPACE}
        
        echo
        print_status "Application URL:"
        APP_URL=$(oc get route stock-trading-app-route -n ${NAMESPACE} -o jsonpath='{.spec.host}' 2>/dev/null || echo "Not available")
        echo "https://${APP_URL}"
    else
        print_warning "OpenShift CLI not available or not logged in"
    fi
}

# Function to clean up resources
cleanup() {
    print_warning "Cleaning up resources..."
    
    if command -v oc >/dev/null 2>&1 && oc whoami >/dev/null 2>&1; then
        oc delete namespace ${NAMESPACE} --ignore-not-found=true
    fi
    
    print_success "Cleanup completed"
}

# Main script logic
case "$1" in
    "build")
        check_prerequisites
        build_docker_image
        ;;
    "push")
        check_prerequisites
        push_to_ecr
        ;;
    "deploy-cf")
        check_prerequisites
        deploy_cloudformation
        ;;
    "deploy-app")
        check_prerequisites
        deploy_to_openshift
        ;;
    "deploy")
        check_prerequisites
        build_docker_image
        push_to_ecr
        deploy_to_openshift
        ;;
    "status")
        show_status
        ;;
    "cleanup")
        cleanup
        ;;
    *)
        echo "Stock Trading App Deployment Script"
        echo
        echo "Usage: $0 {build|push|deploy-cf|deploy-app|deploy|status|cleanup}"
        echo
        echo "Commands:"
        echo "  build      - Build Docker image"
        echo "  push       - Push image to ECR"
        echo "  deploy-cf  - Deploy CloudFormation stacks"
        echo "  deploy-app - Deploy application to OpenShift"
        echo "  deploy     - Build, push, and deploy application"
        echo "  status     - Show application status"
        echo "  cleanup    - Clean up resources"
        echo
        echo "Environment Variables:"
        echo "  AWS_REGION   - AWS region (default: us-east-1)"
        echo "  ENVIRONMENT  - Environment name (default: dev)"
        echo
        exit 1
        ;;
esac 