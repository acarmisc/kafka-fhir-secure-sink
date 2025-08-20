#!/bin/bash
# List FHIR Patient Resources - Print resourceType and id for each Patient
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== FHIR Patient Resources ===${NC}"

# Load environment variables from .env file
if [ -f ".env" ]; then
    set -a
    source .env
    set +a
fi

# Validate required environment variables
if [ -z "$AZURE_TENANT_ID" ] || [ -z "$AZURE_CLIENT_ID" ] || [ -z "$AZURE_CLIENT_SECRET" ] || [ -z "$AZURE_FHIR_URL" ] || [ -z "$AZURE_RESOURCE" ]; then
    echo -e "${RED}ERROR: Missing required Azure environment variables${NC}"
    exit 1
fi

# Get OAuth2 access token
echo -e "${YELLOW}Getting access token...${NC}"
TOKEN_RESPONSE=$(curl -s -X POST "https://login.microsoftonline.com/$AZURE_TENANT_ID/oauth2/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=client_credentials" \
    -d "client_id=$AZURE_CLIENT_ID" \
    -d "client_secret=$AZURE_CLIENT_SECRET" \
    -d "scope=https://azurehealthcareapis.com/.default" \
    -d "resource=$AZURE_RESOURCE")

if command -v jq &> /dev/null; then
    ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')
else
    ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"access_token":"[^"]*"' | sed 's/"access_token":"//;s/"//')
fi

if [ -z "$ACCESS_TOKEN" ]; then
    echo -e "${RED}ERROR: Could not get access token${NC}"
    exit 1
fi

# Get Patient resources
echo -e "${YELLOW}Fetching Patient resources...${NC}"
RESPONSE=$(curl -s \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Accept: application/fhir+json" \
    "$AZURE_FHIR_URL/Patient?_count=1000")

# Print Patient resourceType and id
if command -v jq &> /dev/null; then
    echo "$RESPONSE" | jq -r '.entry[]? | select(.resource) | "\(.resource.resourceType):\(.resource.id)"' 2>/dev/null
    TOTAL=$(echo "$RESPONSE" | jq -r '.total // 0' 2>/dev/null)
    echo -e "${GREEN}Total: $TOTAL Patient resources${NC}"
else
    echo -e "${YELLOW}Install 'jq' for better output formatting${NC}"
    echo "$RESPONSE" | grep -o '"id":"[^"]*"' | sed 's/"id":"//;s/"//' | sed 's/^/Patient:/'
fi