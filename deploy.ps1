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
    if (-not ($line -match '^\s*$' -or $line -match '^\s*#' -or $line -match '^\s*##')) {
        $requiredFiles += $line.Trim()
    }
}

# Format for status updates
$maxFileLength = ($requiredFiles | Measure-Object -Maximum Length).Maximum
$format = "{0,-${maxFileLength}} {1,-12} {2}"

Write-Host ($format -f "File", "Status", "Details")
Write-Host ("-" * ($maxFileLength + 20))

# Copy files with status updates
$copied = 0
$skipped = 0
$errors = 0

foreach ($file in $requiredFiles) {
    $sourcePath = Join-Path $source $file
    $destPath = Join-Path $destination $file
    
    if (-not (Test-Path $sourcePath)) {
        Write-Host ($format -f $file, "ERROR", "Source file missing") -ForegroundColor Red
        $errors++
        continue
    }

    try {
        $sourceHash = Get-FileHash $sourcePath -Algorithm MD5
        
        if (Test-Path $destPath) {
            $destHash = Get-FileHash $destPath -Algorithm MD5
            
            if ($sourceHash.Hash -eq $destHash.Hash) {
                Write-Host ($format -f $file, "SKIPPED", "Files identical") -ForegroundColor DarkGray
                $skipped++
                continue
            }
        }
        
        Copy-Item $sourcePath $destPath -Force
        Write-Host ($format -f $file, "COPIED", "Updated") -ForegroundColor Green
        $copied++
    }
    catch {
        Write-Host ($format -f $file, "ERROR", $_.Exception.Message) -ForegroundColor Red
        $errors++
    }
}

# Print summary
Write-Host "`nDeployment Summary:" -ForegroundColor Cyan
Write-Host "  Files copied:  $copied"
Write-Host "  Files skipped: $skipped"
Write-Host "  Errors:        $errors"

if ($errors -gt 0) {
    Write-Host "`nDeployment completed with errors!" -ForegroundColor Red
    exit 1
}
else {
    Write-Host "`nDeployment completed successfully!" -ForegroundColor Green
}