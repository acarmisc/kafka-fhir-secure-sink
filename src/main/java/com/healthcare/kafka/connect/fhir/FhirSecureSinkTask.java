package com.healthcare.kafka.connect.fhir;

import com.healthcare.kafka.connect.fhir.auth.AzureOAuth2Client;
import com.healthcare.kafka.connect.fhir.config.FhirSecureSinkConnectorConfig;
import com.healthcare.kafka.connect.fhir.sink.FhirClient;
import org.apache.kafka.clients.consumer.OffsetAndMetadata;
import org.apache.kafka.common.TopicPartition;
import org.apache.kafka.connect.sink.SinkRecord;
import org.apache.kafka.connect.sink.SinkTask;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Collection;
import java.util.Map;

public class FhirSecureSinkTask extends SinkTask {

    private static final Logger log = LoggerFactory.getLogger(FhirSecureSinkTask.class);
    
    private FhirSecureSinkConnectorConfig config;
    private AzureOAuth2Client authClient;
    private FhirClient fhirClient;

    @Override
    public String version() {
        return "1.0.0";
    }

    @Override
    public void start(Map<String, String> props) {
        log.info("Starting FHIR Secure Sink Task");
        
        config = new FhirSecureSinkConnectorConfig(props);
        authClient = new AzureOAuth2Client(config);
        fhirClient = new FhirClient(config, authClient);
        
        log.info("FHIR Secure Sink Task started successfully");
    }

    @Override
    public void put(Collection<SinkRecord> records) {
        if (records.isEmpty()) {
            return;
        }
        
        log.info("Processing batch of {} FHIR records", records.size());
        
        int successCount = 0;
        int errorCount = 0;
        
        for (SinkRecord record : records) {
            try {
                processFhirRecord(record);
                successCount++;
                log.debug("Successfully processed record {}/{}: topic={}, partition={}, offset={}", 
                    successCount + errorCount, records.size(), record.topic(), record.kafkaPartition(), record.kafkaOffset());
            } catch (Exception e) {
                errorCount++;
                log.error("ERROR processing record {}/{}: topic={}, partition={}, offset={}, error={}", 
                    successCount + errorCount, records.size(), record.topic(), record.kafkaPartition(), record.kafkaOffset(), e.getMessage());
                log.error("Record processing failed with exception:", e);
                throw e;
            }
        }
        
        log.info("Batch processing completed: {} successful, {} errors", successCount, errorCount);
    }

    private void processFhirRecord(SinkRecord record) {
        log.debug("Processing record: topic={}, partition={}, offset={}", 
            record.topic(), record.kafkaPartition(), record.kafkaOffset());
        
        String fhirResource = (String) record.value();
        if (fhirResource == null || fhirResource.trim().isEmpty()) {
            log.warn("Skipping empty or null FHIR resource at offset {}", record.kafkaOffset());
            return;
        }
        
        log.debug("Sending FHIR resource to server: {} chars, offset {}", 
            fhirResource.length(), record.kafkaOffset());
        
        try {
            fhirClient.sendFhirResource(fhirResource);
            log.debug("Successfully sent FHIR resource from offset {}", record.kafkaOffset());
        } catch (Exception e) {
            log.error("Failed to send FHIR resource from offset {}: {}", record.kafkaOffset(), e.getMessage());
            throw e;
        }
    }

    @Override
    public void flush(Map<TopicPartition, OffsetAndMetadata> currentOffsets) {
        log.debug("Flushing offsets: {}", currentOffsets);
    }

    @Override
    public void stop() {
        log.info("Stopping FHIR Secure Sink Task");
        if (fhirClient != null) {
            fhirClient.close();
        }
        if (authClient != null) {
            authClient.close();
        }
    }
}