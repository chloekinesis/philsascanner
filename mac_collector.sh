#!/bin/zsh

# ==========================================
# SCHOOL COMPUTER SPECIFICATION COLLECTOR (MAC)
# ==========================================

echo ""
echo "\033[1;36m==========================================\033[0m"
echo "\033[1;36m SCHOOL COMPUTER SPECIFICATION COLLECTOR \033[0m"
echo "\033[1;36m==========================================\033[0m"
echo ""
echo "Collecting information. Please wait..."
echo ""

# -------------------------------
# BASIC DEVICE INFORMATION
# -------------------------------
HW_INFO=$(system_profiler SPHardwareDataType 2>/dev/null)

MANUFACTURER="Apple Inc."
MODEL_NAME=$(echo "$HW_INFO" | awk -F': ' '/Model Name/ {print $2}')
MODEL_ID=$(echo "$HW_INFO" | awk -F': ' '/Model Identifier/ {print $2}')
SERIAL_NUM=$(echo "$HW_INFO" | awk -F': ' '/Serial Number/ {print $2}')
[ -z "$SERIAL_NUM" ] && SERIAL_NUM="N/A (Custom/VM)"

# -------------------------------
# PROCESSOR / CHIP
# -------------------------------
CHIP_NAME=$(echo "$HW_INFO" | awk -F': ' '/Chip/ {print $2}')
if [ -z "$CHIP_NAME" ]; then
    CHIP_NAME=$(echo "$HW_INFO" | awk -F': ' '/Processor Name/ {print $2}')
fi

CORES=$(echo "$HW_INFO" | awk -F': ' '/Total Number of Cores/ {print $2}')
[ -z "$CORES" ] && CORES=$(sysctl -n hw.physicalcpu 2>/dev/null || echo "Unknown")

SYS_ARCH=$(uname -m)

# -------------------------------
# MEMORY
# -------------------------------
RAM_BYTES=$(sysctl -n hw.memsize 2>/dev/null)
if [ -n "$RAM_BYTES" ]; then
    RAM_GB=$(awk "BEGIN {printf \"%.2f\", $RAM_BYTES/1073741824}")
else
    RAM_GB=$(echo "$HW_INFO" | awk -F': ' '/Memory/ {print $2}')
fi

# -------------------------------
# STORAGE
# -------------------------------
STORAGE_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
STORAGE_FREE=$(df -h / | awk 'NR==2 {print $4}')

DISK_MODEL=$(system_profiler SPStorageDataType 2>/dev/null | awk -F': ' '/Device Name|Media Name/ {print $2}' | head -n 1)
[ -z "$DISK_MODEL" ] && DISK_MODEL="Apple Internal Storage"

# -------------------------------
# GRAPHICS
# -------------------------------
GPU_INFO=$(system_profiler SPDisplaysDataType 2>/dev/null | awk -F': ' '/Chipset Model/ {print $2}' | paste -sd "; " -)
[ -z "$GPU_INFO" ] && GPU_INFO="Apple Integrated Graphics"

# -------------------------------
# OPERATING SYSTEM
# -------------------------------
OS_NAME=$(sw_vers -productName 2>/dev/null || echo "macOS")
OS_VER=$(sw_vers -productVersion 2>/dev/null || echo "Unknown")
OS_BUILD=$(sw_vers -buildVersion 2>/dev/null || echo "Unknown")

# -------------------------------
# DISPLAY
# -------------------------------
MONITOR_COUNT=$(system_profiler SPDisplaysDataType 2>/dev/null | grep -c "Resolution:")
[ "$MONITOR_COUNT" -eq 0 ] && MONITOR_COUNT=1
DISPLAYS_INFO=$(system_profiler SPDisplaysDataType 2>/dev/null | awk -F': ' '/Resolution/ {print "Display Resolution: " $2}')

# -------------------------------
# SECURITY / FIRMWARE
# -------------------------------
SIP_STATUS="Enabled"
if csrutil status 2>/dev/null | grep -q "disabled"; then
    SIP_STATUS="Disabled"
fi

# -------------------------------
# PERIPHERALS & POWER
# -------------------------------
CAMERA="Not detected"
if system_profiler SPCameraDataType 2>/dev/null | grep -q "Unique ID"; then
    CAMERA="Detected"
fi

AUDIO_INFO=$(system_profiler SPAudioDataType 2>/dev/null)
MIC="Not detected"
if echo "$AUDIO_INFO" | grep -qi "microphone\|input"; then
    MIC="Detected"
fi

SPEAKER="Not detected"
if echo "$AUDIO_INFO" | grep -qi "speaker\|output"; then
    SPEAKER="Detected"
fi

POWER_INFO=$(pmset -g batt 2>/dev/null)
if echo "$POWER_INFO" | grep -q "InternalBattery"; then
    BATTERY_STATUS="Battery detected"
else
    BATTERY_STATUS="No battery detected (Desktop Mac)"
fi

# -------------------------------
# REPORT GENERATION
# -------------------------------
REPORT="
==========================================
SCHOOL COMPUTER SPECIFICATION REPORT
==========================================

DEVICE INFORMATION
------------------------------------------
Manufacturer       : $MANUFACTURER
Product Family     : $MODEL_NAME
Model Identifier   : $MODEL_ID
Serial Number      : $SERIAL_NUM
Motherboard        : Apple Logic Board
System Type        : $SYS_ARCH


PROCESSOR
------------------------------------------
CPU                : $CHIP_NAME
CPU Cores          : $CORES
CPU Threads        : N/A (Apple Architecture)
CPU Gen / Series   : Apple Silicon / Intel Mac

MEMORY
------------------------------------------
RAM                : $RAM_GB GB

STORAGE
------------------------------------------
C: Drive Capacity  : $STORAGE_TOTAL
C: Drive Free      : $STORAGE_FREE

Physical Disk(s)
------------------------------------------
$DISK_MODEL - $STORAGE_TOTAL

GRAPHICS
------------------------------------------
GPU                : $GPU_INFO
DirectX            : N/A (Uses Apple Metal API)

OPERATING SYSTEM
------------------------------------------
OS                 : $OS_NAME
Version            : $OS_VER
Build              : $OS_BUILD

DISPLAY
------------------------------------------
Monitor Count      : $MONITOR_COUNT
Monitor Information:
$DISPLAYS_INFO

SECURITY / FIRMWARE
------------------------------------------
TPM Present        : N/A (Apple Secure Enclave)
TPM Version        : Secure Enclave Processor
Firmware           : Apple EFI / iBoot
Secure Boot        : $SIP_STATUS (System Integrity Protection)

PERIPHERALS
------------------------------------------
Webcam             : $CAMERA
Microphone         : $MIC
Speaker            : $SPEAKER

POWER
------------------------------------------
Battery            : $BATTERY_STATUS

==========================================
END OF AUTOMATIC REPORT
==========================================
"

# Output to terminal
echo "$REPORT"

# Copy output to Mac clipboard
echo "$REPORT" | pbcopy

# Save report to Desktop
OUTPUT_FILE="$HOME/Desktop/Computer_Specification_Report.txt"
echo "$REPORT" > "$OUTPUT_FILE"

echo ""
echo "\033[1;32m==========================================\033[0m"
echo "\033[1;32m DONE!\033[0m"
echo "\033[1;32m==========================================\033[0m"
echo ""
echo "The report has been AUTOMATICALLY COPIED TO YOUR CLIPBOARD."
echo ""
echo "It has also been saved to:"
echo "$OUTPUT_FILE"
echo ""
echo "Please paste the report into the jotform."
