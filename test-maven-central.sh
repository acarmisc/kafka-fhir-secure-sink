#!/bin/bash

set -e

echo "🔍 Testing Maven Central Publishing Process"
echo "=========================================="

echo
echo "📋 Step 1: Validating POM configuration..."
if grep -q "central-publishing-maven-plugin" pom.xml; then
    echo "✅ Central Publishing Maven Plugin found"
else
    echo "❌ Central Publishing Maven Plugin NOT found"
    exit 1
fi

if grep -q "maven-gpg-plugin" pom.xml; then
    echo "✅ Maven GPG Plugin found"
else
    echo "❌ Maven GPG Plugin NOT found"
    exit 1
fi

echo
echo "🔧 Step 2: Testing build without signing..."
mvn clean verify -DskipTests -Dsign=false -q

if [ $? -eq 0 ]; then
    echo "✅ Build successful"
else
    echo "❌ Build failed"
    exit 1
fi

echo
echo "📦 Step 3: Checking generated artifacts..."
if ls target/kafka-fhir-secure-sink-*.jar 1> /dev/null 2>&1; then
    echo "✅ Main JAR created"
else
    echo "❌ Main JAR NOT found"
    exit 1
fi

if ls target/kafka-fhir-secure-sink-*-sources.jar 1> /dev/null 2>&1; then
    echo "✅ Sources JAR created"
else
    echo "❌ Sources JAR NOT found"
    exit 1
fi

if ls target/kafka-fhir-secure-sink-*-javadoc.jar 1> /dev/null 2>&1; then
    echo "✅ Javadoc JAR created"
else
    echo "❌ Javadoc JAR NOT found"
    exit 1
fi

if ls target/kafka-fhir-secure-sink-*-jar-with-dependencies.jar 1> /dev/null 2>&1; then
    echo "✅ Fat JAR created"
else
    echo "❌ Fat JAR NOT found"
    exit 1
fi

echo
echo "🏷️  Step 4: Checking POM metadata for Maven Central..."

# Check required metadata
required_fields=("groupId" "artifactId" "version" "name" "description" "url" "licenses" "developers" "scm")
for field in "${required_fields[@]}"; do
    if grep -q "<$field" pom.xml; then
        echo "✅ $field is present"
    else
        echo "❌ $field is MISSING"
        exit 1
    fi
done

echo
echo "🎯 Step 5: Testing Central Publishing plugin..."
echo "Note: This will only work with proper credentials and GPG setup"

# Check if we can at least validate the plugin
if mvn central:help -q 2>/dev/null; then
    echo "✅ Central Publishing plugin is accessible"
else
    echo "⚠️  Central Publishing plugin validation skipped (plugin not in local repo)"
fi

echo
echo "✅ All validation steps passed!"
echo "🚀 The build is ready for Maven Central publishing."
echo
echo "Next steps to complete the setup:"
echo "1. Set up repository secrets in GitHub:"
echo "   - MAVEN_CENTRAL_USERNAME"
echo "   - MAVEN_CENTRAL_TOKEN"
echo "   - MAVEN_GPG_PRIVATE_KEY"
echo "   - MAVEN_GPG_PASSPHRASE"
echo "2. Create a tag and push to trigger the publish workflow"
echo "   git tag v1.0.8"
echo "   git push origin v1.0.8"