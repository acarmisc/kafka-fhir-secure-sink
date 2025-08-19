# Kafka FHIR Secure Sink Connector - Testing Environment

This directory provides a complete testing environment for the Kafka FHIR Secure Sink Connector with Azure Health Data Services integration.

## What's Included

This test environment provides:

- ✅ **Complete Kafka Stack**: Single-node Kafka cluster with Zookeeper
- ✅ **Kafka Connect**: Pre-configured with the FHIR Secure Sink Connector
- ✅ **AKHQ Management UI**: Web interface for monitoring topics, messages, and connectors
- ✅ **FHIR Producer**: Automated producer sending sample FHIR resources
- ✅ **Sample Data**: Realistic Patient and Observation FHIR R4 resources
- ✅ **Testing Scripts**: OAuth2 authentication and connectivity verification
- ✅ **Schema Registry**: For future Avro/Schema support

## Prerequisites

### Required
- **Docker** and **Docker Compose**
- **Azure Health Data Services** FHIR service
- **Azure Entra ID** application registration

### Azure Setup Required
1. Create **Azure Health Data Services** workspace and FHIR service
2. Register application in **Azure Entra ID** with:
   - Client ID and Client Secret
   - FHIR API permissions (`https://azurehealthcareapis.com/.default`)
   - `FHIR Data Contributor` role assigned to the application

## Quick Start

### 1. Configure Azure Credentials

```bash
# Copy the environment template
cp .env.example .env

# Edit with your actual Azure credentials
nano .env
```

Fill in your Azure credentials:
```bash
AZURE_TENANT_ID=your-tenant-id-here
AZURE_CLIENT_ID=your-client-id-here  
AZURE_CLIENT_SECRET=your-client-secret-here
AZURE_FHIR_URL=https://your-workspace-your-fhir-service.fhir.azurehealthcareapis.com
```

### 2. Test Azure Connectivity (Recommended)

Before starting the full stack, test your Azure configuration:

```bash
# Test FHIR server connectivity and OAuth2 authentication
./test-fhir-fetch.sh
```

This script will:
- ✅ Authenticate with Azure Entra ID using OAuth2
- ✅ Fetch FHIR server capability statement
- ✅ Search for existing Patient and Observation resources
- ✅ Validate your FHIR service is accessible

### 3. Run the Complete Test Environment

```bash
# Run the comprehensive test suite
./run-tests.sh
```

This will:
1. **Build** the connector (if needed)
2. **Start** the Docker Compose stack
3. **Wait** for services to be healthy
4. **Deploy** the FHIR connector to Kafka Connect
5. **Monitor** the data flow from Kafka to Azure FHIR service

### 4. Manual Stack Management

If you prefer to manage services manually:

```bash
# Start all services
docker-compose up -d

# Check service health
docker-compose ps

# View connector logs
docker-compose logs -f kafka-connect

# View producer logs
docker-compose logs -f fhir-producer

# Stop all services
docker-compose down
```

## Monitoring and Management

### Web Interfaces

- **AKHQ Kafka UI**: http://localhost:8080
  - Monitor Kafka topics and messages
  - View connector status and configuration
  - Browse message content
  
- **Kafka Connect REST API**: http://localhost:8083
  - Manage connectors programmatically

### Command Line Monitoring

```bash
# Check connector status
curl -s http://localhost:8083/connectors/azure-fhir-secure-sink-connector/status | jq

# List all connectors
curl -s http://localhost:8083/connectors | jq

# View connector configuration
curl -s http://localhost:8083/connectors/azure-fhir-secure-sink-connector/config | jq

# Check topic messages (last 10)
docker exec kafka-fhir-broker kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic fhir-resources \
  --from-beginning \
  --max-messages 10
```

## Directory Structure

```
sample/
├── .env.example                    # Azure credentials template
├── README.md                       # This file
├── docker-compose.yml              # Complete Kafka + Connect stack
├── run-tests.sh                    # Full integration test script
├── test-fhir-fetch.sh              # Azure connectivity test script
├── config/                         # Connector configurations
│   ├── fhir-sink-connector.json           # Main connector config
│   ├── fhir-sink-connector-no-validation.json
│   ├── fhir-sink-connector-test.json
│   └── connect-standalone.properties      # Connect worker config
├── connectors/                     # Built connector JAR location
│   └── kafka-fhir-secure-sink-1.0.0-SNAPSHOT-jar-with-dependencies.jar
├── fhir-producer/                  # FHIR sample data producer
│   ├── Dockerfile                         # Producer container
│   ├── producer.py                        # Python producer script  
│   └── requirements.txt                   # Python dependencies
├── fhir-samples/                   # Sample FHIR R4 resources
│   ├── patient-example.json               # Sample patient
│   └── observation-vitals.json            # Sample vital signs
└── test-scripts/                   # Additional test utilities
    ├── test-azure-oauth2.sh               # OAuth2 authentication test
    └── test-kafka-connect.sh              # Connector deployment test
```

## Sample FHIR Resources

The test environment includes realistic FHIR R4 sample data:

### Patient Resource
- Complete patient demographics
- Multiple identifiers
- Contact information
- Telecom details

### Observation Resource  
- Vital signs (blood pressure)
- Component values (systolic/diastolic)
- LOINC codes for interoperability
- Reference to patient

**Adding Custom Resources**: Place additional FHIR JSON files in `fhir-samples/` and they will be automatically picked up by the producer.

## Configuration Files

### Main Connector Configuration
`config/fhir-sink-connector.json` - Production-ready configuration with:
- FHIR resource validation enabled
- OAuth2 authentication configured
- Retry logic with exponential backoff
- String converters for JSON data

### Alternative Configurations
- `fhir-sink-connector-no-validation.json` - Faster processing, no validation
- `fhir-sink-connector-test.json` - Development settings

### Environment Variables

The Docker Compose stack supports these environment variables:

**Kafka Producer**:
- `KAFKA_BOOTSTRAP_SERVERS` (default: kafka:29092)
- `KAFKA_TOPIC` (default: fhir-resources) 
- `SEND_INTERVAL_SECONDS` (default: 10)

**Azure Integration**:
- `AZURE_TENANT_ID` - Your Azure tenant ID
- `AZURE_CLIENT_ID` - Your application client ID
- `AZURE_CLIENT_SECRET` - Your client secret
- `AZURE_FHIR_URL` - Your FHIR service URL

## Troubleshooting

### Connector Fails to Start

If the connector shows `FAILED` status:

```bash
# Check detailed connector status
curl -s http://localhost:8083/connectors/azure-fhir-secure-sink-connector/status | jq

# Common issues:
# - FHIR server URL must be HTTPS
# - Azure credentials must be valid
# - Application must have FHIR Data Contributor role
```

### Authentication Issues

```bash
# Test Azure authentication independently
./test-fhir-fetch.sh

# Check for:
# - Correct tenant ID, client ID, client secret
# - Application has proper FHIR permissions
# - FHIR service URL is accessible
```

### No Messages in FHIR Service

```bash
# Verify messages are being produced
docker-compose logs fhir-producer

# Check Kafka topic has messages
docker exec kafka-fhir-broker kafka-run-class kafka.tools.GetOffsetShell \
  --broker-list localhost:9092 --topic fhir-resources

# Check connector is consuming
curl -s http://localhost:8083/connectors/azure-fhir-secure-sink-connector/status | jq '.tasks[0]'
```

### Service Health Issues

```bash
# Check all service health
docker-compose ps

# Services should show 'Up' and 'healthy'
# If not healthy, check logs:
docker-compose logs service-name
```

## Performance Testing

### Message Volume Testing

```bash
# Scale up the producer for higher volume
docker-compose up -d --scale fhir-producer=3

# Monitor processing lag
# Check AKHQ UI at http://localhost:8080
```

### Load Testing

The sample environment can handle moderate loads for testing. For production load testing:

1. Increase `tasks.max` in connector configuration
2. Tune Kafka producer settings
3. Monitor Azure FHIR service throttling limits
4. Use multiple connector instances for horizontal scaling

## Cleaning Up

```bash
# Stop all services and remove volumes
docker-compose down -v

# Remove built images
docker-compose down --rmi local

# Clean up Docker system (optional)
docker system prune -f
```

## Next Steps

After successful testing:

1. **Production Deployment**: Use the main [README.md](../README.md) for production setup
2. **Security Hardening**: Implement Kafka Connect configuration encryption
3. **Monitoring**: Set up production monitoring and alerting
4. **Scaling**: Configure multiple connector tasks for higher throughput

## Support

If you encounter issues:

1. Check the troubleshooting section above
2. Review logs from all services
3. Test Azure connectivity with `./test-fhir-fetch.sh`
4. Verify environment variables are set correctly

For additional help, see the main project [README.md](../README.md#support).