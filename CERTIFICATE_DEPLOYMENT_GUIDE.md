# SSL Certificate Deployment Guide for ADSoft API

This guide provides step-by-step instructions for deploying SSL certificates with the ADSoft API at client sites.

## Quick Reference

| Scenario | Certificate Type | Best For |
|----------|------------------|----------|
| Public API with domain | CA-issued (Let's Encrypt, commercial) | Production with internet access |
| Internal corporate network | Self-signed | Internal networks, development |
| Company domain | Commercial CA certificate | Enterprise production |

## Option 1: Commercial Certificate (Recommended for Production)

### Step 1: Obtain Certificate
1. Purchase SSL certificate from a trusted CA (GoDaddy, DigiCert, etc.)
2. Generate CSR (Certificate Signing Request) if required
3. Download the certificate in PFX format

### Step 2: Install Certificate
```powershell
# Import certificate to Windows Certificate Store
Import-PfxCertificate -FilePath "C:\certificates\your-cert.pfx" `
    -CertStoreLocation Cert:\LocalMachine\My `
    -Password (Read-Host "Enter certificate password" -AsSecureString)
```

### Step 3: Configure API
Update `appsettings.json`:
```json
{
  "Urls": "http://0.0.0.0:5000;https://0.0.0.0:5001",
  "Kestrel": {
    "Endpoints": {
      "Http": {
        "Url": "http://0.0.0.0:5000"
      },
      "Https": {
        "Url": "https://0.0.0.0:5001",
        "Certificate": {
          "Subject": "api.yourcompany.com",
          "Store": "My",
          "Location": "LocalMachine"
        }
      }
    }
  }
}
```

## Option 2: Self-Signed Certificate (Internal Networks)

### Step 1: Generate Certificate
```powershell
# Create self-signed certificate
$cert = New-SelfSignedCertificate `
    -DnsName "api.company.local", "192.168.1.100", "server-name" `
    -CertStoreLocation "cert:\LocalMachine\My" `
    -NotAfter (Get-Date).AddYears(2) `
    -KeyAlgorithm RSA `
    -KeyLength 2048

# Export for distribution to clients
Export-Certificate -Cert $cert -FilePath "C:\certificates\api-public.crt"

# Export with private key for server
$password = Read-Host "Enter password for PFX file" -AsSecureString
Export-PfxCertificate -Cert $cert -FilePath "C:\certificates\api-server.pfx" -Password $password
```

### Step 2: Configure API
```json
{
  "Urls": "http://0.0.0.0:5000;https://0.0.0.0:5001",
  "Kestrel": {
    "Endpoints": {
      "Http": {
        "Url": "http://0.0.0.0:5000"
      },
      "Https": {
        "Url": "https://0.0.0.0:5001",
        "Certificate": {
          "Path": "C:\\certificates\\api-server.pfx",
          "Password": "your-certificate-password"
        }
      }
    }
  }
}
```

### Step 3: Distribute to Client Machines
```powershell
# On each client machine that will access the API
Import-Certificate -FilePath "C:\certificates\api-public.crt" `
    -CertStoreLocation Cert:\LocalMachine\Root
```

## Option 3: Let's Encrypt (Free, Domain Required)

### Prerequisites
- Public domain name pointing to your server
- Port 80 accessible from internet (for validation)

### Step 1: Install Certbot
```powershell
# Download and install Certbot for Windows
# https://certbot.eff.org/instructions?ws=other&os=windows
```

### Step 2: Generate Certificate
```powershell
# Stop IIS or other web servers on port 80
certbot certonly --standalone -d api.yourcompany.com

# Certificate will be saved to: C:\Certbot\live\api.yourcompany.com\
```

### Step 3: Convert to PFX
```powershell
# Convert Let's Encrypt files to PFX format
openssl pkcs12 -export -out api-cert.pfx `
    -inkey "C:\Certbot\live\api.yourcompany.com\privkey.pem" `
    -in "C:\Certbot\live\api.yourcompany.com\cert.pem" `
    -certfile "C:\Certbot\live\api.yourcompany.com\chain.pem"
```

### Step 4: Setup Auto-Renewal
```powershell
# Create scheduled task for renewal
schtasks /create /tn "Certbot Renewal" /tr "certbot renew --quiet" /sc daily /st 02:00
```

## Deployment Scripts

### Certificate Installation Script
Create `install-certificate.ps1`:
```powershell
param(
    [Parameter(Mandatory=$true)]
    [string]$CertificatePath,
    
    [Parameter(Mandatory=$true)]
    [string]$CertificatePassword,
    
    [string]$ConfigPath = ".\appsettings.json"
)

try {
    # Import certificate
    $securePassword = ConvertTo-SecureString $CertificatePassword -AsPlainText -Force
    $cert = Import-PfxCertificate -FilePath $CertificatePath `
        -CertStoreLocation Cert:\LocalMachine\My `
        -Password $securePassword
    
    Write-Host "✓ Certificate imported successfully" -ForegroundColor Green
    Write-Host "  Thumbprint: $($cert.Thumbprint)" -ForegroundColor Cyan
    Write-Host "  Subject: $($cert.Subject)" -ForegroundColor Cyan
    Write-Host "  Expires: $($cert.NotAfter)" -ForegroundColor Cyan
    
    # Update appsettings.json
    $config = Get-Content $ConfigPath | ConvertFrom-Json
    
    # Add Kestrel configuration
    $config | Add-Member -Name "Kestrel" -Value @{
        Endpoints = @{
            Http = @{ Url = "http://0.0.0.0:5000" }
            Https = @{
                Url = "https://0.0.0.0:5001"
                Certificate = @{
                    Subject = $cert.Subject.Split(',')[0].Replace('CN=', '')
                    Store = "My"
                    Location = "LocalMachine"
                }
            }
        }
    } -Force
    
    $config | ConvertTo-Json -Depth 5 | Set-Content $ConfigPath
    Write-Host "✓ Configuration updated" -ForegroundColor Green
    
} catch {
    Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
```

### Certificate Validation Script
Create `validate-certificate.ps1`:
```powershell
param(
    [string]$ServerUrl = "https://localhost:5001",
    [switch]$SkipCertificateCheck
)

try {
    Write-Host "Testing HTTPS endpoint: $ServerUrl" -ForegroundColor Yellow
    
    if ($SkipCertificateCheck) {
        # Skip certificate validation for self-signed certificates
        add-type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
        return true;
    }
}
"@
        [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
    }
    
    $response = Invoke-RestMethod -Uri "$ServerUrl/swagger/index.html" -Method GET
    Write-Host "✓ HTTPS endpoint is accessible" -ForegroundColor Green
    
} catch {
    Write-Host "✗ HTTPS test failed: $($_.Exception.Message)" -ForegroundColor Red
    
    # Provide troubleshooting hints
    Write-Host "`nTroubleshooting tips:" -ForegroundColor Yellow
    Write-Host "1. Check if the certificate is properly installed" -ForegroundColor White
    Write-Host "2. Verify the certificate subject matches the server name" -ForegroundColor White
    Write-Host "3. Ensure the certificate is not expired" -ForegroundColor White
    Write-Host "4. Check Windows Firewall rules for port 5001" -ForegroundColor White
}
```

## Firewall Configuration

```powershell
# Allow HTTPS traffic
New-NetFirewallRule -DisplayName "ADSoft API HTTPS" `
    -Direction Inbound `
    -LocalPort 5001 `
    -Protocol TCP `
    -Action Allow

# Allow HTTP traffic (if needed)
New-NetFirewallRule -DisplayName "ADSoft API HTTP" `
    -Direction Inbound `
    -LocalPort 5000 `
    -Protocol TCP `
    -Action Allow
```

## Testing the Deployment

### 1. Local Testing
```powershell
# Test HTTP endpoint
curl http://localhost:5000/swagger

# Test HTTPS endpoint
curl -k https://localhost:5001/swagger
```

### 2. Network Testing
```powershell
# From another machine on the network
curl -k https://192.168.1.100:5001/swagger

# Test with actual domain name
curl https://api.company.com:5001/swagger
```

### 3. Certificate Validation
```powershell
# Check certificate details
Get-ChildItem Cert:\LocalMachine\My | Where-Object {$_.Subject -like "*api*"}

# Validate certificate chain
certlm.msc  # Open Certificate Manager
```

## Troubleshooting

### Common Issues

#### "Certificate not found" Error
```powershell
# List all certificates
Get-ChildItem Cert:\LocalMachine\My

# Check certificate subject name in appsettings.json
# Ensure it matches exactly (case-sensitive)
```

#### "Certificate validation failed" Error
```powershell
# For self-signed certificates, install the root certificate
Import-Certificate -FilePath "certificate.crt" -CertStoreLocation Cert:\LocalMachine\Root
```

#### "Access denied" Error
```powershell
# Grant IIS_IUSRS permission to private key
$cert = Get-ChildItem Cert:\LocalMachine\My | Where-Object {$_.Subject -like "*yourapi*"}
$rsaCert = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($cert)
$fileName = $rsaCert.key.UniqueName
icacls C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys\$fileName /grant IIS_IUSRS:F
```

## Security Best Practices

1. **Password Security**
   - Use strong passwords for certificate files
   - Store passwords in Windows Credential Manager or Azure Key Vault
   - Never commit passwords to source control

2. **Certificate Management**
   - Set up expiration monitoring
   - Implement automated renewal processes
   - Keep backup copies in secure storage

3. **Access Control**
   - Limit certificate file permissions
   - Use service accounts with minimal privileges
   - Regularly audit certificate access

4. **Network Security**
   - Use firewall rules to restrict access
   - Consider using VPN for internal APIs
   - Implement rate limiting and DDoS protection

## Maintenance

### Certificate Renewal Checklist
- [ ] Monitor certificate expiration dates
- [ ] Test renewal process in staging environment
- [ ] Schedule maintenance windows for certificate updates
- [ ] Update monitoring systems with new certificate details
- [ ] Verify all client applications still function after renewal

### Backup Procedures
- [ ] Export certificates with private keys
- [ ] Store backups in secure, encrypted storage
- [ ] Document recovery procedures
- [ ] Test certificate restoration process

## Support

For certificate-related issues:
1. Check Windows Event Logs (System, Application, Security)
2. Review ADSoft API logs in the `Logs/` directory
3. Use certificate management tools (certlm.msc, certmgr.msc)
4. Validate network connectivity and firewall rules
