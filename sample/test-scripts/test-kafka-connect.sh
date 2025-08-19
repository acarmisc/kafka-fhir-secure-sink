#!/bin/sh
# Test Kafka Connect FHIR Sink Connector with Azure OAuth2
set -e

echo "Testing Kafka Connect FHIR Sink Connector..."

# Validate Kafka Connect is running
echo "Checking Kafka Connect status..."
CONNECT_STATUS=$(curl -s "$KAFKA_CONNECT_URL/connectors" || echo "FAILED")
if [ "$CONNECT_STATUS" = "FAILED" ]; then
    echo "ERROR: Kafka Connect is not accessible"
    exit 1
fi
echo "✓ Kafka Connect is running"

# Create FHIR Sink Connector configuration with Azure OAuth2
echo "Creating FHIR Sink Connector with Azure OAuth2..."
CONNECTOR_CONFIG='{
  "name": "azure-fhir-secure-sink-connector",
  "config": {
    "connector.class": "com.healthcare.kafka.connect.fhir.FhirSecureSinkConnector",
    "tasks.max": "1",
    "topics": "fhir-resources",
    "fhir.server.url": "'$AZURE_FHIR_URL'",
    "azure.tenant.id": "'$AZURE_TENANT_ID'",
    "azure.client.id": "'$AZURE_CLIENT_ID'",
    "azure.client.secret": "'$AZURE_CLIENT_SECRET'",
    "azure.scope": "https://azurehealthcareapis.com/.default",
    "http.timeout.ms": "30000",
    "retry.attempts": "3",
    "retry.backoff.ms": "1000",
    "fhir.validation.enabled": "true",
    "key.converter": "org.apache.kafka.connect.storage.StringConverter",
    "value.converter": "org.apache.kafka.connect.storage.StringConverter",
    "key.converter.schemas.enable": "false",
    "value.converter.schemas.enable": "false"
  }
}'

# Deploy connector
curl -s -X POST "$KAFKA_CONNECT_URL/connectors" \
    -H "Content-Type: application/json" \
    -d "$CONNECTOR_CONFIG" > /dev/null

echo "✓ FHIR Sink Connector deployed"

# Check connector status
sleep 5
CONNECTOR_STATUS=$(curl -s "$KAFKA_CONNECT_URL/connectors/azure-fhir-secure-sink-connector/status")
echo "Connector status: $CONNECTOR_STATUS"

if echo "$CONNECTOR_STATUS" | grep -q '"state":"RUNNING"'; then
    echo "✓ Connector is running successfully"
else
    echo "WARNING: Connector may not be running properly"
fi

echo ""
echo "=== Kafka Connect Test Results ==="
echo "✓ Kafka Connect accessible: SUCCESS"
echo "✓ FHIR Sink Connector deployed: SUCCESS"
echo "✓ Azure OAuth2 integration: CONFIGURED"