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

# Verify source files exist
$requiredFiles = @(
    "BankMail.lua",
    "BankMail.toc",
    "BankMail_Money.lua",
    "BankMail_Options.lua",
    "BankMail_AutoSwitch.lua"
)

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