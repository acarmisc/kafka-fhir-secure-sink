#!/bin/sh
# Test Azure Health Data Services OAuth2 Authentication
set -e

echo "Testing Azure Health Data Services OAuth2 Authentication..."

# Validate required environment variables
if [ -z "$AZURE_TENANT_ID" ] || [ -z "$AZURE_CLIENT_ID" ] || [ -z "$AZURE_CLIENT_SECRET" ] || [ -z "$AZURE_FHIR_URL" ]; then
    echo "ERROR: Missing required Azure environment variables"
    echo "Required: AZURE_TENANT_ID, AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, AZURE_FHIR_URL"
    exit 1
fi

echo "✓ Environment variables validated"

# Get OAuth2 access token from Azure Entra ID
echo "Requesting OAuth2 token from Azure Entra ID..."
TOKEN_RESPONSE=$(curl -s -X POST "https://login.microsoftonline.com/$AZURE_TENANT_ID/oauth2/v2.0/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=client_credentials" \
    -d "client_id=$AZURE_CLIENT_ID" \
    -d "client_secret=$AZURE_CLIENT_SECRET" \
    -d "scope=https://azurehealthcareapis.com/.default")

# Extract access token
ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"access_token":"[^"]*"' | sed 's/"access_token":"//;s/"//')

if [ -z "$ACCESS_TOKEN" ]; then
    echo "ERROR: Failed to obtain access token"
    echo "Response: $TOKEN_RESPONSE"
    exit 1
fi

echo "✓ OAuth2 token obtained successfully"

# Test FHIR API access with Bearer token
echo "Testing FHIR API access with OAuth2 token..."
FHIR_RESPONSE=$(curl -s -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Accept: application/fhir+json" \
    "$AZURE_FHIR_URL/metadata")

if echo "$FHIR_RESPONSE" | grep -q '"resourceType":"CapabilityStatement"'; then
    echo "✓ FHIR API access successful"
    echo "✓ Azure Health Data Services OAuth2 authentication working correctly"
else
    echo "ERROR: FHIR API access failed"
    echo "Response: $FHIR_RESPONSE"
    exit 1
fi

echo ""
echo "=== Azure OAuth2 Test Results ==="
echo "✓ OAuth2 token acquisition: SUCCESS"
echo "✓ FHIR API authentication: SUCCESS"
echo "✓ Azure Health Data Services integration: READY"