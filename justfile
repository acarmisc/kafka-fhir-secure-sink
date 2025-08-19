# Justfile for kafka-fhir-secure-sink

# Build the connector JAR
build:
    mvn clean package

# Copy the built JAR to the connectors directory
deploy:
    cp target/kafka-fhir-secure-sink-1.0.0-SNAPSHOT-jar-with-dependencies.jar sample/connectors/

# Create the connector using the configuration file
create-connector:
    curl -X POST http://localhost:8083/connectors \
      -H "Content-Type: application/json" \
      -d @sample/config/fhir-sink-connector.json

# Show available recipes
default:
    @just --list