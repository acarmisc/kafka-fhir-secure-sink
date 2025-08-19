package com.healthcare.kafka.connect.fhir;

import com.healthcare.kafka.connect.fhir.config.FhirSecureSinkConnectorConfig;
import org.apache.kafka.common.config.ConfigDef;
import org.apache.kafka.connect.connector.Task;
import org.apache.kafka.connect.sink.SinkConnector;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * Kafka Connect sink connector for Azure Health Data Services FHIR API.
 * Provides secure OAuth2 authentication and reliable FHIR resource submission.
 */
public class FhirSecureSinkConnector extends SinkConnector {

    private static final Logger log = LoggerFactory.getLogger(FhirSecureSinkConnector.class);
    
    private FhirSecureSinkConnectorConfig config;

    @Override
    public String version() {
        return "1.0.0";
    }

    @Override
    public void start(Map<String, String> props) {
        log.info("Starting FHIR Secure Sink Connector");
        config = new FhirSecureSinkConnectorConfig(props);
        log.info("FHIR endpoint: {}", config.getFhirServerUrl());
    }

    @Override
    public Class<? extends Task> taskClass() {
        return FhirSecureSinkTask.class;
    }

    @Override
    public List<Map<String, String>> taskConfigs(int maxTasks) {
        List<Map<String, String>> taskConfigs = new ArrayList<>(maxTasks);
        Map<String, String> taskProps = config.originalsStrings();
        
        for (int i = 0; i < maxTasks; i++) {
            taskConfigs.add(taskProps);
        }
        
        return taskConfigs;
    }

    @Override
    public void stop() {
        log.info("Stopping FHIR Secure Sink Connector");
    }

    @Override
    public ConfigDef config() {
        return FhirSecureSinkConnectorConfig.configDef();
    }
}