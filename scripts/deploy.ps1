# Stock Trading App Deployment Script (PowerShell)
# This script builds the Docker image and deploys the application to OpenShift

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("build", "push", "deploy-cf", "deploy-app", "deploy", "status", "cleanup")]
    [string]$Action,
    
    [string]$Region = "us-east-1",
    [string]$Environment = "dev"
)

# Configuration
$APP_NAME = "stock-trading-app"
$NAMESPACE = "stock-trading"

# Function to print colored output
function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Function to check if required tools are installed
function Test-Prerequisites {
    Write-Status "Checking prerequisites..."
    
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Error "Docker is required but not installed. Aborting."
        exit 1
    }
    
    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        Write-Error "AWS CLI is required but not installed. Aborting."
        exit 1
    }
    
    if (-not (Get-Command oc -ErrorAction SilentlyContinue)) {
        Write-Warning "OpenShift CLI (oc) not found. Some features may not work."
    }
    
    Write-Success "Prerequisites check completed"
}

# Function to build Docker image
function Build-DockerImage {
    Write-Status "Building Docker image..."
    
    docker build -t ${APP_NAME}:latest .
    docker build -t ${APP_NAME}:${Environment} .
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Docker image built successfully"
    } else {
        Write-Error "Docker build failed"
        exit 1
    }
}

# Function to push image to ECR
function Push-ToECR {
    Write-Status "Pushing image to ECR..."
    
    # Get ECR repository URI from CloudFormation
    try {
        $ECR_URI = aws cloudformation describe-stacks `
            --stack-name stock-trading-rosa-cluster `
            --query 'Stacks[0].Outputs[?OutputKey==`ECRRepositoryURI`].OutputValue' `
            --output text `
            --region $Region 2>$null
    } catch {
        $ECR_URI = ""
    }
    
    if ([string]::IsNullOrEmpty($ECR_URI)) {
        Write-Error "ECR repository URI not found. Make sure the ROSA cluster CloudFormation stack is deployed."
        exit 1
    }
    
    # Login to ECR
    $loginCmd = aws ecr get-login-password --region $Region
    $loginCmd | docker login --username AWS --password-stdin ($ECR_URI -split '/')[0]
    
    # Tag and push images
    docker tag ${APP_NAME}:latest ${ECR_URI}:latest
    docker tag ${APP_NAME}:${Environment} ${ECR_URI}:${Environment}
    
    docker push ${ECR_URI}:latest
    docker push ${ECR_URI}:${Environment}
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Image pushed to ECR: $ECR_URI"
        "ECR_URI=$ECR_URI" | Out-File -FilePath .env
    } else {
        Write-Error "ECR push failed"
        exit 1
    }
}

# Function to deploy CloudFormation stacks
function Deploy-CloudFormation {
    Write-Status "Deploying CloudFormation stacks..."
    
    # Get VPC and subnet information
    $VPC_ID = Read-Host "Enter VPC ID"
    $SUBNET_IDS = Read-Host "Enter subnet IDs (comma-separated)"
    
    # Deploy ROSA cluster stack
    Write-Status "Deploying ROSA cluster stack..."
    aws cloudformation deploy `
        --template-file cloudformation/rosa-cluster.yaml `
        --stack-name stock-trading-rosa-cluster `
        --parameter-overrides `
            ClusterName=stock-trading-cluster `
            Environment=$Environment `
            VpcId=$VPC_ID `
            SubnetIds=$SUBNET_IDS `
        --capabilities CAPABILITY_NAMED_IAM `
        --region $Region
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "ROSA cluster stack deployed"
        
        # Get cluster information
        $CLUSTER_NAME = aws cloudformation describe-stacks `
            --stack-name stock-trading-rosa-cluster `
            --query 'Stacks[0].Outputs[?OutputKey==`ClusterName`].OutputValue' `
            --output text `
            --region $Region
        
        Write-Status "Cluster name: $CLUSTER_NAME"
        
        # Show ROSA create command
        Write-Warning "Please run the ROSA create command from the CloudFormation output to create the actual cluster."
        
        aws cloudformation describe-stacks `
            --stack-name stock-trading-rosa-cluster `
            --query 'Stacks[0].Outputs[?OutputKey==`ROSACreateCommand`].OutputValue' `
            --output text `
            --region $Region
    } else {
        Write-Error "CloudFormation deployment failed"
        exit 1
    }
}

# Function to deploy application to OpenShift
function Deploy-ToOpenShift {
    Write-Status "Deploying application to OpenShift..."
    
    # Check if oc is available and logged in
    if (-not (Get-Command oc -ErrorAction SilentlyContinue)) {
        Write-Error "OpenShift CLI (oc) is required for deployment"
        exit 1
    }
    
    # Check if logged in
    try {
        oc whoami | Out-Null
    } catch {
        Write-Error "Please login to OpenShift using 'oc login'"
        exit 1
    }
    
    # Apply OpenShift manifests
    Write-Status "Applying OpenShift manifests..."
    
    oc apply -f openshift/namespace.yaml
    oc apply -f openshift/deployment.yaml
    oc apply -f openshift/service.yaml
    oc apply -f openshift/route.yaml
    
    # Wait for deployment to be ready
    Write-Status "Waiting for deployment to be ready..."
    oc rollout status deployment/stock-trading-app -n $NAMESPACE --timeout=300s
    
    # Get application URL
    try {
        $APP_URL = oc get route stock-trading-app-route -n $NAMESPACE -o jsonpath='{.spec.host}' 2>$null
    } catch {
        $APP_URL = ""
    }
    
    if (-not [string]::IsNullOrEmpty($APP_URL)) {
        Write-Success "Application deployed successfully!"
        Write-Success "Application URL: https://$APP_URL"
        Write-Success "WebSocket URL: wss://$APP_URL/ws"
    } else {
        Write-Warning "Deployment completed but could not retrieve application URL"
    }
}

# Function to show application status
function Show-Status {
    Write-Status "Application Status:"
    
    if ((Get-Command oc -ErrorAction SilentlyContinue) -and (oc whoami 2>$null)) {
        Write-Host ""
        Write-Status "Pods:"
        oc get pods -n $NAMESPACE -l app=stock-trading-app
        
        Write-Host ""
        Write-Status "Services:"
        oc get services -n $NAMESPACE
        
        Write-Host ""
        Write-Status "Routes:"
        oc get routes -n $NAMESPACE
        
        Write-Host ""
        Write-Status "Application URL:"
        try {
            $APP_URL = oc get route stock-trading-app-route -n $NAMESPACE -o jsonpath='{.spec.host}' 2>$null
            Write-Host "https://$APP_URL"
        } catch {
            Write-Host "Not available"
        }
    } else {
        Write-Warning "OpenShift CLI not available or not logged in"
    }
}

# Function to clean up resources
function Remove-Resources {
    Write-Warning "Cleaning up resources..."
    
    if ((Get-Command oc -ErrorAction SilentlyContinue) -and (oc whoami 2>$null)) {
        oc delete namespace $NAMESPACE --ignore-not-found=true
    }
    
    Write-Success "Cleanup completed"
}

# Main script logic
Test-Prerequisites

switch ($Action) {
    "build" {
        Build-DockerImage
    }
    "push" {
        Push-ToECR
    }
    "deploy-cf" {
        Deploy-CloudFormation
    }
    "deploy-app" {
        Deploy-ToOpenShift
    }
    "deploy" {
        Build-DockerImage
        Push-ToECR
        Deploy-ToOpenShift
    }
    "status" {
        Show-Status
    }
    "cleanup" {
        Remove-Resources
    }
}

Write-Host ""
Write-Host "Stock Trading App Deployment Script (PowerShell)"
Write-Host ""
Write-Host "Usage: .\scripts\deploy.ps1 -Action <action> [-Region <region>] [-Environment <env>]"
Write-Host ""
Write-Host "Actions:"
Write-Host "  build      - Build Docker image"
Write-Host "  push       - Push image to ECR"
Write-Host "  deploy-cf  - Deploy CloudFormation stacks"
Write-Host "  deploy-app - Deploy application to OpenShift"
Write-Host "  deploy     - Build, push, and deploy application"
Write-Host "  status     - Show application status"
Write-Host "  cleanup    - Clean up resources"
Write-Host ""
Write-Host "Parameters:"
Write-Host "  -Region      - AWS region (default: us-east-1)"
Write-Host "  -Environment - Environment name (default: dev)" 