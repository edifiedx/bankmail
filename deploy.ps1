# Deploy script for BankMail addon
param (
    [string]$source = $PSScriptRoot,
    [string]$destination = "G:\Games\World of Warcraft\_classic_era_\Interface\AddOns\BankMail"
)

# Create destination directory if it doesn't exist
if (-not (Test-Path $destination)) {
    New-Item -ItemType Directory -Path $destination -Force
    Write-Host "Created destination directory: $destination"
}

# Read .toc file
$tocPath = Join-Path $source "BankMail.toc"
if (-not (Test-Path $tocPath)) {
    Write-Error "Missing BankMail.toc file"
    exit 1
}

# Parse .toc file to get the list of files
$requiredFiles = @("BankMail.toc")  # Always include the .toc file
$tocContent = Get-Content $tocPath
foreach ($line in $tocContent) {
    # Skip comments and empty lines
    if ($line -match '^\s*$' -or $line -match '^\s*#' -or $line -match '^\s*##') {
        continue
    }
    
    # Add the file to our list
    $requiredFiles += $line.Trim()
}

Write-Host "Files to deploy:" -ForegroundColor Cyan
$requiredFiles | ForEach-Object { Write-Host "  - $_" }

# Verify source files exist
foreach ($file in $requiredFiles) {
    if (-not (Test-Path "$source\$file")) {
        Write-Error "Missing required file: $file"
        exit 1
    }
}

# Copy all files
try {
    foreach ($file in $requiredFiles) {
        Copy-Item "$source\$file" "$destination" -Force
        Write-Host "Copied $file"
    }
    Write-Host "`nDeployment complete!" -ForegroundColor Green
}
catch {
    Write-Error "Error during deployment: $_"
    exit 1
}