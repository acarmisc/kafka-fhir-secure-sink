# Maven Central Publishing Setup

This document explains how to set up the GitHub Actions workflow to automatically publish this Kafka FHIR Secure Sink Connector to Maven Central.

## Prerequisites

1. **Maven Central Account**: You need a Sonatype account for Maven Central publishing
2. **GPG Key**: Required for signing artifacts
3. **GitHub Repository Secrets**: Configure the required secrets in your GitHub repository

## Step 1: Create Maven Central Account

1. Go to [https://central.sonatype.com/](https://central.sonatype.com/)
2. Sign up for an account using your GitHub account
3. Verify your namespace `io.github.acarmisc` (this should be automatic for GitHub-based namespaces)

## Step 2: Generate GPG Key

Generate a GPG key pair for signing your artifacts:

```bash
# Generate a new GPG key
gpg --gen-key

# List your keys to get the key ID
gpg --list-secret-keys --keyid-format LONG

# Export your private key (replace KEY_ID with your actual key ID)
gpg --armor --export-secret-keys KEY_ID > private-key.asc

# Export your public key
gpg --armor --export KEY_ID > public-key.asc
```

Upload your public key to key servers:
```bash
# Upload to multiple key servers
gpg --keyserver keyserver.ubuntu.com --send-keys KEY_ID
gpg --keyserver keys.openpgp.org --send-keys KEY_ID
gpg --keyserver pgp.mit.edu --send-keys KEY_ID
```

## Step 3: Configure GitHub Secrets

In your GitHub repository, go to Settings → Secrets and variables → Actions, and add these secrets:

### Required Secrets

| Secret Name | Description | Example/Notes |
|-------------|-------------|---------------|
| `MAVEN_CENTRAL_USERNAME` | Your Sonatype username | Your Sonatype account username |
| `MAVEN_CENTRAL_TOKEN` | Your Sonatype token | Generate from [https://central.sonatype.com/account](https://central.sonatype.com/account) |
| `MAVEN_GPG_PRIVATE_KEY` | Your GPG private key | Content of `private-key.asc` (entire file including headers) |
| `MAVEN_GPG_PASSPHRASE` | Your GPG key passphrase | The passphrase you used when creating the GPG key |

### How to Get Your Sonatype Token

1. Log in to [https://central.sonatype.com/](https://central.sonatype.com/)
2. Go to your account settings
3. Click on "Generate User Token"
4. Copy the username and password - use these as `MAVEN_CENTRAL_USERNAME` and `MAVEN_CENTRAL_TOKEN`

## Step 4: Publishing Process

### Automatic Publishing (Recommended)

The workflow will automatically publish when you create a GitHub release or push a tag:

1. **Create a Git tag**:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

2. **Create a GitHub Release**:
   - Go to your repository on GitHub
   - Click "Releases" → "Create a new release"
   - Choose the tag you created
   - Add release notes
   - Click "Publish release"

### Manual Publishing

You can also trigger publishing manually:

1. Go to Actions tab in your GitHub repository
2. Select "Publish to Maven Central" workflow
3. Click "Run workflow"
4. Optionally specify a version number

## Step 5: Verify Publication

After successful publication:

1. Check [Maven Central Search](https://central.sonatype.com/search?q=io.github.acarmisc) for your artifact
2. Your artifact will be available at: `https://central.sonatype.com/artifact/io.github.acarmisc/kafka-fhir-secure-sink`

## Usage in Other Projects

Once published, others can use your connector in their projects:

### Maven
```xml
<dependency>
    <groupId>io.github.acarmisc</groupId>
    <artifactId>kafka-fhir-secure-sink</artifactId>
    <version>1.0.0</version>
</dependency>
```

### Gradle
```groovy
implementation 'io.github.acarmisc:kafka-fhir-secure-sink:1.0.0'
```

## Troubleshooting

### Common Issues

1. **GPG Signing Fails**
   - Ensure your GPG private key is correctly formatted in the secret
   - Check that the passphrase is correct
   - Verify the key hasn't expired

2. **Authentication Fails**
   - Double-check your Sonatype username and token
   - Ensure the token has sufficient permissions

3. **Namespace Issues**
   - Verify your namespace `io.github.acarmisc` is approved in Sonatype
   - For GitHub-based namespaces, this should be automatic

4. **Upload Fails**
   - Check that all required metadata is present in pom.xml
   - Ensure sources and javadoc jars are being generated

### Getting Help

- Check the GitHub Actions logs for detailed error messages
- Consult the [Sonatype Documentation](https://central.sonatype.org/publish/)
- Review the [Maven Central Publishing Guide](https://central.sonatype.org/publish/publish-guide/)

## Security Notes

- Never commit GPG private keys or tokens to your repository
- Use GitHub Secrets for all sensitive information
- Regularly rotate your tokens and keys
- Monitor your published artifacts for any unauthorized changes

## Workflow Features

The GitHub Actions workflow includes:

- **Multi-JDK Testing**: Tests against Java 11, 17, and 21
- **Security Scanning**: OWASP dependency check
- **Integration Testing**: Tests with real Kafka infrastructure
- **Automatic Versioning**: Extracts version from Git tags
- **Release Creation**: Automatically creates GitHub releases
- **Artifact Upload**: Uploads JARs to both Maven Central and GitHub Releases