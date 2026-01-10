#!/bin/bash

# Linux Performance Optimizer
# Tested on AMD Ryzen 5 1600 + NVIDIA GTX 1660 SUPER + Arch Linux

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Please run as root (use sudo)${NC}"
        exit 1
    fi
}

# Check required tools
check_tools() {
    local missing=()

    if ! command -v cpupower &> /dev/null; then
        missing+=("cpupower")
    fi

    if ! command -v nvidia-smi &> /dev/null; then
        echo -e "${YELLOW}nvidia-smi not found. GPU optimizations will be skipped.${NC}"
    fi

    if ! command -v systemctl &> /dev/null; then
        missing+=("systemd")
    fi

    if [ ${#missing[@]} -ne 0 ]; then
        echo -e "${YELLOW}Missing tools: ${missing[*]}${NC}"
        echo -e "Install with: ${GREEN}sudo pacman -S ${missing[*]}${NC}"
        [ "${missing[0]}" == "cpupower" ] && exit 1
    fi
}

# Get CPU information
get_cpu_info() {
    echo -e "${CYAN}=== CPU Information ===${NC}"
    echo "Model: $(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
    echo "Cores: $(nproc)"
    echo "Current Governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo 'Unknown')"
    echo "Available Governors: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null || echo 'N/A')"
    echo ""
}

# Get GPU information
get_gpu_info() {
    if command -v nvidia-smi &> /dev/null; then
        echo -e "${CYAN}=== GPU Information ===${NC}"
        nvidia-smi --query-gpu=name,driver_version,power.default_limit,power.max_limit --format=csv,noheader
        echo ""
    fi
}

# Set CPU performance mode
set_cpu_performance() {
    echo -e "${YELLOW}Optimizing CPU performance...${NC}"

    # Set performance governor for all cores
    cpupower frequency-set -g performance > /dev/null 2>&1

    # Disable frequency scaling limits (let CPU boost as high as possible)
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq; do
        if [ -d "$cpu" ]; then
            echo "performance" > "$cpu/scaling_governor" 2>/dev/null
            # Remove scaling limits if files exist
            [ -f "$cpu/scaling_min_freq" ] && cat "$cpu/cpuinfo_max_freq" > "$cpu/scaling_min_freq" 2>/dev/null
            [ -f "$cpu/scaling_max_freq" ] && cat "$cpu/cpuinfo_max_freq" > "$cpu/scaling_max_freq" 2>/dev/null
        fi
    done

    # Set performance energy bias (for Intel, but harmless on AMD)
    [ -f "/sys/devices/system/cpu/cpu0/power/energy_perf_bias" ] && \
        echo "performance" > "/sys/devices/system/cpu/cpu0/power/energy_perf_bias" 2>/dev/null

    echo -e "${GREEN}✓ CPU set to performance mode${NC}"
}

# Set GPU performance mode
set_gpu_performance() {
    if command -v nvidia-smi &> /dev/null; then
        echo -e "${YELLOW}Optimizing GPU performance...${NC}"

        # Set performance mode (0 = Adaptive, 1 = Prefer Maximum Performance)
        nvidia-settings -a "[gpu:0]/GpuPowerMizerMode=1" > /dev/null 2>&1

        # Set texture filtering to high performance
        nvidia-settings -a "[gpu:0]/GPUTextureFilteringMode=1" > /dev/null 2>&1

        # Set OpenGL image settings to high performance
        nvidia-settings -a "[gpu:0]/OpenGLImageSettings=3" > /dev/null 2>&1

        echo -e "${GREEN}✓ GPU set to maximum performance${NC}"
    else
        echo -e "${YELLOW}⚠ NVIDIA tools not available - skipping GPU optimization${NC}"
    fi
}

# Optimize system settings
optimize_system() {
    echo -e "${YELLOW}Optimizing system settings...${NC}"

    # Increase VM dirty ratio for better performance (be careful with this)
    echo "10" > /proc/sys/vm/dirty_ratio
    echo "5" > /proc/sys/vm/dirty_background_ratio

    # Swappiness (reduce if you have enough RAM)
    echo "10" > /proc/sys/vm/swappiness

    # Increase file max for better performance
    echo "1000000" > /proc/sys/fs/file-max

    # Network performance (optional)
    [ -f "/proc/sys/net/core/rmem_max" ] && echo "16777216" > /proc/sys/net/core/rmem_max
    [ -f "/proc/sys/net/core/wmem_max" ] && echo "16777216" > /proc/sys/net/core/wmem_max

    echo -e "${GREEN}✓ System settings optimized${NC}"
}

# Set balanced mode
set_balanced_mode() {
    echo -e "${YELLOW}Setting balanced mode...${NC}"

    # CPU governor
    if grep -q "schedutil" /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors; then
        cpupower frequency-set -g schedutil > /dev/null 2>&1
    else
        cpupower frequency-set -g ondemand > /dev/null 2>&1
    fi

    # GPU settings
    if command -v nvidia-smi &> /dev/null; then
        nvidia-settings -a "[gpu:0]/GpuPowerMizerMode=0" > /dev/null 2>&1
        nvidia-settings -a "[gpu:0]/GPUTextureFilteringMode=0" > /dev/null 2>&1
    fi

    # Reset system settings to defaults
    echo "20" > /proc/sys/vm/dirty_ratio
    echo "10" > /proc/sys/vm/dirty_background_ratio
    echo "60" > /proc/sys/vm/swappiness

    echo -e "${GREEN}✓ Balanced mode activated${NC}"
}

# Set power save mode
set_powersave_mode() {
    echo -e "${YELLOW}Setting power save mode...${NC}"

    cpupower frequency-set -g powersave > /dev/null 2>&1

    # Limit max frequency for power saving
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq; do
        if [ -d "$cpu" ]; then
            [ -f "$cpu/scaling_max_freq" ] && \
            echo "$(( $(cat "$cpu/cpuinfo_min_freq") + 500000 ))" > "$cpu/scaling_max_freq" 2>/dev/null
        fi
    done

    if command -v nvidia-smi &> /dev/null; then
        nvidia-settings -a "[gpu:0]/GpuPowerMizerMode=2" > /dev/null 2>&1
    fi

    echo -e "${GREEN}✓ Power save mode activated${NC}"
}

# Make settings persistent
make_persistent() {
    local mode=$1

    echo -e "${YELLOW}Making settings persistent...${NC}"

    # Enable cpupower service
    systemctl enable cpupower.service > /dev/null 2>&1

    # Create or update cpupower config
    local config_file="/etc/default/cpupower"
    case $mode in
        "performance")
            governor="performance"
            ;;
        "balanced")
            if grep -q "schedutil" /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors; then
                governor="schedutil"
            else
                governor="ondemand"
            fi
            ;;
        "powersave")
            governor="powersave"
            ;;
    esac

    if [ -f "$config_file" ]; then
        sed -i "s/^governor=.*/governor='$governor'/" "$config_file"
    else
        echo "governor='$governor'" > "$config_file"
        echo "max_freq=0" >> "$config_file"
        echo "min_freq=0" >> "$config_file"
    fi

    echo -e "${GREEN}✓ Settings will persist across reboots${NC}"
}

# Show current status with monitoring
show_status() {
    echo -e "${PURPLE}=== System Performance Status ===${NC}"
    get_cpu_info
    get_gpu_info

    echo -e "${CYAN}=== Current Frequencies ===${NC}"
    cpupower frequency-info | grep "current CPU frequency" | head -n 5

    echo -e "${CYAN}=== Memory Info ===${NC}"
    free -h

    if command -v nvidia-smi &> /dev/null; then
        echo -e "${CYAN}=== GPU Status ===${NC}"
        nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader
    fi
}

# Show menu
show_menu() {
    echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         Linux Performance Optimizer          ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    echo "1) 🚀 ULTIMATE Performance (CPU+GPU+System)"
    echo "2) ⚖️  Balanced Mode (Recommended for daily use)"
    echo "3) 🔋 Power Saving Mode"
    echo "4) 📊 Show Detailed Status"
    echo "5) ❌ Exit"
    echo ""
}

# Main function
main() {
    check_root
    check_tools

    while true; do
        show_menu
        read -p "Choose an option (1-5): " choice
        echo ""

        case $choice in
            1)
                echo -e "${RED}🚀 ACTIVATING ULTIMATE PERFORMANCE MODE${NC}"
                set_cpu_performance
                set_gpu_performance
                optimize_system
                echo ""
                read -p "Make these settings persistent across reboots? (y/n): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    make_persistent "performance"
                fi
                echo ""
                read -p "Press Enter to continue..."
                clear
                ;;
            2)
                echo -e "${GREEN}⚖️ ACTIVATING BALANCED MODE${NC}"
                set_balanced_mode
                echo ""
                read -p "Make these settings persistent across reboots? (y/n): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    make_persistent "balanced"
                fi
                echo ""
                read -p "Press Enter to continue..."
                clear
                ;;
            3)
                echo -e "${BLUE}🔋 ACTIVATING POWER SAVE MODE${NC}"
                set_powersave_mode
                echo ""
                read -p "Make these settings persistent across reboots? (y/n): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    make_persistent "powersave"
                fi
                echo ""
                read -p "Press Enter to continue..."
                clear
                ;;
            4)
                show_status
                echo ""
                read -p "Press Enter to continue..."
                clear
                ;;
            5)
                echo -e "${GREEN}Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"
                echo ""
                read -p "Press Enter to continue..."
                clear
                ;;
        esac
    done
}

# Run main function
main
