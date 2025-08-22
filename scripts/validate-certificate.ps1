# ADSoft API Certificate Validation Script
# This script validates SSL certificate configuration and connectivity

param(
    [Parameter(HelpMessage="Server URL to test")]
    [string]$ServerUrl = "https://localhost:5001",
    
    [Parameter(HelpMessage="Skip certificate validation for self-signed certificates")]
    [switch]$SkipCertificateCheck,
    
    [Parameter(HelpMessage="Test specific API endpoints")]
    [switch]$TestApiEndpoints,
    
    [Parameter(HelpMessage="API key for testing endpoints")]
    [string]$ApiKey,
    
    [Parameter(HelpMessage="JWT token for testing endpoints")]
    [string]$JwtToken
)

Write-Host "=== ADSoft API Certificate Validation ===" -ForegroundColor Cyan
Write-Host ""

# Helper function to make HTTP requests with optional certificate bypass
function Test-HttpEndpoint {
    param(
        [string]$Url,
        [string]$Method = "GET",
        [hashtable]$Headers = @{},
        [switch]$SkipCertCheck
    )
    
    try {
        if ($SkipCertCheck) {
            # Skip certificate validation
            $result = Invoke-RestMethod -Uri $Url -Method $Method -Headers $Headers -SkipCertificateCheck -TimeoutSec 10
        } else {
            $result = Invoke-RestMethod -Uri $Url -Method $Method -Headers $Headers -TimeoutSec 10
        }
        return @{ Success = $true; Data = $result; Error = $null }
    }
    catch {
        return @{ Success = $false; Data = $null; Error = $_.Exception.Message }
    }
}

# Test 1: Certificate Store Validation
Write-Host "1. Checking certificate store..." -ForegroundColor Yellow

try {
    $certificates = Get-ChildItem Cert:\LocalMachine\My | Where-Object { 
        $_.HasPrivateKey -and 
        $_.NotAfter -gt (Get-Date) -and
        ($_.Subject -like "*api*" -or $_.Subject -like "*localhost*" -or $_.DnsNameList -like "*api*")
    }
    
    if ($certificates.Count -eq 0) {
        Write-Host "   ⚠ No suitable certificates found in Local Machine store" -ForegroundColor Yellow
        Write-Host "     Looking for certificates with private keys that are not expired" -ForegroundColor Gray
    } else {
        Write-Host "   ✓ Found $($certificates.Count) suitable certificate(s)" -ForegroundColor Green
        foreach ($cert in $certificates) {
            Write-Host "     - Subject: $($cert.Subject)" -ForegroundColor Gray
            Write-Host "       Thumbprint: $($cert.Thumbprint)" -ForegroundColor Gray
            Write-Host "       Expires: $($cert.NotAfter)" -ForegroundColor Gray
            Write-Host "       DNS Names: $($cert.DnsNameList -join ', ')" -ForegroundColor Gray
            Write-Host ""
        }
    }
} catch {
    Write-Host "   ✗ Error checking certificate store: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 2: Configuration File Validation
Write-Host "2. Checking configuration..." -ForegroundColor Yellow

try {
    $configPath = ".\appsettings.json"
    if (Test-Path $configPath) {
        $config = Get-Content $configPath | ConvertFrom-Json
        
        # Check URLs
        if ($config.Urls) {
            Write-Host "   ✓ URLs configured: $($config.Urls)" -ForegroundColor Green
        } else {
            Write-Host "   ⚠ No URLs configured in appsettings.json" -ForegroundColor Yellow
        }
        
        # Check Kestrel configuration
        if ($config.Kestrel -and $config.Kestrel.Endpoints -and $config.Kestrel.Endpoints.Https) {
            $httpsConfig = $config.Kestrel.Endpoints.Https
            Write-Host "   ✓ HTTPS endpoint configured: $($httpsConfig.Url)" -ForegroundColor Green
            
            if ($httpsConfig.Certificate) {
                $certConfig = $httpsConfig.Certificate
                if ($certConfig.Subject) {
                    Write-Host "     Certificate Subject: $($certConfig.Subject)" -ForegroundColor Gray
                } elseif ($certConfig.Path) {
                    Write-Host "     Certificate Path: $($certConfig.Path)" -ForegroundColor Gray
                }
            }
        } else {
            Write-Host "   ⚠ HTTPS configuration not found in Kestrel settings" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   ✗ Configuration file not found: $configPath" -ForegroundColor Red
    }
} catch {
    Write-Host "   ✗ Error reading configuration: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 3: Network Connectivity
Write-Host "3. Testing network connectivity..." -ForegroundColor Yellow

# Extract host and port from URL
$uri = [System.Uri]$ServerUrl
$hostname = $uri.Host
$port = $uri.Port

try {
    $tcpTest = Test-NetConnection -ComputerName $hostname -Port $port -WarningAction SilentlyContinue
    if ($tcpTest.TcpTestSucceeded) {
        Write-Host "   ✓ TCP connection successful to $hostname`:$port" -ForegroundColor Green
    } else {
        Write-Host "   ✗ TCP connection failed to $hostname`:$port" -ForegroundColor Red
        Write-Host "     Check if the API is running and firewall rules are configured" -ForegroundColor Gray
    }
} catch {
    Write-Host "   ✗ Network test failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 4: HTTPS Endpoint Validation
Write-Host "4. Testing HTTPS endpoint..." -ForegroundColor Yellow

# Test Swagger UI
$swaggerUrl = "$ServerUrl/swagger/index.html"
$swaggerTest = Test-HttpEndpoint -Url $swaggerUrl -SkipCertCheck:$SkipCertificateCheck

if ($swaggerTest.Success) {
    Write-Host "   ✓ Swagger UI accessible: $swaggerUrl" -ForegroundColor Green
} else {
    Write-Host "   ✗ Swagger UI test failed: $($swaggerTest.Error)" -ForegroundColor Red
    
    # Try alternative swagger path
    $altSwaggerUrl = "$ServerUrl/swagger"
    $altSwaggerTest = Test-HttpEndpoint -Url $altSwaggerUrl -SkipCertCheck:$SkipCertificateCheck
    
    if ($altSwaggerTest.Success) {
        Write-Host "   ✓ Alternative Swagger URL accessible: $altSwaggerUrl" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Alternative Swagger URL also failed" -ForegroundColor Red
    }
}

# Test API health endpoint (if available)
$healthUrl = "$ServerUrl/health"
$healthTest = Test-HttpEndpoint -Url $healthUrl -SkipCertCheck:$SkipCertificateCheck

if ($healthTest.Success) {
    Write-Host "   ✓ Health endpoint accessible: $healthUrl" -ForegroundColor Green
} else {
    Write-Host "   ⚠ Health endpoint not available (this is normal if not implemented)" -ForegroundColor Yellow
}

Write-Host ""

# Test 5: API Endpoints (if credentials provided)
if ($TestApiEndpoints -and ($ApiKey -or $JwtToken)) {
    Write-Host "5. Testing API endpoints..." -ForegroundColor Yellow
    
    $headers = @{}
    if ($ApiKey) {
        $headers["X-API-Key"] = $ApiKey
    }
    if ($JwtToken) {
        $headers["Authorization"] = "Bearer $JwtToken"
    }
    
    # Test auth endpoint
    $authUrl = "$ServerUrl/api/auth/login"
    $authTest = Test-HttpEndpoint -Url $authUrl -Method "POST" -Headers $headers -SkipCertCheck:$SkipCertificateCheck
    
    if ($authTest.Success) {
        Write-Host "   ✓ Auth endpoint accessible: $authUrl" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Auth endpoint test failed: $($authTest.Error)" -ForegroundColor Red
    }
    
    # Test configuration endpoint
    $configUrl = "$ServerUrl/api/configuration/generate-keys"
    $configTest = Test-HttpEndpoint -Url $configUrl -Headers $headers -SkipCertCheck:$SkipCertificateCheck
    
    if ($configTest.Success) {
        Write-Host "   ✓ Configuration endpoint accessible: $configUrl" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Configuration endpoint test failed: $($configTest.Error)" -ForegroundColor Red
    }
    
    Write-Host ""
}

# Test 6: Certificate Chain Validation
Write-Host "6. Certificate chain validation..." -ForegroundColor Yellow

try {
    # Create web request to get certificate details
    $request = [System.Net.WebRequest]::Create($ServerUrl)
    $request.Timeout = 10000
    
    if ($SkipCertificateCheck) {
        # Skip certificate validation
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    }
    
    try {
        $response = $request.GetResponse()
        Write-Host "   ✓ Certificate chain validation passed" -ForegroundColor Green
        $response.Close()
    } catch [System.Net.WebException] {
        $webEx = $_.Exception
        if ($webEx.Status -eq [System.Net.WebExceptionStatus]::TrustFailure) {
            Write-Host "   ✗ Certificate trust failure" -ForegroundColor Red
            Write-Host "     This is common with self-signed certificates" -ForegroundColor Gray
            Write-Host "     Consider installing the certificate in the Trusted Root store" -ForegroundColor Gray
        } else {
            Write-Host "   ✗ Certificate validation error: $($webEx.Message)" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "   ✗ Certificate chain test failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Summary and Recommendations
Write-Host "=== Validation Summary ===" -ForegroundColor Cyan
Write-Host ""

if ($SkipCertificateCheck) {
    Write-Host "⚠ Certificate validation was bypassed" -ForegroundColor Yellow
    Write-Host "  For production use, ensure proper certificate trust chain" -ForegroundColor Gray
}

Write-Host "Recommendations:" -ForegroundColor Cyan
Write-Host "• Ensure the API application is running before testing" -ForegroundColor White
Write-Host "• Check Windows Event Logs for detailed error information" -ForegroundColor White
Write-Host "• Verify firewall rules allow traffic on ports 5000 and 5001" -ForegroundColor White
Write-Host "• For self-signed certificates, install them in client trust stores" -ForegroundColor White
Write-Host "• Monitor certificate expiration dates and plan renewals" -ForegroundColor White
Write-Host ""

Write-Host "Testing completed. Check the results above for any issues." -ForegroundColor Green
