#!/usr/bin/env python3

import json
import os
import time
import logging
from pathlib import Path
from kafka import KafkaProducer
from kafka.errors import KafkaError
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def create_producer():
    """Create Kafka producer with retry logic"""
    max_retries = 10
    retry_delay = 5
    
    for attempt in range(max_retries):
        try:
            producer = KafkaProducer(
                bootstrap_servers=os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9092'),
                value_serializer=lambda x: x.encode('utf-8') if isinstance(x, str) else json.dumps(x).encode('utf-8'),
                key_serializer=lambda x: x.encode('utf-8') if x else None,
                acks='all',
                retries=3,
                retry_backoff_ms=1000
            )
            logger.info("Successfully connected to Kafka")
            return producer
        except Exception as e:
            logger.warning(f"Attempt {attempt + 1}/{max_retries} failed: {e}")
            if attempt < max_retries - 1:
                time.sleep(retry_delay)
            else:
                raise

def load_fhir_samples(samples_path):
    """Load FHIR sample resources from files"""
    samples = []
    samples_dir = Path(samples_path)
    
    if not samples_dir.exists():
        logger.warning(f"Samples directory {samples_path} does not exist")
        return samples
    
    for file_path in samples_dir.glob('*.json'):
        try:
            with open(file_path, 'r') as f:
                content = f.read().strip()
                if content:
                    # Validate it's valid JSON
                    json.loads(content)
                    samples.append(content)
                    logger.info(f"Loaded FHIR sample: {file_path.name}")
        except Exception as e:
            logger.error(f"Error loading {file_path}: {e}")
    
    return samples

def generate_sample_fhir_resources():
    """Generate sample FHIR resources if no files are found"""
    return [
        {
            "resourceType": "Patient",
            "id": "example-patient-1",
            "identifier": [
                {
                    "system": "http://hospital.example.org/patients",
                    "value": "12345"
                }
            ],
            "name": [
                {
                    "use": "official",
                    "family": "Doe",
                    "given": ["John"]
                }
            ],
            "gender": "male",
            "birthDate": "1990-01-01",
            "active": True
        },
        {
            "resourceType": "Observation",
            "id": "example-observation-1",
            "status": "final",
            "category": [
                {
                    "coding": [
                        {
                            "system": "http://terminology.hl7.org/CodeSystem/observation-category",
                            "code": "vital-signs",
                            "display": "Vital Signs"
                        }
                    ]
                }
            ],
            "code": {
                "coding": [
                    {
                        "system": "http://loinc.org",
                        "code": "8867-4",
                        "display": "Heart rate"
                    }
                ]
            },
            "subject": {
                "reference": "Patient/example-patient-1"
            },
            "valueQuantity": {
                "value": 72,
                "unit": "beats/minute",
                "system": "http://unitsofmeasure.org",
                "code": "/min"
            }
        }
    ]

def main():
    topic = os.getenv('KAFKA_TOPIC', 'fhir-resources')
    samples_path = os.getenv('FHIR_SAMPLES_PATH', '/app/samples')
    send_interval = int(os.getenv('SEND_INTERVAL_SECONDS', '10'))
    
    # Azure Health Data Services configuration from .env
    azure_tenant_id = os.getenv('AZURE_TENANT_ID')
    azure_client_id = os.getenv('AZURE_CLIENT_ID') 
    azure_client_secret = os.getenv('AZURE_CLIENT_SECRET')
    azure_fhir_url = os.getenv('AZURE_FHIR_URL')
    azure_scope = os.getenv('AZURE_SCOPE', 'https://azurehealthcareapis.com/.default')
    
    logger.info(f"Starting FHIR producer for topic: {topic}")
    logger.info(f"Samples path: {samples_path}")
    logger.info(f"Send interval: {send_interval} seconds")
    logger.info(f"Azure FHIR URL: {azure_fhir_url}")
    logger.info(f"Azure Tenant ID: {azure_tenant_id}")
    
    producer = create_producer()
    
    # Load FHIR samples from files
    fhir_samples = load_fhir_samples(samples_path)
    
    # If no samples found, use generated ones
    if not fhir_samples:
        logger.info("No sample files found, using generated samples")
        generated_samples = generate_sample_fhir_resources()
        fhir_samples = [json.dumps(sample) for sample in generated_samples]
    
    logger.info(f"Loaded {len(fhir_samples)} FHIR samples")
    
    try:
        sample_index = 0
        while True:
            if not fhir_samples:
                logger.warning("No FHIR samples available")
                time.sleep(send_interval)
                continue
                
            # Get next sample (cycle through samples)
            fhir_resource = fhir_samples[sample_index % len(fhir_samples)]
            sample_index += 1
            
            try:
                # Send to Kafka
                future = producer.send(topic, value=fhir_resource)
                result = future.get(timeout=10)
                
                logger.info(f"Sent FHIR resource to {result.topic}:{result.partition}:{result.offset}")
                
            except KafkaError as e:
                logger.error(f"Failed to send FHIR resource: {e}")
            except Exception as e:
                logger.error(f"Unexpected error sending FHIR resource: {e}")
            
            time.sleep(send_interval)
            
    except KeyboardInterrupt:
        logger.info("Stopping FHIR producer...")
    finally:
        producer.close()
        logger.info("FHIR producer stopped")

if __name__ == "__main__":
    main()