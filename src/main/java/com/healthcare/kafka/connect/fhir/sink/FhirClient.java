package com.healthcare.kafka.connect.fhir.sink;

import ca.uhn.fhir.context.FhirContext;
import ca.uhn.fhir.parser.IParser;
import ca.uhn.fhir.rest.client.api.IGenericClient;
import ca.uhn.fhir.rest.client.interceptor.BearerTokenAuthInterceptor;
import ca.uhn.fhir.rest.server.exceptions.BaseServerResponseException;
import ca.uhn.fhir.rest.server.exceptions.UnprocessableEntityException;
import com.healthcare.kafka.connect.fhir.auth.AzureOAuth2Client;
import com.healthcare.kafka.connect.fhir.config.FhirSecureSinkConnectorConfig;
import org.hl7.fhir.r4.model.Resource;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.concurrent.TimeUnit;
import java.util.function.Supplier;

public class FhirClient {

    private static final Logger log = LoggerFactory.getLogger(FhirClient.class);
    
    private final FhirSecureSinkConnectorConfig config;
    private final AzureOAuth2Client authClient;
    private final FhirContext fhirContext;
    private final IGenericClient client;
    private final IParser jsonParser;

    public FhirClient(FhirSecureSinkConnectorConfig config, AzureOAuth2Client authClient) {
        this.config = config;
        this.authClient = authClient;
        this.fhirContext = FhirContext.forR4();
        
        // Configure timeouts directly on the FHIR context
        fhirContext.getRestfulClientFactory().setSocketTimeout(config.getHttpTimeout());
        fhirContext.getRestfulClientFactory().setConnectTimeout(config.getHttpTimeout());
        
        this.client = fhirContext.newRestfulGenericClient(config.getFhirServerUrl());
        this.jsonParser = fhirContext.newJsonParser();
        
        setupAuthentication();
        
        log.info("FHIR client initialized for endpoint: {}", config.getFhirServerUrl());
    }

    private void setupAuthentication() {
        BearerTokenAuthInterceptor authInterceptor = new BearerTokenAuthInterceptor() {
            @Override
            public void interceptRequest(ca.uhn.fhir.rest.client.api.IHttpRequest theRequest) {
                try {
                    String token = authClient.getAccessToken();
                    setToken(token);
                    super.interceptRequest(theRequest);
                } catch (Exception e) {
                    log.error("Failed to get access token for FHIR request", e);
                    throw new RuntimeException("Authentication failed", e);
                }
            }
        };
        
        client.registerInterceptor(authInterceptor);
    }

    public void sendFhirResource(String fhirResourceJson) {
        int attempts = 0;
        int maxAttempts = config.getRetryAttempts() + 1;
        
        while (attempts < maxAttempts) {
            try {
                attempts++;
                
                Resource resource = parseAndValidateResource(fhirResourceJson);
                
                log.debug("Sending FHIR resource: {} with ID: {}", 
                    resource.getResourceType(), resource.getId());
                
                if (resource.getId() != null && !resource.getId().isEmpty()) {
                    client.update().resource(resource).execute();
                    log.debug("Successfully updated FHIR resource: {}", resource.getId());
                } else {
                    client.create().resource(resource).execute();
                    log.debug("Successfully created FHIR resource: {}", resource.getResourceType());
                }
                
                return;
                
            } catch (Exception e) {
                logDetailedHttpError(e, attempts, fhirResourceJson);
                
                if (attempts >= maxAttempts) {
                    log.error("FAILED to send FHIR resource after {} attempts. Final error: {}", maxAttempts, e.getMessage());
                    log.error("Resource content: {}", truncateForLog(fhirResourceJson, 500));
                    throw new RuntimeException("Failed to send FHIR resource", e);
                }
                
                if (isAuthenticationError(e)) {
                    log.warn("Authentication error detected (HTTP 401/403), invalidating token and retrying");
                    authClient.invalidateToken();
                }
                
                try {
                    Thread.sleep(config.getRetryBackoffMs() * attempts);
                } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                    throw new RuntimeException("Interrupted during retry backoff", ie);
                }
            }
        }
    }

    private Resource parseAndValidateResource(String fhirResourceJson) {
        try {
            Resource resource = (Resource) jsonParser.parseResource(fhirResourceJson);
            
            if (config.isValidationEnabled()) {
                fhirContext.newValidator().validateWithResult(resource);
            }
            
            String expectedType = config.getFhirResourceType();
            if (expectedType != null && !expectedType.equals(resource.getResourceType().name())) {
                log.warn("Resource type mismatch. Expected: {}, Actual: {}", 
                    expectedType, resource.getResourceType().name());
            }
            
            return resource;
            
        } catch (Exception e) {
            log.error("Failed to parse or validate FHIR resource: {}", fhirResourceJson, e);
            throw new RuntimeException("Invalid FHIR resource", e);
        }
    }

    private void logDetailedHttpError(Exception e, int attempt, String resourceJson) {
        if (e instanceof BaseServerResponseException) {
            BaseServerResponseException httpError = (BaseServerResponseException) e;
            log.error("HTTP Error on attempt {}: Status={}, Message={}", 
                attempt, httpError.getStatusCode(), httpError.getMessage());
            
            if (httpError.getResponseBody() != null && !httpError.getResponseBody().isEmpty()) {
                log.error("HTTP Response Body: {}", truncateForLog(httpError.getResponseBody(), 1000));
            }
            
            if (httpError instanceof UnprocessableEntityException) {
                log.error("FHIR Validation Error (422): The resource failed server-side validation");
                log.debug("Problematic resource: {}", truncateForLog(resourceJson, 1000));
            }
            
        } else {
            log.error("Non-HTTP Error on attempt {}: Type={}, Message={}", 
                attempt, e.getClass().getSimpleName(), e.getMessage());
        }
    }
    
    private String truncateForLog(String content, int maxLength) {
        if (content == null) return "null";
        if (content.length() <= maxLength) return content;
        return content.substring(0, maxLength) + "... [truncated]";
    }

    private boolean isAuthenticationError(Exception e) {
        if (e instanceof BaseServerResponseException) {
            int statusCode = ((BaseServerResponseException) e).getStatusCode();
            return statusCode == 401 || statusCode == 403;
        }
        
        String message = e.getMessage();
        return message != null && (
            message.contains("401") || 
            message.contains("403") || 
            message.contains("Unauthorized") || 
            message.contains("Forbidden") ||
            message.contains("invalid_token")
        );
    }

    public void close() {
        log.info("FHIR client closed");
    }
}