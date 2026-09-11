# ==========================================
# SCHOOL COMPUTER SPECIFICATION COLLECTOR
# ==========================================

$ErrorActionPreference = "SilentlyContinue"

# Where the plain-text backup copy of the report gets saved
$Timestamp  = Get-Date -Format "yyyy-MM-dd_HHmmss"
$OutputFile = Join-Path -Path ([Environment]::GetFolderPath("Desktop")) -ChildPath "SchoolPC_Report_$Timestamp.txt"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " SCHOOL COMPUTER SPECIFICATION COLLECTOR"
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Collecting information. Please wait..."
Write-Host ""

# Regex for generic placeholder strings common in custom builds
$IgnoredOEMStrings = "(?i)Default|To be filled|System Product Name|System Serial Number|O\.E\.M|1\.0|01|System Version"

# -------------------------------
# BASIC DEVICE INFORMATION
# -------------------------------

$Computer  = Get-CimInstance Win32_ComputerSystem
$Product   = Get-CimInstance Win32_ComputerSystemProduct
$BaseBoard = Get-CimInstance Win32_BaseBoard
$BIOS      = Get-CimInstance Win32_BIOS
$OS        = Get-CimInstance Win32_OperatingSystem
$CPU       = Get-CimInstance Win32_Processor
$GPU       = Get-CimInstance Win32_VideoController

$Manufacturer = $Computer.Manufacturer

# Filter Serial Number for Custom Builds
$SafeSerialNumber = $BIOS.SerialNumber
if ([string]::IsNullOrWhiteSpace($SafeSerialNumber) -or $SafeSerialNumber -match $IgnoredOEMStrings) {
    $SafeSerialNumber = "N/A (Custom Build)"
}

# -------------------------------
# UNIVERSAL BRAND MODEL / CODE DETECTION
# -------------------------------

$ModelFull   = "Unknown"
$VendorCode  = "N/A"
$CodeType    = "Model Identifier"

# Standardize Manufacturer string for checking
$MfrLower = if ($Manufacturer) { $Manufacturer.ToLower() } else { "" }

# 1. DELL (Service Tag & Express Service Code)
if ($MfrLower -like "*dell*") {
    $CodeType   = "Dell Service Tag"
    $VendorCode = $BIOS.SerialNumber
    $ModelFull  = "$($Computer.Model) (Service Tag: $VendorCode)"
}

# 2. LENOVO (Machine Type Model / MTM)
elseif ($MfrLower -like "*lenovo*") {
    $CodeType = "Lenovo MTM / SKU"
    if ($Product.Name -and $Product.Name -notmatch $IgnoredOEMStrings) {
        $VendorCode = $Product.Name
    }
    elseif ($Computer.SystemSKUNumber -and $Computer.SystemSKUNumber -notmatch $IgnoredOEMStrings) {
        $VendorCode = $Computer.SystemSKUNumber
    }
    else {
        $VendorCode = $Computer.Model
    }
    $ModelFull = "$($Computer.Model) [MTM: $VendorCode]"
}

# 3. HP / HEWLETT-PACKARD (Product ID / System Board ID)
elseif ($MfrLower -like "*hp*" -or $MfrLower -like "*hewlett*") {
    $CodeType = "HP System SKU / Board ID"
    $SKU = $Computer.SystemSKUNumber
    $BoardID = $BaseBoard.Product
    
    if ($SKU -and $SKU -notmatch $IgnoredOEMStrings) {
        $VendorCode = $SKU
    } elseif ($BoardID) {
        $VendorCode = "Board ID: $BoardID"
    } else {
        $VendorCode = $BIOS.SerialNumber
    }
    $ModelFull = "$($Computer.Model) [SKU: $VendorCode]"
}

# 4. APPLE / BOOTCAMP (A-Number / Board ID)
elseif ($MfrLower -like "*apple*") {
    $CodeType = "Apple Model / Board ID"
    $AppleModelReg = (Get-ItemProperty -Path "HKLM:\HARDWARE\DESCRIPTION\System\BIOS" -Name "SystemProductName" -ErrorAction SilentlyContinue).SystemProductName
    if ($AppleModelReg) {
        $VendorCode = $AppleModelReg
    } else {
        $VendorCode = $BaseBoard.Product
    }
    $ModelFull = "$($Computer.Model) [$VendorCode]"
}

# 5. MICROSOFT SURFACE
elseif ($MfrLower -like "*microsoft*") {
    $CodeType   = "Surface Model Code"
    $VendorCode = if ($Computer.SystemSKUNumber) { $Computer.SystemSKUNumber } else { $Product.Version }
    $ModelFull  = "$($Computer.Model) [SKU: $VendorCode]"
}

# 6. CUSTOM BUILD DETECTIONS (ASUS, ACER, MSI, GIGABYTE, ASROCK)
elseif ($MfrLower -match "asus|acer|msi|micro-star|gigabyte|asrock") {
    $CodeType = "Motherboard Model"
    $VendorCode = $BaseBoard.Product
    $ModelFull = "Custom Build [$VendorCode]"
}

# 7. GENERAL FALLBACK (Custom Built, Unknown, etc.)
else {
    $CodeType = "System Identifier"
    if ($Computer.SystemSKUNumber -and $Computer.SystemSKUNumber -notmatch $IgnoredOEMStrings) {
        $VendorCode = $Computer.SystemSKUNumber
    } elseif ($Product.Name -and $Product.Name -notmatch $IgnoredOEMStrings) {
        $VendorCode = $Product.Name
    } elseif ($BaseBoard.Product -and $BaseBoard.Product -notmatch $IgnoredOEMStrings) {
        $CodeType = "Motherboard Model"
        $VendorCode = $BaseBoard.Product
    } else {
        $VendorCode = "Custom / Unspecified"
    }
    $ModelFull = if ($Computer.Model -match $IgnoredOEMStrings) { "Custom Build" } else { $Computer.Model }
}

# -------------------------------
# MARKETING FAMILY / PRODUCT LINE
# -------------------------------

$MarketingFamily = "Unknown"

try {
    $SysProduct = Get-CimInstance Win32_ComputerSystemProduct -ErrorAction Stop

    if ($SysProduct.Family -and $SysProduct.Family -notmatch $IgnoredOEMStrings) {
        $MarketingFamily = $SysProduct.Family
    }
    elseif ($SysProduct.Version -and $SysProduct.Version -notmatch $IgnoredOEMStrings) {
        $MarketingFamily = $SysProduct.Version
    }
    else {
        # Fallback for custom builds
        if ($BaseBoard.Product -and $BaseBoard.Product -notmatch $IgnoredOEMStrings) {
            $MarketingFamily = "Custom Desktop ($($BaseBoard.Product))"
        } else {
            $MarketingFamily = "Custom Build / Unspecified"
        }
    }
}
catch {
    $MarketingFamily = "Unable to determine"
}

# -------------------------------
# RAM
# -------------------------------

$RAMGB = [math]::Round(
    ((Get-CimInstance Win32_PhysicalMemory |
    Measure-Object Capacity -Sum).Sum / 1GB), 2
)

# -------------------------------
# STORAGE
# -------------------------------

$SystemDrive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"

$StorageFreeGB = [math]::Round(
    $SystemDrive.FreeSpace / 1GB, 2
)

$StorageTotalGB = [math]::Round(
    $SystemDrive.Size / 1GB, 2
)

$PhysicalDisks = Get-CimInstance Win32_DiskDrive

$SSDInfo = @()

foreach ($disk in $PhysicalDisks) {
    $sizeGB = [math]::Round($disk.Size / 1GB, 0)
    $SSDInfo += "$($disk.Model) - $sizeGB GB - $($disk.MediaType)"
}

# -------------------------------
# CPU
# -------------------------------

$CPUName = $CPU.Name
$CPUCores = $CPU.NumberOfCores
$CPUThreads = $CPU.NumberOfLogicalProcessors

$CPUGeneration = "N/A"

# Intel Detection
if ($CPUName -match "Intel.*i[3579]-([0-9]{4,5})") {
    $digits = $Matches[1]
    if ($digits.Length -eq 4) {
        $CPUGeneration = $digits.Substring(0,1) + "th Gen Intel"
    }
    elseif ($digits.Length -eq 5) {
        $CPUGeneration = $digits.Substring(0,2) + "th Gen Intel"
    }
}
# AMD Ryzen Detection
elseif ($CPUName -match "AMD Ryzen.* (\d{4,5})") {
    $digits = $Matches[1]
    if ($digits.Length -eq 4) {
        $CPUGeneration = $digits.Substring(0,1) + "000 Series AMD"
    }
    elseif ($digits.Length -eq 5) {
        $CPUGeneration = $digits.Substring(0,2) + "000 Series AMD"
    }
}

# -------------------------------
# GPU
# -------------------------------

$GPUInfo = ($GPU | Select-Object -ExpandProperty Name) -join "; "

# -------------------------------
# DIRECTX
# -------------------------------

$DxDiagPath = "$env:TEMP\dxdiag_school.txt"

Start-Process `
    -FilePath "dxdiag.exe" `
    -ArgumentList "/t `"$DxDiagPath`"" `
    -Wait `
    -WindowStyle Hidden

$DirectXVersion = "Unable to detect"

if (Test-Path $DxDiagPath) {
    $DxText = Get-Content $DxDiagPath
    $DXLine = $DxText |
        Where-Object { $_ -match "DirectX Version" } |
        Select-Object -First 1

    if ($DXLine) {
        $DirectXVersion = $DXLine.Trim()
    }
}

# -------------------------------
# SECURITY / FIRMWARE
# -------------------------------

$TPMPresent   = "Unknown"
$TPMVersion   = "Unknown"
$TPMEnabled   = "Unknown"
$FirmwareType = "Unknown"
$SecureBoot   = "Unknown"

# TPM DETECTION
$TpmDevice = Get-PnpDevice -Class "SecurityDevices" -ErrorAction SilentlyContinue | 
    Where-Object { $_.FriendlyName -match "Trusted Platform Module" -or $_.DeviceId -match "TPM" }

if ($TpmDevice) {
    $TPMPresent = "Yes"
    if ($TpmDevice.Status -eq "OK") {
        $TPMEnabled = "Yes"
    } else {
        $TPMEnabled = "No / Error ($($TpmDevice.Status))"
    }

    if ($TpmDevice.FriendlyName -match "2\.0") {
        $TPMVersion = "2.0"
    } elseif ($TpmDevice.FriendlyName -match "1\.2") {
        $TPMVersion = "1.2"
    } else {
        $TPMVersion = $TpmDevice.FriendlyName
    }
}
else {
    try {
        $TPM = Get-Tpm -ErrorAction Stop
        if ($TPM.TpmPresent -eq $true) {
            $TPMPresent = "Yes"
            $TPMEnabled = if ($TPM.TpmReady -eq $true) { "Yes" } else { "No / Not Ready" }
        } else {
            $TPMPresent = "No"
            $TPMEnabled = "No"
        }
    }
    catch {
        try {
            $TPMInfo = Get-CimInstance -Namespace "root\CIMV2\Security\MicrosoftTpm" -ClassName Win32_Tpm -ErrorAction Stop
            if ($TPMInfo) {
                $TPMPresent = "Yes"
                $TPMEnabled = if ($TPMInfo.IsEnabled_InitialValue) { "Yes" } else { "No" }
                $TPMVersion = if ($TPMInfo.SpecVersion) { $TPMInfo.SpecVersion } else { "Unknown" }
            } else {
                $TPMPresent = "No"
                $TPMEnabled = "No"
            }
        }
        catch {
            $TPMPresent = "Unable to determine (Access Denied)"
            $TPMEnabled = "Unable to determine"
            $TPMVersion = "Unable to determine"
        }
    }
}

# FIRMWARE TYPE
try {
    $FirmwareRegistry = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "PEFirmwareType" -ErrorAction Stop
    switch ($FirmwareRegistry.PEFirmwareType) {
        1 { $FirmwareType = "Legacy BIOS" }
        2 { $FirmwareType = "UEFI" }
        default { $FirmwareType = "Unknown" }
    }
}
catch {
    try {
        $SystemInfo = Get-ComputerInfo -Property BiosFirmwareType -ErrorAction Stop
        if ($SystemInfo.BiosFirmwareType) {
            $FirmwareType = $SystemInfo.BiosFirmwareType
        }
    }
    catch {
        if (Get-Partition | Where-Object { $_.GptType -eq "{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}" }) {
            $FirmwareType = "UEFI"
        } else {
            $FirmwareType = "Unknown"
        }
    }
}

# SECURE BOOT
try {
    $SecureBootResult = Confirm-SecureBootUEFI -ErrorAction Stop
    if ($SecureBootResult -eq $true) {
        $SecureBoot = "Enabled"
    } else {
        $SecureBoot = "Disabled"
    }
}
catch {
    try {
        $RegUEFI = Get-ItemPropertyValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State" -Name "UEFISecureBootEnabled" -ErrorAction Stop
        if ($RegUEFI -eq 1) {
            $SecureBoot = "Enabled"
        } elseif ($RegUEFI -eq 0) {
            $SecureBoot = "Disabled"
        } else {
            $SecureBoot = "Unknown"
        }
    }
    catch {
        if ($FirmwareType -eq "Legacy BIOS") {
            $SecureBoot = "Not supported (Legacy BIOS)"
        } else {
            $SecureBoot = "Unable to determine (Requires Admin privileges)"
        }
    }
}

# -------------------------------
# DISPLAY
# -------------------------------

$Monitors = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorBasicDisplayParams
$MonitorCount = $Monitors.Count
$MonitorInfo = @()

foreach ($Monitor in $Monitors) {
    $Width = $Monitor.MaxHorizontalImageSize
    $Height = $Monitor.MaxVerticalImageSize

    if ($Width -and $Height) {
        $DiagonalCM = [math]::Sqrt(($Width * $Width) + ($Height * $Height))
        $DiagonalInches = [math]::Round($DiagonalCM / 2.54, 1)
        $MonitorInfo += "Approx. $DiagonalInches inch display"
    }
}

# -------------------------------
# PERIPHERALS & POWER
# -------------------------------

$CameraDevices = Get-PnpDevice | Where-Object { $_.FriendlyName -match "camera|webcam|integrated camera" }
$CameraPresent = if ($CameraDevices) { "Detected" } else { "Not detected" }

$AudioDevices = Get-PnpDevice | Where-Object { $_.Class -match "AudioEndpoint|MEDIA" }
$MicrophoneDevices = $AudioDevices | Where-Object { $_.FriendlyName -match "microphone|mic" }
$SpeakerDevices    = $AudioDevices | Where-Object { $_.FriendlyName -match "speaker|headphone|audio" }

$MicrophonePresent = if ($MicrophoneDevices) { "Detected" } else { "Not detected" }
$SpeakerPresent    = if ($SpeakerDevices) { "Detected" } else { "Not detected" }

$Battery = Get-CimInstance Win32_Battery
if ($Battery) {
    $BatteryStatus = "Battery detected"
} else {
    $BatteryStatus = "No battery detected"
}

# -------------------------------
# OUTPUT
# -------------------------------

# Pretty, boxed report -- shown in the console window only, for the
# person running the script to read while it's on screen.
$DisplayReport = @"

==========================================
SCHOOL COMPUTER SPECIFICATION REPORT
==========================================

DEVICE INFORMATION
------------------------------------------
Manufacturer       : $($Computer.Manufacturer)
Product Family     : $MarketingFamily
$($CodeType.PadRight(19)): $VendorCode
Serial Number      : $SafeSerialNumber
Motherboard        : $($BaseBoard.Product)
System Type        : $($Computer.SystemType)


PROCESSOR
------------------------------------------
CPU                : $CPUName
CPU Cores          : $CPUCores
CPU Threads        : $CPUThreads
CPU Gen / Series   : $CPUGeneration

MEMORY
------------------------------------------
RAM                : $RAMGB GB

STORAGE
------------------------------------------
C: Drive Capacity  : $StorageTotalGB GB
C: Drive Free      : $StorageFreeGB GB

Physical Disk(s)
------------------------------------------
$($SSDInfo -join "`n")

GRAPHICS
------------------------------------------
GPU                : $GPUInfo
DirectX            : $DirectXVersion

OPERATING SYSTEM
------------------------------------------
OS                 : $($OS.Caption)
Version            : $($OS.Version)
Build              : $($OS.BuildNumber)

DISPLAY
------------------------------------------
Monitor Count      : $MonitorCount
Monitor Information:
$($MonitorInfo -join "`n")

SECURITY / FIRMWARE
------------------------------------------
TPM Present        : $TPMPresent
TPM Version        : $TPMVersion
Firmware           : $FirmwareType
Secure Boot        : $SecureBoot

PERIPHERALS
------------------------------------------
Webcam             : $CameraPresent
Microphone         : $MicrophonePresent
Speaker            : $SpeakerPresent

POWER
------------------------------------------
Battery            : $BatteryStatus

==========================================
END OF AUTOMATIC REPORT
==========================================

"@

# Flat, single-line report -- this is what gets copied to the clipboard.
# Fillout's table field strips newlines on paste, which is what was turning
# the boxed report into one giant run-on wall of text in the CSV export.
# Using " | " as a separator instead of newlines means it reads the same
# clean way whether it lands in the form field, the CSV, or Excel.
$ReportFields = [ordered]@{
    "Manufacturer"     = $Computer.Manufacturer
    "Product Family"   = $MarketingFamily
    $CodeType          = $VendorCode
    "Serial Number"    = $SafeSerialNumber
    "Motherboard"      = $BaseBoard.Product
    "System Type"      = $Computer.SystemType
    "CPU"              = $CPUName
    "CPU Cores"        = $CPUCores
    "CPU Threads"      = $CPUThreads
    "CPU Gen / Series" = $CPUGeneration
    "RAM"              = "$RAMGB GB"
    "C: Drive Capacity"= "$StorageTotalGB GB"
    "C: Drive Free"    = "$StorageFreeGB GB"
    "Physical Disk(s)" = ($SSDInfo -join "; ")
    "GPU"              = $GPUInfo
    "DirectX"          = $DirectXVersion
    "OS"               = $OS.Caption
    "OS Version"       = $OS.Version
    "OS Build"         = $OS.BuildNumber
    "Monitor Count"    = $MonitorCount
    "Monitor Info"     = ($MonitorInfo -join "; ")
    "TPM Present"      = $TPMPresent
    "TPM Version"      = $TPMVersion
    "Firmware"         = $FirmwareType
    "Secure Boot"      = $SecureBoot
    "Webcam"           = $CameraPresent
    "Microphone"       = $MicrophonePresent
    "Speaker"          = $SpeakerPresent
    "Battery"          = $BatteryStatus
}

$Report = ($ReportFields.GetEnumerator() | ForEach-Object { "$($_.Key): $($_.Value)" }) -join " | "

# Display the pretty version in the console
Write-Host $DisplayReport

# Copy the flat, form-friendly version to clipboard
$Report | Set-Clipboard

# Save the pretty version to a text file as a readable backup copy
$DisplayReport | Out-File -FilePath $OutputFile -Encoding UTF8

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host " DONE!"
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "The report has been AUTOMATICALLY COPIED TO YOUR CLIPBOARD."
Write-Host ""
Write-Host "It has also been saved to:"
Write-Host $OutputFile
Write-Host ""
Write-Host "Please paste the report into the jotform."
Write-Host ""
Write-Host "Press any key to close..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")