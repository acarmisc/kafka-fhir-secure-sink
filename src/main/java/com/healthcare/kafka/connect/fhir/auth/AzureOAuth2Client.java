package com.healthcare.kafka.connect.fhir.auth;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.healthcare.kafka.connect.fhir.config.FhirSecureSinkConnectorConfig;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.concurrent.locks.ReentrantReadWriteLock;

public class AzureOAuth2Client {

    private static final Logger log = LoggerFactory.getLogger(AzureOAuth2Client.class);
    
    private final FhirSecureSinkConnectorConfig config;
    private final HttpClient httpClient;
    private final ObjectMapper objectMapper;
    private final ReentrantReadWriteLock lock = new ReentrantReadWriteLock();
    
    private volatile TokenInfo cachedToken;
    
    private static class TokenInfo {
        final String token;
        final Instant expiresAt;
        
        TokenInfo(String token, int expiresInSeconds) {
            this.token = token;
            this.expiresAt = Instant.now().plusSeconds(expiresInSeconds);
        }
        
        boolean isExpired() {
            return Instant.now().plusSeconds(300).isAfter(expiresAt); // 5 minute buffer
        }
    }

    public AzureOAuth2Client(FhirSecureSinkConnectorConfig config) {
        this.config = config;
        this.httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(10))
            .build();
        this.objectMapper = new ObjectMapper();
        
        log.info("Azure OAuth2 client initialized for tenant: {}", config.getAzureTenantId());
    }

    public String getAccessToken() {
        lock.readLock().lock();
        try {
            if (cachedToken != null && !cachedToken.isExpired()) {
                return cachedToken.token;
            }
        } finally {
            lock.readLock().unlock();
        }

        lock.writeLock().lock();
        try {
            if (cachedToken != null && !cachedToken.isExpired()) {
                return cachedToken.token;
            }

            log.debug("Acquiring new access token from Azure Entra ID");
            cachedToken = acquireNewToken();
            
            log.debug("Successfully acquired new access token, expires at: {}", cachedToken.expiresAt);
            return cachedToken.token;

        } catch (Exception e) {
            log.error("Failed to acquire access token: {}", e.getMessage(), e);
            throw new RuntimeException("OAuth2 authentication failed", e);
        } finally {
            lock.writeLock().unlock();
        }
    }
    
    private TokenInfo acquireNewToken() throws IOException, InterruptedException {
        String tokenEndpoint = String.format("https://login.microsoftonline.com/%s/oauth2/token", 
            config.getAzureTenantId());
        
        String requestBody = String.format(
            "grant_type=client_credentials&client_id=%s&client_secret=%s&scope=%s&resource=%s",
            URLEncoder.encode(config.getAzureClientId(), StandardCharsets.UTF_8),
            URLEncoder.encode(config.getAzureClientSecret(), StandardCharsets.UTF_8),
            URLEncoder.encode(config.getAzureScope(), StandardCharsets.UTF_8),
            URLEncoder.encode(config.getAzureResource(), StandardCharsets.UTF_8)
        );
        
        HttpRequest request = HttpRequest.newBuilder()
            .uri(URI.create(tokenEndpoint))
            .header("Content-Type", "application/x-www-form-urlencoded")
            .timeout(Duration.ofSeconds(30))
            .POST(HttpRequest.BodyPublishers.ofString(requestBody))
            .build();
            
        HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
        
        if (response.statusCode() != 200) {
            log.error("OAuth2 token request failed with status: {} body: {}", 
                response.statusCode(), response.body());
            throw new RuntimeException("OAuth2 token request failed with status: " + response.statusCode());
        }
        
        JsonNode jsonResponse = objectMapper.readTree(response.body());
        String accessToken = jsonResponse.get("access_token").asText();
        int expiresIn = jsonResponse.get("expires_in").asInt();
        
        return new TokenInfo(accessToken, expiresIn);
    }

    public void invalidateToken() {
        lock.writeLock().lock();
        try {
            log.debug("Invalidating cached access token");
            cachedToken = null;
        } finally {
            lock.writeLock().unlock();
        }
    }

    public void close() {
        lock.writeLock().lock();
        try {
            cachedToken = null;
            log.info("Azure OAuth2 client closed");
        } finally {
            lock.writeLock().unlock();
        }
    }
}