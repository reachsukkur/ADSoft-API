# ADSoft API - Active Directory Integration API

A secure .NET 9.0 Web API that provides Active Directory integration with encrypted credential storage, JWT authentication, and custom attribute support.

## Features

- **Active Directory Integration**: Query user details and organizational units
- **Custom Attributes**: Support for Arabic display names and other custom AD attributes
- **Secure Authentication**: JWT-based authentication with API key validation
- **Encrypted Storage**: AES-256 encryption for sensitive configuration data
- **Configuration Management**: Tools for generating encryption keys and managing encrypted values
- **Comprehensive Logging**: Structured logging with Serilog
- **API Documentation**: Swagger/OpenAPI documentation

## Quick Start

### Prerequisites

- .NET 9.0 SDK
- Windows environment (for Active Directory integration)
- Active Directory domain access

### Installation

1. Clone the repository:
```bash
git clone https://github.com/reachsukkur/adsoft-api.git
cd adsoft-api
```

2. Configure the application:
```bash
# Copy example configuration
cp appsettings.json appsettings.Development.json
```

3. Generate encryption keys:
```bash
dotnet run
# Navigate to http://localhost:5000/swagger
# Use GET /api/configuration/generate-keys endpoint
```

4. Update `appsettings.Development.json` with your AD configuration and encryption keys.

5. Run the application:
```bash
dotnet run
```

The API will be available at:
- HTTP: http://localhost:5000/swagger
- HTTPS: https://localhost:5001/swagger

## Configuration

### Active Directory Settings

```json
{
  "ActiveDirectory": {
    "Domain": "your-domain.local",
    "EncryptedUsername": "encrypted-username-here",
    "EncryptedPassword": "encrypted-password-here",
    "Encryption": {
      "Key": "your-base64-encryption-key",
      "IV": "your-base64-iv"
    }
  }
}
```

### JWT Settings

```json
{
  "Jwt": {
    "Key": "your-secret-key-here",
    "Issuer": "https://your-api-domain.com",
    "Audience": "https://your-clients-domain.com",
    "ExpiryInMinutes": 60
  }
}
```

### API Keys

```json
{
  "ClientAuthentication": {
    "ApiKeys": {
      "client1": "your-api-key-1",
      "client2": "your-api-key-2"
    }
  }
}
```

## API Endpoints

### Authentication
- `POST /api/auth/login` - Get JWT token

### User Management
- `GET /api/aduser/{username}` - Get user details by username
- `GET /api/aduser/ou/{ouName}` - Get all users in an organizational unit

### Configuration Management
- `GET /api/configuration/generate-keys` - Generate new encryption keys
- `POST /api/configuration/encrypt` - Encrypt a configuration value
- `POST /api/configuration/decrypt` - Decrypt a configuration value

## Usage Examples

### Getting User Details

```bash
curl -X GET "http://localhost:5000/api/aduser/testuser" \
  -H "Authorization: Bearer your-jwt-token" \
  -H "X-API-Key: your-api-key"
```

### Getting Users from OU

```bash
curl -X GET "http://localhost:5000/api/aduser/ou/TestUsers" \
  -H "Authorization: Bearer your-jwt-token" \
  -H "X-API-Key: your-api-key"
```

### Encrypting Configuration Values

```bash
curl -X POST "http://localhost:5000/api/configuration/encrypt" \
  -H "Content-Type: application/json" \
  -d '{"value": "sensitive-data-here"}'
```

## Custom Active Directory Attributes

The API supports custom AD attributes. To add custom attributes:

1. **Extend AD Schema** (if needed):
   - Create new attributes in Active Directory Schema
   - Add attributes to User class

2. **Configure in Code**:
   The API automatically retrieves custom attributes and includes them in the `AdditionalAttributes` dictionary.

### Example: Adding Arabic Display Name

The API has built-in support for `displayNameAr` attribute:

```powershell
# Set Arabic name in AD
Set-ADUser -Identity "username" -Add @{
    'displayNameAr' = 'الاسم بالعربية'
}
```

## Deployment

### Self-Contained Deployment

Build a standalone executable:

```bash
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true
```

### Network Access Configuration

To allow access from other machines:

1. Update `appsettings.json`:
```json
{
  "Urls": "http://0.0.0.0:5000;https://0.0.0.0:5001"
}
```

2. Configure Windows Firewall:
```powershell
# Allow inbound connections
New-NetFirewallRule -DisplayName "ADSoft API HTTP" -Direction Inbound -LocalPort 5000 -Protocol TCP -Action Allow
New-NetFirewallRule -DisplayName "ADSoft API HTTPS" -Direction Inbound -LocalPort 5001 -Protocol TCP -Action Allow
```

### SSL Certificate Configuration for Production

For production deployment at client sites, you'll need to configure SSL certificates for HTTPS. Here are the different approaches:

#### Option 1: Using a Valid Domain Certificate

1. **Obtain a Certificate**:
   - Purchase from a Certificate Authority (CA) like Let's Encrypt, DigiCert, or GoDaddy
   - Ensure the certificate matches your domain name

2. **Install Certificate in Windows Certificate Store**:
   ```powershell
   # Import certificate to Local Machine Personal store
   Import-PfxCertificate -FilePath "C:\path\to\certificate.pfx" -CertStoreLocation Cert:\LocalMachine\My -Password (ConvertTo-SecureString "certificate-password" -AsPlainText -Force)
   ```

3. **Configure Certificate in appsettings.json**:
   ```json
   {
     "Kestrel": {
       "Endpoints": {
         "Http": {
           "Url": "http://0.0.0.0:5000"
         },
         "Https": {
           "Url": "https://0.0.0.0:5001",
           "Certificate": {
             "Subject": "your-domain.com",
             "Store": "My",
             "Location": "LocalMachine",
             "AllowInvalid": false
           }
         }
       }
     }
   }
   ```

#### Option 2: Using Certificate File with Password

If you have a .pfx certificate file:

```json
{
  "Kestrel": {
    "Endpoints": {
      "Http": {
        "Url": "http://0.0.0.0:5000"
      },
      "Https": {
        "Url": "https://0.0.0.0:5001",
        "Certificate": {
          "Path": "C:\\certificates\\your-certificate.pfx",
          "Password": "your-certificate-password"
        }
      }
    }
  }
}
```

#### Option 3: Self-Signed Certificate for Internal Use

For internal client networks where you can't get a domain certificate:

1. **Generate Self-Signed Certificate**:
   ```powershell
   # Create self-signed certificate
   $cert = New-SelfSignedCertificate -DnsName "api.company.local", "192.168.1.100" -CertStoreLocation "cert:\LocalMachine\My" -NotAfter (Get-Date).AddYears(2)
   
   # Export certificate for client trust
   Export-Certificate -Cert $cert -FilePath "C:\certificates\api-cert.crt"
   
   # Export with private key for server use
   $password = ConvertTo-SecureString "YourPassword123!" -AsPlainText -Force
   Export-PfxCertificate -Cert $cert -FilePath "C:\certificates\api-cert.pfx" -Password $password
   ```

2. **Configure in appsettings.json**:
   ```json
   {
     "Kestrel": {
       "Endpoints": {
         "Http": {
           "Url": "http://0.0.0.0:5000"
         },
         "Https": {
           "Url": "https://0.0.0.0:5001",
           "Certificate": {
             "Path": "C:\\certificates\\api-cert.pfx",
             "Password": "YourPassword123!"
           }
         }
       }
     }
   }
   ```

3. **Install Certificate on Client Machines**:
   ```powershell
   # Install the certificate as trusted root on client machines
   Import-Certificate -FilePath "C:\certificates\api-cert.crt" -CertStoreLocation Cert:\LocalMachine\Root
   ```

#### Option 4: Let's Encrypt Free Certificate

For public-facing APIs with domain names:

1. **Install Certbot** or use ACME client
2. **Generate Certificate**:
   ```bash
   certbot certonly --standalone -d your-api-domain.com
   ```
3. **Convert to PFX format**:
   ```bash
   openssl pkcs12 -export -out certificate.pfx -inkey privkey.pem -in cert.pem -certfile chain.pem
   ```

#### Certificate Deployment Script

Create a PowerShell script for easy certificate deployment:

```powershell
# deploy-certificate.ps1
param(
    [string]$CertificatePath,
    [string]$CertificatePassword,
    [string]$ApiConfigPath = ".\appsettings.json"
)

# Import certificate
$securePassword = ConvertTo-SecureString $CertificatePassword -AsPlainText -Force
$cert = Import-PfxCertificate -FilePath $CertificatePath -CertStoreLocation Cert:\LocalMachine\My -Password $securePassword

Write-Host "Certificate imported with thumbprint: $($cert.Thumbprint)"
Write-Host "Update your appsettings.json with the certificate configuration."
```

#### Testing HTTPS Configuration

After configuring certificates, test the HTTPS endpoint:

```powershell
# Test HTTPS endpoint
Invoke-RestMethod -Uri "https://your-server:5001/api/auth/login" -Method GET -SkipCertificateCheck

# Or use curl
curl -k https://your-server:5001/swagger
```

#### Certificate Best Practices

1. **Security**:
   - Store certificate passwords securely (use Azure Key Vault, Windows Credential Manager, or environment variables)
   - Use strong passwords for certificate files
   - Regularly rotate certificates before expiration

2. **Monitoring**:
   - Set up certificate expiration monitoring
   - Implement automated renewal for Let's Encrypt certificates

3. **Backup**:
   - Keep backup copies of certificates in secure storage
   - Document certificate installation procedures

4. **Access Control**:
   - Limit file system permissions on certificate files
   - Use service accounts with minimal required permissions

## Security Considerations

- **Encryption**: All sensitive configuration data is encrypted using AES-256
- **Authentication**: JWT tokens for API authentication
- **Authorization**: API key validation for client access
- **HTTPS**: SSL/TLS encryption for data in transit
- **Logging**: Comprehensive audit logging without exposing sensitive data

## Development

### Project Structure

```
ADSoft/
├── Controllers/          # API controllers
├── Services/            # Business logic services
├── Models/              # Data models and DTOs
├── Helpers/             # Utility classes
├── Properties/          # Launch settings
├── appsettings.json     # Configuration
└── Program.cs           # Application entry point
```

### Adding New Features

1. **New API Endpoints**: Add controllers in `Controllers/` folder
2. **Business Logic**: Add services in `Services/` folder
3. **Data Models**: Add models in `Models/` folder
4. **Utilities**: Add helpers in `Helpers/` folder

## Testing

### Prerequisites for Testing

1. Set up a test Active Directory environment
2. Configure test users and organizational units
3. Update configuration with test credentials

### Running Tests

```bash
# Unit tests (when available)
dotnet test

# Integration testing via Swagger UI
# Navigate to http://localhost:5000/swagger
```

## Troubleshooting

### Common Issues

1. **AD Connection Errors**:
   - Verify domain connectivity
   - Check credentials
   - Ensure proper DNS resolution

2. **Encryption Errors**:
   - Verify encryption keys are properly set
   - Check key format (must be valid Base64)

3. **Authentication Failures**:
   - Verify JWT configuration
   - Check API key validity
   - Ensure proper headers are sent

### Logging

The application uses Serilog for structured logging. Logs are written to:
- Console (during development)
- Files in `Logs/` directory

Log levels can be configured in `appsettings.json`.

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Commit your changes: `git commit -am 'Add some feature'`
4. Push to the branch: `git push origin feature/your-feature`
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review the logs for error details
3. Open an issue on GitHub

## Changelog

### Version 1.0.0
- Initial release
- Active Directory integration
- JWT authentication
- Configuration management tools
- Custom attribute support
- Encrypted credential storage
