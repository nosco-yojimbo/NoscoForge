Write-Host "Starting system maintenance..." -ForegroundColor Cyan

try {
    # Run DISM
    Write-Host "Running DISM /Online /Cleanup-Image /RestoreHealth..." -ForegroundColor Yellow
    Start-Process -FilePath "dism.exe" -ArgumentList "/Online","/Cleanup-Image","/RestoreHealth" -Wait -NoNewWindow

    # Run SFC
    Write-Host "Running SFC /scannow..." -ForegroundColor Yellow
    Start-Process -FilePath "sfc.exe" -ArgumentList "/scannow" -Wait -NoNewWindow

    Write-Host "Maintenance complete!" -ForegroundColor Green
}
catch {
    Write-Host "An error occurred: $($_.Exception.Message)" -ForegroundColor Red
}
