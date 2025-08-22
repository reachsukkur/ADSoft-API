# ADSoft API Certificate Installation Script
# This script automates the installation of SSL certificates for the ADSoft API

param(
    [Parameter(Mandatory=$true, HelpMessage="Path to the PFX certificate file")]
    [string]$CertificatePath,
    
    [Parameter(Mandatory=$true, HelpMessage="Password for the PFX certificate")]
    [string]$CertificatePassword,
    
    [Parameter(HelpMessage="Path to appsettings.json file")]
    [string]$ConfigPath = ".\appsettings.json",
    
    [Parameter(HelpMessage="Domain name for the certificate")]
    [string]$DomainName,
    
    [switch]$SkipFirewall,
    
    [switch]$TestAfterInstall
)

Write-Host "=== ADSoft API Certificate Installation ===" -ForegroundColor Cyan
Write-Host ""

# Check if running as administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "✗ This script requires Administrator privileges." -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    exit 1
}

try {
    # Validate certificate file exists
    if (-not (Test-Path $CertificatePath)) {
        throw "Certificate file not found: $CertificatePath"
    }

    # Validate config file exists
    if (-not (Test-Path $ConfigPath)) {
        throw "Configuration file not found: $ConfigPath"
    }

    Write-Host "1. Installing certificate..." -ForegroundColor Yellow
    
    # Import certificate
    $securePassword = ConvertTo-SecureString $CertificatePassword -AsPlainText -Force
    $cert = Import-PfxCertificate -FilePath $CertificatePath `
        -CertStoreLocation Cert:\LocalMachine\My `
        -Password $securePassword

    Write-Host "   ✓ Certificate imported successfully" -ForegroundColor Green
    Write-Host "     Thumbprint: $($cert.Thumbprint)" -ForegroundColor Gray
    Write-Host "     Subject: $($cert.Subject)" -ForegroundColor Gray
    Write-Host "     Expires: $($cert.NotAfter)" -ForegroundColor Gray
    Write-Host ""

    # Extract domain name from certificate if not provided
    if (-not $DomainName) {
        $DomainName = $cert.Subject.Split(',')[0].Replace('CN=', '').Trim()
        Write-Host "   Using domain from certificate: $DomainName" -ForegroundColor Gray
    }

    Write-Host "2. Updating configuration..." -ForegroundColor Yellow
    
    # Read current configuration
    $configContent = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    
    # Update URLs if needed
    if (-not $configContent.Urls) {
        $configContent | Add-Member -Name "Urls" -Value "http://0.0.0.0:5000;https://0.0.0.0:5001" -Force
    }
    
    # Add or update Kestrel configuration
    $kestrelConfig = @{
        Endpoints = @{
            Http = @{ 
                Url = "http://0.0.0.0:5000" 
            }
            Https = @{
                Url = "https://0.0.0.0:5001"
                Certificate = @{
                    Subject = $DomainName
                    Store = "My"
                    Location = "LocalMachine"
                    AllowInvalid = $false
                }
            }
        }
    }
    
    $configContent | Add-Member -Name "Kestrel" -Value $kestrelConfig -Force
    
    # Save updated configuration
    $configContent | ConvertTo-Json -Depth 6 | Set-Content $ConfigPath
    Write-Host "   ✓ Configuration updated" -ForegroundColor Green
    Write-Host ""

    # Configure firewall rules
    if (-not $SkipFirewall) {
        Write-Host "3. Configuring Windows Firewall..." -ForegroundColor Yellow
        
        try {
            # Check if rules already exist
            $httpRule = Get-NetFirewallRule -DisplayName "ADSoft API HTTP" -ErrorAction SilentlyContinue
            $httpsRule = Get-NetFirewallRule -DisplayName "ADSoft API HTTPS" -ErrorAction SilentlyContinue
            
            if (-not $httpRule) {
                New-NetFirewallRule -DisplayName "ADSoft API HTTP" `
                    -Direction Inbound `
                    -LocalPort 5000 `
                    -Protocol TCP `
                    -Action Allow | Out-Null
                Write-Host "   ✓ HTTP firewall rule created" -ForegroundColor Green
            } else {
                Write-Host "   ✓ HTTP firewall rule already exists" -ForegroundColor Green
            }
            
            if (-not $httpsRule) {
                New-NetFirewallRule -DisplayName "ADSoft API HTTPS" `
                    -Direction Inbound `
                    -LocalPort 5001 `
                    -Protocol TCP `
                    -Action Allow | Out-Null
                Write-Host "   ✓ HTTPS firewall rule created" -ForegroundColor Green
            } else {
                Write-Host "   ✓ HTTPS firewall rule already exists" -ForegroundColor Green
            }
        }
        catch {
            Write-Host "   ⚠ Warning: Could not configure firewall rules: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        Write-Host ""
    }

    # Grant permissions to certificate private key
    Write-Host "4. Configuring certificate permissions..." -ForegroundColor Yellow
    try {
        $rsaCert = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($cert)
        if ($rsaCert -and $rsaCert.Key) {
            $keyPath = "C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys\$($rsaCert.Key.UniqueName)"
            if (Test-Path $keyPath) {
                icacls $keyPath /grant "IIS_IUSRS:(F)" /grant "NETWORK SERVICE:(F)" | Out-Null
                Write-Host "   ✓ Certificate permissions configured" -ForegroundColor Green
            }
        }
    }
    catch {
        Write-Host "   ⚠ Warning: Could not configure certificate permissions: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    Write-Host ""

    # Test the installation
    if ($TestAfterInstall) {
        Write-Host "5. Testing installation..." -ForegroundColor Yellow
        
        # Wait a moment for any pending operations
        Start-Sleep -Seconds 2
        
        try {
            # Test certificate availability
            $installedCert = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Thumbprint -eq $cert.Thumbprint }
            if ($installedCert) {
                Write-Host "   ✓ Certificate is accessible" -ForegroundColor Green
            } else {
                throw "Certificate not found in store"
            }
            
            Write-Host "   ℹ Manual verification required:" -ForegroundColor Blue
            Write-Host "     - Start the ADSoft API application" -ForegroundColor Gray
            Write-Host "     - Test HTTPS endpoint: https://localhost:5001/swagger" -ForegroundColor Gray
            Write-Host "     - Test from other machines: https://$DomainName:5001/swagger" -ForegroundColor Gray
        }
        catch {
            Write-Host "   ✗ Test failed: $($_.Exception.Message)" -ForegroundColor Red
        }
        Write-Host ""
    }

    Write-Host "=== Installation Complete ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Start the ADSoft API application" -ForegroundColor White
    Write-Host "2. Verify HTTPS access: https://localhost:5001/swagger" -ForegroundColor White
    Write-Host "3. Test from client machines: https://$DomainName:5001/swagger" -ForegroundColor White
    Write-Host ""
    Write-Host "Configuration file updated: $ConfigPath" -ForegroundColor Gray
    Write-Host "Certificate thumbprint: $($cert.Thumbprint)" -ForegroundColor Gray

} catch {
    Write-Host ""
    Write-Host "✗ Installation failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting tips:" -ForegroundColor Yellow
    Write-Host "- Ensure the certificate file is valid and not corrupted" -ForegroundColor White
    Write-Host "- Verify the certificate password is correct" -ForegroundColor White
    Write-Host "- Check that you're running as Administrator" -ForegroundColor White
    Write-Host "- Ensure the certificate is not expired" -ForegroundColor White
    exit 1
}
