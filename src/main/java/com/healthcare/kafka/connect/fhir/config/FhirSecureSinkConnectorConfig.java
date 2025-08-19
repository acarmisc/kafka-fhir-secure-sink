package com.healthcare.kafka.connect.fhir.config;

import org.apache.kafka.common.config.AbstractConfig;
import org.apache.kafka.common.config.ConfigDef;
import org.apache.kafka.common.config.ConfigException;

import java.util.Map;

public class FhirSecureSinkConnectorConfig extends AbstractConfig {

    public static final String FHIR_SERVER_URL_CONFIG = "fhir.server.url";
    private static final String FHIR_SERVER_URL_DOC = "Azure Health Data Services FHIR service URL";
    
    public static final String AZURE_TENANT_ID_CONFIG = "azure.tenant.id";
    private static final String AZURE_TENANT_ID_DOC = "Azure Entra ID tenant ID";
    
    public static final String AZURE_CLIENT_ID_CONFIG = "azure.client.id";
    private static final String AZURE_CLIENT_ID_DOC = "Azure Entra ID client ID (application ID)";
    
    public static final String AZURE_CLIENT_SECRET_CONFIG = "azure.client.secret";
    private static final String AZURE_CLIENT_SECRET_DOC = "Azure Entra ID client secret";
    
    public static final String AZURE_SCOPE_CONFIG = "azure.scope";
    private static final String AZURE_SCOPE_DOC = "OAuth2 scope for FHIR API access";
    private static final String AZURE_SCOPE_DEFAULT = "https://azurehealthcareapis.com/.default";
    
    public static final String AZURE_RESOURCE_CONFIG = "azure.resource";
    private static final String AZURE_RESOURCE_DOC = "Azure resource identifier for OAuth2 authentication";
    
    public static final String FHIR_RESOURCE_TYPE_CONFIG = "fhir.resource.type";
    private static final String FHIR_RESOURCE_TYPE_DOC = "Expected FHIR resource type (optional validation)";
    
    public static final String HTTP_TIMEOUT_CONFIG = "http.timeout.ms";
    private static final String HTTP_TIMEOUT_DOC = "HTTP request timeout in milliseconds";
    private static final int HTTP_TIMEOUT_DEFAULT = 30000;
    
    public static final String RETRY_ATTEMPTS_CONFIG = "retry.attempts";
    private static final String RETRY_ATTEMPTS_DOC = "Number of retry attempts for failed requests";
    private static final int RETRY_ATTEMPTS_DEFAULT = 3;
    
    public static final String RETRY_BACKOFF_MS_CONFIG = "retry.backoff.ms";
    private static final String RETRY_BACKOFF_MS_DOC = "Retry backoff time in milliseconds";
    private static final int RETRY_BACKOFF_MS_DEFAULT = 1000;

    public static final String ENABLE_VALIDATION_CONFIG = "fhir.validation.enabled";
    private static final String ENABLE_VALIDATION_DOC = "Enable FHIR resource validation before sending";
    private static final boolean ENABLE_VALIDATION_DEFAULT = true;

    public FhirSecureSinkConnectorConfig(Map<String, String> props) {
        super(configDef(), props);
        validateConfig();
    }

    public static ConfigDef configDef() {
        return new ConfigDef()
            .define(FHIR_SERVER_URL_CONFIG, ConfigDef.Type.STRING, ConfigDef.NO_DEFAULT_VALUE,
                    ConfigDef.Importance.HIGH, FHIR_SERVER_URL_DOC)
            
            .define(AZURE_TENANT_ID_CONFIG, ConfigDef.Type.STRING, ConfigDef.NO_DEFAULT_VALUE,
                    ConfigDef.Importance.HIGH, AZURE_TENANT_ID_DOC)
            
            .define(AZURE_CLIENT_ID_CONFIG, ConfigDef.Type.STRING, ConfigDef.NO_DEFAULT_VALUE,
                    ConfigDef.Importance.HIGH, AZURE_CLIENT_ID_DOC)
            
            .define(AZURE_CLIENT_SECRET_CONFIG, ConfigDef.Type.PASSWORD, ConfigDef.NO_DEFAULT_VALUE,
                    ConfigDef.Importance.HIGH, AZURE_CLIENT_SECRET_DOC)
            
            .define(AZURE_SCOPE_CONFIG, ConfigDef.Type.STRING, AZURE_SCOPE_DEFAULT,
                    ConfigDef.Importance.MEDIUM, AZURE_SCOPE_DOC)
            
            .define(AZURE_RESOURCE_CONFIG, ConfigDef.Type.STRING, ConfigDef.NO_DEFAULT_VALUE,
                    ConfigDef.Importance.HIGH, AZURE_RESOURCE_DOC)
            
            .define(FHIR_RESOURCE_TYPE_CONFIG, ConfigDef.Type.STRING, null,
                    ConfigDef.Importance.LOW, FHIR_RESOURCE_TYPE_DOC)
            
            .define(HTTP_TIMEOUT_CONFIG, ConfigDef.Type.INT, HTTP_TIMEOUT_DEFAULT,
                    ConfigDef.Range.atLeast(1000), ConfigDef.Importance.MEDIUM, HTTP_TIMEOUT_DOC)
            
            .define(RETRY_ATTEMPTS_CONFIG, ConfigDef.Type.INT, RETRY_ATTEMPTS_DEFAULT,
                    ConfigDef.Range.atLeast(0), ConfigDef.Importance.MEDIUM, RETRY_ATTEMPTS_DOC)
            
            .define(RETRY_BACKOFF_MS_CONFIG, ConfigDef.Type.INT, RETRY_BACKOFF_MS_DEFAULT,
                    ConfigDef.Range.atLeast(100), ConfigDef.Importance.MEDIUM, RETRY_BACKOFF_MS_DOC)
            
            .define(ENABLE_VALIDATION_CONFIG, ConfigDef.Type.BOOLEAN, ENABLE_VALIDATION_DEFAULT,
                    ConfigDef.Importance.MEDIUM, ENABLE_VALIDATION_DOC);
    }

    private void validateConfig() {
        String fhirUrl = getFhirServerUrl();
        if (fhirUrl == null || !fhirUrl.startsWith("https://")) {
            throw new ConfigException("FHIR server URL must be HTTPS");
        }
    }

    public String getFhirServerUrl() {
        return getString(FHIR_SERVER_URL_CONFIG);
    }

    public String getAzureTenantId() {
        return getString(AZURE_TENANT_ID_CONFIG);
    }

    public String getAzureClientId() {
        return getString(AZURE_CLIENT_ID_CONFIG);
    }

    public String getAzureClientSecret() {
        return getPassword(AZURE_CLIENT_SECRET_CONFIG).value();
    }

    public String getAzureScope() {
        return getString(AZURE_SCOPE_CONFIG);
    }

    public String getAzureResource() {
        return getString(AZURE_RESOURCE_CONFIG);
    }

    public String getFhirResourceType() {
        return getString(FHIR_RESOURCE_TYPE_CONFIG);
    }

    public int getHttpTimeout() {
        return getInt(HTTP_TIMEOUT_CONFIG);
    }

    public int getRetryAttempts() {
        return getInt(RETRY_ATTEMPTS_CONFIG);
    }

    public int getRetryBackoffMs() {
        return getInt(RETRY_BACKOFF_MS_CONFIG);
    }

    public boolean isValidationEnabled() {
        return getBoolean(ENABLE_VALIDATION_CONFIG);
    }
}