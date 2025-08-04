# Stock Trading App - Real-time Stock Price Tracking

A modern Java Spring Boot application that provides real-time stock price tracking with WebSocket support, designed for deployment on OpenShift clusters using CloudFormation.

## 🚀 Features

- **Real-time Stock Prices**: Live updating stock prices with WebSocket connectivity
- **Interactive Dashboard**: Modern web interface with real-time updates
- **Market Analytics**: Top gainers and losers tracking
- **Scalable Architecture**: Microservices-ready with Spring Boot
- **Cloud-Native**: Containerized and Kubernetes/OpenShift ready
- **Production Ready**: Health checks, monitoring, and observability

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │   Spring Boot   │    │   H2 Database   │
│   (HTML/JS)     │◄──►│   Application   │◄──►│   (In-Memory)   │
│                 │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         ▲                       ▲
         │                       │
         ▼                       ▼
┌─────────────────┐    ┌─────────────────┐
│   WebSocket     │    │   REST API      │
│   (Real-time)   │    │   (/api/*)      │
└─────────────────┘    └─────────────────┘
```

## 📋 Prerequisites

### Development
- Java 17+
- Maven 3.6+
- Docker
- Git

### Deployment
- AWS CLI configured
- OpenShift CLI (`oc`) installed
- Docker
- Access to AWS account with appropriate permissions
- Red Hat OpenShift cluster or ROSA setup

## 🛠️ Local Development

### 1. Clone and Build
```bash
git clone <repository-url>
cd stock-trading-app
mvn clean compile
```

### 2. Run Locally
```bash
mvn spring-boot:run
```

### 3. Access Application
- Application: http://localhost:8080
- H2 Console: http://localhost:8080/h2-console
- API Info: http://localhost:8080/api/info

### 4. Build Docker Image
```bash
docker build -t stock-trading-app:latest .
```

## 🚀 Deployment to OpenShift

### Option 1: Automated Deployment

Make the deployment script executable and run:
```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh deploy
```

### Option 2: Manual Deployment

#### Step 1: Deploy AWS Infrastructure
```bash
# Deploy ROSA cluster CloudFormation stack
aws cloudformation deploy \
  --template-file cloudformation/rosa-cluster.yaml \
  --stack-name stock-trading-rosa-cluster \
  --parameter-overrides \
    ClusterName=stock-trading-cluster \
    Environment=dev \
    VpcId=vpc-xxxxxxxx \
    SubnetIds=subnet-xxxxxxxx,subnet-yyyyyyyy \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

#### Step 2: Create ROSA Cluster
Get the ROSA create command from CloudFormation output and run it:
```bash
aws cloudformation describe-stacks \
  --stack-name stock-trading-rosa-cluster \
  --query 'Stacks[0].Outputs[?OutputKey==`ROSACreateCommand`].OutputValue' \
  --output text
```

#### Step 3: Build and Push Container Image
```bash
# Get ECR repository URI
ECR_URI=$(aws cloudformation describe-stacks \
  --stack-name stock-trading-rosa-cluster \
  --query 'Stacks[0].Outputs[?OutputKey==`ECRRepositoryURI`].OutputValue' \
  --output text)

# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin ${ECR_URI%/*}

# Build and push
docker build -t stock-trading-app:latest .
docker tag stock-trading-app:latest ${ECR_URI}:latest
docker push ${ECR_URI}:latest
```

#### Step 4: Deploy to OpenShift
```bash
# Login to OpenShift
oc login --token=<your-token> --server=<your-server-url>

# Update deployment image
sed -i "s|stock-trading-app:latest|${ECR_URI}:latest|g" openshift/deployment.yaml

# Deploy application
oc apply -f openshift/namespace.yaml
oc apply -f openshift/deployment.yaml
oc apply -f openshift/service.yaml
oc apply -f openshift/route.yaml

# Check deployment status
oc rollout status deployment/stock-trading-app -n stock-trading
```

## 📁 Project Structure

```
stock-trading-app/
├── main/
│   ├── java/com/cognizant/vibecoding/stocktrading/
│   │   ├── StockTradingApplication.java      # Main application class
│   │   ├── model/Stock.java                  # Stock entity
│   │   ├── dto/StockPriceDto.java           # Data transfer object
│   │   ├── repository/StockRepository.java   # Data access layer
│   │   ├── service/
│   │   │   ├── StockService.java            # Business logic
│   │   │   └── StockPriceSimulationService.java # Price simulation
│   │   ├── controller/
│   │   │   ├── StockController.java         # REST API endpoints
│   │   │   └── HomeController.java          # Frontend controller
│   │   └── config/WebSocketConfig.java      # WebSocket configuration
│   └── resources/
│       ├── application.properties           # Application configuration
│       └── static/index.html               # Frontend application
├── openshift/                              # OpenShift deployment manifests
│   ├── namespace.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   └── route.yaml
├── cloudformation/                         # CloudFormation templates
│   ├── rosa-cluster.yaml                  # ROSA cluster infrastructure
│   └── app-deployment.yaml               # Application deployment
├── scripts/
│   └── deploy.sh                          # Deployment automation script
├── Dockerfile                             # Container definition
├── pom.xml                               # Maven configuration
└── README.md                             # This file
```

## 🔗 API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Frontend application |
| `/api/info` | GET | Application information |
| `/api/stocks` | GET | Get all stocks |
| `/api/stocks/{symbol}` | GET | Get specific stock |
| `/api/stocks/gainers` | GET | Get top gainers |
| `/api/stocks/losers` | GET | Get top losers |
| `/ws` | WebSocket | Real-time updates |

## 🔧 Configuration

### Environment Variables
| Variable | Description | Default |
|----------|-------------|---------|
| `SPRING_PROFILES_ACTIVE` | Active Spring profile | `default` |
| `SERVER_PORT` | Application port | `8080` |
| `JAVA_OPTS` | JVM options | `-Xmx512m -Xms256m` |

### OpenShift Configuration
The application includes OpenShift-specific configuration in `openshift/namespace.yaml` with a ConfigMap for environment-specific settings.

## 📊 Monitoring and Health Checks

### Health Check Endpoints
- Liveness: `/api/info`
- Readiness: `/api/info`

### Logging
Application logs are configured for OpenShift with structured JSON output for better observability.

## 🔄 CI/CD Integration

The deployment script supports various CI/CD workflows:

```bash
# For CI/CD pipelines
./scripts/deploy.sh build     # Build only
./scripts/deploy.sh push      # Push to registry
./scripts/deploy.sh deploy-app # Deploy to existing cluster
./scripts/deploy.sh status    # Check deployment status
```

## 🐛 Troubleshooting

### Common Issues

1. **Docker Build Fails**
   ```bash
   # Ensure Docker daemon is running
   docker version
   ```

2. **ECR Push Permission Denied**
   ```bash
   # Check AWS credentials
   aws sts get-caller-identity
   ```

3. **OpenShift Login Issues**
   ```bash
   # Verify cluster connection
   oc cluster-info
   ```

4. **Application Not Starting**
   ```bash
   # Check pod logs
   oc logs -f deployment/stock-trading-app -n stock-trading
   ```

### Debugging Commands

```bash
# Check deployment status
./scripts/deploy.sh status

# View pod logs
oc logs -f deployment/stock-trading-app -n stock-trading

# Access pod shell
oc exec -it deployment/stock-trading-app -n stock-trading -- /bin/bash

# Port forward for local access
oc port-forward service/stock-trading-app-service 8080:8080 -n stock-trading
```

## 🛡️ Security Considerations

- Application runs as non-root user in container
- OpenShift security context constraints applied
- Network policies for namespace isolation
- TLS termination at route level
- Secrets management via OpenShift/Kubernetes secrets

## 📈 Scaling and Performance

### Horizontal Scaling
```bash
# Scale application
oc scale deployment/stock-trading-app --replicas=5 -n stock-trading
```

### Resource Limits
Current configuration:
- **Requests**: 512Mi memory, 250m CPU
- **Limits**: 1Gi memory, 500m CPU

## 🧪 Testing

### Local Testing
```bash
# Run unit tests
mvn test

# Run integration tests
mvn verify
```

### Load Testing
```bash
# Using curl for basic testing
curl -X GET http://localhost:8080/api/stocks

# WebSocket testing
wscat -c ws://localhost:8080/ws
```

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📞 Support

For support and questions:
- Create an issue in the repository
- Contact the development team
- Check the troubleshooting section above

---

**Note**: This application is designed for demonstration purposes. For production use, consider implementing proper authentication, external databases, and comprehensive monitoring solutions. 