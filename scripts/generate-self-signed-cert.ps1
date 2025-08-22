# ADSoft API Self-Signed Certificate Generator
# This script creates self-signed certificates for internal use

param(
    [Parameter(HelpMessage="Primary domain name for the certificate")]
    [string]$DomainName = "api.company.local",
    
    [Parameter(HelpMessage="Additional DNS names (comma-separated)")]
    [string]$AdditionalDnsNames = "",
    
    [Parameter(HelpMessage="IP addresses to include (comma-separated)")]
    [string]$IpAddresses = "",
    
    [Parameter(HelpMessage="Certificate validity period in years")]
    [int]$ValidityYears = 2,
    
    [Parameter(HelpMessage="Output directory for certificate files")]
    [string]$OutputPath = ".\certificates",
    
    [Parameter(HelpMessage="Password for the PFX file")]
    [string]$PfxPassword,
    
    [switch]$InstallToStore,
    
    [switch]$CreateClientCert
)

Write-Host "=== ADSoft API Self-Signed Certificate Generator ===" -ForegroundColor Cyan
Write-Host ""

# Check if running as administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "⚠ Warning: Not running as Administrator." -ForegroundColor Yellow
    Write-Host "  Certificate installation may fail if -InstallToStore is used." -ForegroundColor Gray
    Write-Host ""
}

# Create output directory
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    Write-Host "Created output directory: $OutputPath" -ForegroundColor Green
}

# Generate PFX password if not provided
if (-not $PfxPassword) {
    $PfxPassword = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 16 | ForEach-Object {[char]$_})
    Write-Host "Generated PFX password: $PfxPassword" -ForegroundColor Yellow
    Write-Host "Please save this password securely!" -ForegroundColor Red
    Write-Host ""
}

# Build DNS names list
$dnsNames = @($DomainName)

# Add localhost variations
$dnsNames += "localhost"
$dnsNames += $env:COMPUTERNAME

# Add additional DNS names
if ($AdditionalDnsNames) {
    $additionalNames = $AdditionalDnsNames.Split(',') | ForEach-Object { $_.Trim() }
    $dnsNames += $additionalNames
}

# Add IP addresses if provided
if ($IpAddresses) {
    $ipList = $IpAddresses.Split(',') | ForEach-Object { $_.Trim() }
    $dnsNames += $ipList
}

# Get local IP addresses
try {
    $localIPs = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { 
        $_.AddressState -eq "Preferred" -and 
        $_.PrefixOrigin -eq "Manual" -or $_.PrefixOrigin -eq "Dhcp"
    } | Select-Object -ExpandProperty IPAddress
    
    foreach ($ip in $localIPs) {
        if ($ip -ne "127.0.0.1" -and $dnsNames -notcontains $ip) {
            $dnsNames += $ip
        }
    }
} catch {
    Write-Host "⚠ Could not automatically detect IP addresses" -ForegroundColor Yellow
}

Write-Host "Certificate will be created for the following names:" -ForegroundColor Cyan
foreach ($name in $dnsNames) {
    Write-Host "  • $name" -ForegroundColor Gray
}
Write-Host ""

try {
    Write-Host "1. Generating self-signed certificate..." -ForegroundColor Yellow
    
    # Create the certificate
    $cert = New-SelfSignedCertificate `
        -DnsName $dnsNames `
        -CertStoreLocation "cert:\LocalMachine\My" `
        -NotAfter (Get-Date).AddYears($ValidityYears) `
        -KeyAlgorithm RSA `
        -KeyLength 2048 `
        -HashAlgorithm SHA256 `
        -KeyUsage CertSign, CRLSign, DigitalSignature, KeyEncipherment `
        -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.1") `
        -Subject "CN=$DomainName, O=ADSoft API, OU=IT Department"

    Write-Host "   ✓ Certificate generated successfully" -ForegroundColor Green
    Write-Host "     Subject: $($cert.Subject)" -ForegroundColor Gray
    Write-Host "     Thumbprint: $($cert.Thumbprint)" -ForegroundColor Gray
    Write-Host "     Valid Until: $($cert.NotAfter)" -ForegroundColor Gray
    Write-Host ""

    Write-Host "2. Exporting certificate files..." -ForegroundColor Yellow
    
    # Export public certificate (for client distribution)
    $publicCertPath = Join-Path $OutputPath "adsoft-api-public.crt"
    Export-Certificate -Cert $cert -FilePath $publicCertPath | Out-Null
    Write-Host "   ✓ Public certificate: $publicCertPath" -ForegroundColor Green
    
    # Export PFX with private key (for server installation)
    $pfxPath = Join-Path $OutputPath "adsoft-api-server.pfx"
    $securePassword = ConvertTo-SecureString $PfxPassword -AsPlainText -Force
    Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $securePassword | Out-Null
    Write-Host "   ✓ PFX certificate: $pfxPath" -ForegroundColor Green
    
    # Export certificate details
    $detailsPath = Join-Path $OutputPath "certificate-details.txt"
    $details = @"
ADSoft API Certificate Details
==============================

Certificate Information:
- Subject: $($cert.Subject)
- Thumbprint: $($cert.Thumbprint)
- Serial Number: $($cert.SerialNumber)
- Valid From: $($cert.NotBefore)
- Valid Until: $($cert.NotAfter)
- Key Algorithm: $($cert.PublicKey.Key.KeySize)-bit $($cert.PublicKey.Oid.FriendlyName)

DNS Names:
$($dnsNames | ForEach-Object { "- $_" } | Out-String)

Files Generated:
- Public Certificate: adsoft-api-public.crt
- Server PFX: adsoft-api-server.pfx
- PFX Password: $PfxPassword

Installation Instructions:
1. Copy adsoft-api-server.pfx to the API server
2. Run: .\scripts\install-certificate.ps1 -CertificatePath ".\certificates\adsoft-api-server.pfx" -CertificatePassword "$PfxPassword"
3. Distribute adsoft-api-public.crt to client machines
4. On client machines, import the public certificate to Trusted Root store

Client Installation Command:
Import-Certificate -FilePath "adsoft-api-public.crt" -CertStoreLocation Cert:\LocalMachine\Root

Generated on: $(Get-Date)
"@
    
    $details | Out-File -FilePath $detailsPath -Encoding UTF8
    Write-Host "   ✓ Certificate details: $detailsPath" -ForegroundColor Green
    Write-Host ""

    # Create installation script
    $installScriptPath = Join-Path $OutputPath "install-certificate.cmd"
    $installScript = @"
@echo off
echo Installing ADSoft API Certificate...
echo.

REM Check for administrator privileges
net session >nul 2>&1
if %errorLevel% == 0 (
    echo Running as Administrator - OK
) else (
    echo This script requires Administrator privileges.
    echo Please run as Administrator.
    pause
    exit /b 1
)

echo Installing server certificate...
powershell -ExecutionPolicy Bypass -File "..\scripts\install-certificate.ps1" -CertificatePath ".\adsoft-api-server.pfx" -CertificatePassword "$PfxPassword" -TestAfterInstall

echo.
echo Certificate installation completed.
echo Check the output above for any errors.
pause
"@
    
    $installScript | Out-File -FilePath $installScriptPath -Encoding ASCII
    Write-Host "   ✓ Installation script: $installScriptPath" -ForegroundColor Green
    Write-Host ""

    # Remove from store if not installing
    if (-not $InstallToStore) {
        Write-Host "3. Removing temporary certificate from store..." -ForegroundColor Yellow
        Remove-Item -Path "Cert:\LocalMachine\My\$($cert.Thumbprint)" -Force
        Write-Host "   ✓ Temporary certificate removed" -ForegroundColor Green
        Write-Host "     (Use install-certificate.ps1 to install properly)" -ForegroundColor Gray
    } else {
        Write-Host "3. Certificate installed to Local Machine store" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "=== Certificate Generation Complete ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "Files created in $OutputPath`:" -ForegroundColor Cyan
    Write-Host "• adsoft-api-public.crt    - For client machines (install to Trusted Root)" -ForegroundColor White
    Write-Host "• adsoft-api-server.pfx    - For API server (install to Personal store)" -ForegroundColor White
    Write-Host "• certificate-details.txt  - Certificate information and instructions" -ForegroundColor White
    Write-Host "• install-certificate.cmd  - Automated installation script" -ForegroundColor White
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "1. Install server certificate: Run install-certificate.cmd as Administrator" -ForegroundColor White
    Write-Host "2. Distribute public certificate to client machines" -ForegroundColor White
    Write-Host "3. Test the installation: .\scripts\validate-certificate.ps1 -SkipCertificateCheck" -ForegroundColor White
    Write-Host ""
    Write-Host "⚠ Important: Save the PFX password securely: $PfxPassword" -ForegroundColor Yellow

} catch {
    Write-Host ""
    Write-Host "✗ Certificate generation failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "• Ensure you're running PowerShell as Administrator" -ForegroundColor White
    Write-Host "• Check that the output directory is writable" -ForegroundColor White
    Write-Host "• Verify that no conflicting certificates exist" -ForegroundColor White
    exit 1
}
