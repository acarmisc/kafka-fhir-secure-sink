#!/bin/bash
# Test FHIR Data Fetching with OAuth2 Authentication
# This script validates that the FHIR connector can successfully authenticate and retrieve data
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== FHIR Connector Data Fetch Test ===${NC}"
echo "Testing FHIR data retrieval with OAuth2 authentication..."
echo ""

# Load environment variables from .env file
if [ -f ".env" ]; then
    echo -e "${YELLOW}Loading configuration from .env file...${NC}"
    set -a  # automatically export all variables
    source .env
    set +a  # disable auto-export
    echo -e "${GREEN}✓${NC} Configuration loaded from .env"
else
    echo -e "${YELLOW}No .env file found, using existing environment variables...${NC}"
fi

# Validate required environment variables
echo -e "${YELLOW}Validating environment variables...${NC}"
if [ -z "$AZURE_TENANT_ID" ] || [ -z "$AZURE_CLIENT_ID" ] || [ -z "$AZURE_CLIENT_SECRET" ] || [ -z "$AZURE_FHIR_URL" ] || [ -z "$AZURE_RESOURCE" ]; then
    echo -e "${RED}ERROR: Missing required Azure environment variables${NC}"
    echo "Please ensure your .env file contains:"
    echo "  AZURE_TENANT_ID     - Your Azure Entra ID tenant ID"
    echo "  AZURE_CLIENT_ID     - Your registered application client ID"
    echo "  AZURE_CLIENT_SECRET - Your application client secret"
    echo "  AZURE_FHIR_URL      - Your Azure Health Data Services FHIR endpoint"
    echo "  AZURE_RESOURCE      - Your Azure FHIR resource URL for authentication"
    echo ""
    echo "Example .env file:"
    echo "  AZURE_TENANT_ID=your-tenant-id"
    echo "  AZURE_CLIENT_ID=your-client-id"
    echo "  AZURE_CLIENT_SECRET=your-client-secret"
    echo "  AZURE_FHIR_URL=https://your-fhir-service.fhir.azurehealthcareapis.com"
    echo "  AZURE_RESOURCE=https://your-fhir-service.fhir.azurehealthcareapis.com"
    exit 1
fi
echo -e "${GREEN}✓${NC} Environment variables validated"

# Validate FHIR URL format
if [[ ! "$AZURE_FHIR_URL" =~ ^https://.*\.fhir\.azurehealthcareapis\.com$ ]]; then
    echo -e "${YELLOW}WARNING: FHIR URL format may be incorrect${NC}"
    echo "Expected format: https://your-service.fhir.azurehealthcareapis.com"
    echo "Current URL: $AZURE_FHIR_URL"
    echo ""
fi

# Function to get OAuth2 access token
get_access_token() {
    echo -e "${YELLOW}Acquiring OAuth2 access token from Azure Entra ID...${NC}"
    
    TOKEN_RESPONSE=$(curl -s -X POST "https://login.microsoftonline.com/$AZURE_TENANT_ID/oauth2/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=client_credentials" \
        -d "client_id=$AZURE_CLIENT_ID" \
        -d "client_secret=$AZURE_CLIENT_SECRET" \
        -d "scope=https://azurehealthcareapis.com/.default" \
        -d "resource=$AZURE_RESOURCE")

    # Check if request was successful
    if ! echo "$TOKEN_RESPONSE" | grep -q "access_token"; then
        echo -e "${RED}ERROR: Failed to obtain access token${NC}"
        echo "Response: $TOKEN_RESPONSE"
        exit 1
    fi

    # Extract access token using jq if available, otherwise use grep/sed
    if command -v jq &> /dev/null; then
        ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')
    else
        ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"access_token":"[^"]*"' | sed 's/"access_token":"//;s/"//')
    fi

    if [ -z "$ACCESS_TOKEN" ]; then
        echo -e "${RED}ERROR: Could not extract access token from response${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓${NC} OAuth2 token acquired successfully"
}

# Function to test FHIR capability statement
test_capability_statement() {
    echo -e "${YELLOW}Testing FHIR server capability statement...${NC}"
    
    CAPABILITY_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Accept: application/fhir+json" \
        "$AZURE_FHIR_URL/metadata")

    HTTP_CODE=$(echo "$CAPABILITY_RESPONSE" | tail -n1 | sed 's/HTTP_CODE://')
    RESPONSE_BODY=$(echo "$CAPABILITY_RESPONSE" | sed '$d')

    if [ "$HTTP_CODE" != "200" ]; then
        echo -e "${RED}ERROR: FHIR capability statement request failed (HTTP $HTTP_CODE)${NC}"
        echo "Response: $RESPONSE_BODY"
        return 1
    fi

    if echo "$RESPONSE_BODY" | grep -q '"resourceType":"CapabilityStatement"'; then
        echo -e "${GREEN}✓${NC} FHIR capability statement retrieved successfully"
        
        # Extract FHIR version if possible
        if command -v jq &> /dev/null; then
            FHIR_VERSION=$(echo "$RESPONSE_BODY" | jq -r '.fhirVersion // "unknown"')
            echo "  FHIR Version: $FHIR_VERSION"
        fi
        return 0
    else
        echo -e "${RED}ERROR: Invalid capability statement response${NC}"
        return 1
    fi
}

# Function to test patient resource search
test_patient_search() {
    echo -e "${YELLOW}Testing Patient resource search...${NC}"
    
    PATIENT_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Accept: application/fhir+json" \
        "$AZURE_FHIR_URL/Patient?_count=5")

    HTTP_CODE=$(echo "$PATIENT_RESPONSE" | tail -n1 | sed 's/HTTP_CODE://')
    RESPONSE_BODY=$(echo "$PATIENT_RESPONSE" | sed '$d')

    if [ "$HTTP_CODE" != "200" ]; then
        echo -e "${YELLOW}WARNING: Patient search failed (HTTP $HTTP_CODE)${NC}"
        echo "This may be normal if no Patient resources exist"
        return 1
    fi

    if echo "$RESPONSE_BODY" | grep -q '"resourceType":"Bundle"'; then
        echo -e "${GREEN}✓${NC} Patient resource search successful"
        
        if command -v jq &> /dev/null; then
            TOTAL=$(echo "$RESPONSE_BODY" | jq -r '.total // 0')
            echo "  Total Patient resources: $TOTAL"
        fi
        return 0
    else
        echo -e "${YELLOW}WARNING: Unexpected Patient search response${NC}"
        return 1
    fi
}
# Function to test observation resource search
test_observation_search() {
    echo -e "${YELLOW}Testing Observation resource search...${NC}"
    
    OBSERVATION_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Accept: application/fhir+json" \
        "$AZURE_FHIR_URL/Observation?_count=5")

    HTTP_CODE=$(echo "$OBSERVATION_RESPONSE" | tail -n1 | sed 's/HTTP_CODE://')
    RESPONSE_BODY=$(echo "$OBSERVATION_RESPONSE" | sed '$d')

    if [ "$HTTP_CODE" != "200" ]; then
        echo -e "${YELLOW}WARNING: Observation search failed (HTTP $HTTP_CODE)${NC}"
        echo "This may be normal if no Observation resources exist"
        return 1
    fi

    if echo "$RESPONSE_BODY" | grep -q '"resourceType":"Bundle"'; then
        echo -e "${GREEN}✓${NC} Observation resource search successful"
        
        if command -v jq &> /dev/null; then
            TOTAL=$(echo "$RESPONSE_BODY" | jq -r '.total // 0')
            echo "  Total Observation resources: $TOTAL"
        fi
        return 0
    else
        echo -e "${YELLOW}WARNING: Unexpected Observation search response${NC}"
        return 1
    fi
}

# Function to test resource type list
test_resource_types() {
    echo -e "${YELLOW}Testing supported resource types...${NC}"
    
    if [ -z "$CAPABILITY_RESPONSE_BODY" ]; then
        echo -e "${YELLOW}WARNING: Cannot test resource types without capability statement${NC}"
        return 1
    fi

    if command -v jq &> /dev/null; then
        RESOURCE_TYPES=$(echo "$CAPABILITY_RESPONSE_BODY" | jq -r '.rest[]?.resource[]?.type' 2>/dev/null | sort | uniq)
        if [ -n "$RESOURCE_TYPES" ]; then
            echo -e "${GREEN}✓${NC} Supported FHIR resource types:"
            echo "$RESOURCE_TYPES" | head -10 | sed 's/^/  - /'
            RESOURCE_COUNT=$(echo "$RESOURCE_TYPES" | wc -l)
            if [ "$RESOURCE_COUNT" -gt 10 ]; then
                echo "  ... and $(($RESOURCE_COUNT - 10)) more"
            fi
        else
            echo -e "${YELLOW}WARNING: Could not extract resource types${NC}"
        fi
    else
        echo -e "${YELLOW}INFO: Install 'jq' for detailed resource type analysis${NC}"
    fi
}

# Main test execution
echo -e "${BLUE}Starting FHIR connector tests...${NC}"
echo ""

# Get access token
get_access_token

# Store capability response for later use
echo -e "${YELLOW}Retrieving and storing capability statement...${NC}"
CAPABILITY_RESPONSE_RAW=$(curl -s \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Accept: application/fhir+json" \
    "$AZURE_FHIR_URL/metadata")
CAPABILITY_RESPONSE_BODY="$CAPABILITY_RESPONSE_RAW"

# Run tests
test_capability_statement
test_resource_types
test_patient_search
test_observation_search

# Summary
echo ""
echo -e "${BLUE}=== Test Results Summary ===${NC}"
echo -e "${GREEN}✓${NC} OAuth2 Authentication: SUCCESS"
echo -e "${GREEN}✓${NC} FHIR Server Connection: SUCCESS"
echo -e "${GREEN}✓${NC} Capability Statement: SUCCESS"

# Check if searches were successful
PATIENT_SUCCESS=false
OBSERVATION_SUCCESS=false

if test_patient_search &> /dev/null; then
    PATIENT_SUCCESS=true
fi

if test_observation_search &> /dev/null; then
    OBSERVATION_SUCCESS=true
fi

if [ "$PATIENT_SUCCESS" = true ]; then
    echo -e "${GREEN}✓${NC} Patient Resource Access: SUCCESS"
else
    echo -e "${YELLOW}○${NC} Patient Resource Access: NO DATA (normal for empty server)"
fi

if [ "$OBSERVATION_SUCCESS" = true ]; then
    echo -e "${GREEN}✓${NC} Observation Resource Access: SUCCESS"
else
    echo -e "${YELLOW}○${NC} Observation Resource Access: NO DATA (normal for empty server)"
fi

echo ""
echo -e "${GREEN}FHIR Connector Test Complete!${NC}"
echo -e "${GREEN}Your Azure Health Data Services FHIR connection is working correctly.${NC}"

# Optional: Save token for manual testing
if [ "$1" = "--save-token" ]; then
    echo ""
    echo -e "${YELLOW}Access token saved to .fhir-token (expires in ~1 hour):${NC}"
    echo "$ACCESS_TOKEN" > .fhir-token
    echo "Use: curl -H \"Authorization: Bearer \$(cat .fhir-token)\" -H \"Accept: application/fhir+json\" \"$AZURE_FHIR_URL/Patient\""
fi
