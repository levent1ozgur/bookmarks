#!/bin/bash

# Linux Performance Optimizer — Fedora Edition (tuned-native)
# Built for AMD Ryzen 5 1600 + NVIDIA GTX 1660 SUPER + Fedora Linux (KDE Plasma, X11)
#
# Fedora's tuned.service owns CPU governor/sysctl management by default, so this
# version drives tuned-adm profiles instead of poking /sys and /proc directly —
# that avoids the previous approach getting silently reverted by tuned on the
# next reload. NVIDIA PowerMizer tuning stays separate since tuned doesn't touch it.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

CUSTOM_PERF_PROFILE="perfopt-performance"

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Please run as root (use sudo)${NC}"
        exit 1
    fi
}

check_tools() {
    local missing=()

    if ! command -v tuned-adm &> /dev/null; then
        missing+=("tuned")
    fi

    if ! command -v cpupower &> /dev/null; then
        echo -e "${YELLOW}cpupower not found (optional — only used for frequency display).${NC}"
        echo -e "Install with: ${GREEN}sudo dnf install kernel-tools${NC}"
    fi

    if ! command -v nvidia-smi &> /dev/null; then
        echo -e "${YELLOW}nvidia-smi not found. GPU optimizations will be skipped.${NC}"
        echo -e "${YELLOW}(Install the RPM Fusion NVIDIA driver: akmod-nvidia + xorg-x11-drv-nvidia-cuda)${NC}"
    elif ! command -v nvidia-settings &> /dev/null; then
        echo -e "${YELLOW}nvidia-settings not found. GPU PowerMizer tuning will be skipped.${NC}"
        echo -e "Install with: ${GREEN}sudo dnf install nvidia-settings${NC}"
    fi

    if ! command -v systemctl &> /dev/null; then
        missing+=("systemd")
    fi

    if [ ${#missing[@]} -ne 0 ]; then
        echo -e "${RED}Missing required tools: ${missing[*]}${NC}"
        echo -e "Install with: ${GREEN}sudo dnf install ${missing[*]}${NC}"
        exit 1
    fi

    if ! systemctl is-enabled --quiet tuned 2>/dev/null; then
        echo -e "${YELLOW}⚠ tuned.service is not enabled — profile changes won't survive a reboot.${NC}"
        echo -e "${YELLOW}  Enable with: sudo systemctl enable --now tuned${NC}"
    fi
}

# tuned doesn't manage the NVIDIA driver, and nvidia-settings needs the
# desktop session's X auth to work — sudo strips that by default.
detect_display_env() {
    [ -z "$DISPLAY" ] && export DISPLAY=":0"
    if [ -z "$XAUTHORITY" ]; then
        local target_user
        target_user=$(logname 2>/dev/null || who | awk '{print $1; exit}')
        [ -n "$target_user" ] && [ -f "/home/$target_user/.Xauthority" ] && \
            export XAUTHORITY="/home/$target_user/.Xauthority"
    fi
}

get_cpu_info() {
    echo -e "${CYAN}=== CPU Information ===${NC}"
    echo "Model: $(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
    echo "Cores: $(nproc)"
    echo "Current Governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo 'Unknown')"
    if command -v tuned-adm &> /dev/null; then
        echo "Active tuned profile: $(tuned-adm active 2>/dev/null | sed 's/Current active profile: //')"
    fi
    echo ""
}

get_gpu_info() {
    if command -v nvidia-smi &> /dev/null; then
        echo -e "${CYAN}=== GPU Information ===${NC}"
        nvidia-smi --query-gpu=name,driver_version,power.default_limit,power.max_limit --format=csv,noheader
        echo ""
    fi
}

# Custom profile layers our own VM/network sysctl tweaks on top of the stock
# throughput-performance profile, so they persist correctly under tuned
# instead of getting reset by it.
ensure_performance_profile() {
    local dir="/etc/tuned/${CUSTOM_PERF_PROFILE}"
    if [ ! -f "$dir/tuned.conf" ]; then
        mkdir -p "$dir"
        cat > "$dir/tuned.conf" <<EOF
[main]
summary=perf-optimizer: throughput-performance + extra VM/network tuning
include=throughput-performance

[sysctl]
vm.dirty_ratio=10
vm.dirty_background_ratio=5
vm.swappiness=10
fs.file-max=1000000
net.core.rmem_max=16777216
net.core.wmem_max=16777216
EOF
        echo -e "${GREEN}✓ Created custom tuned profile: ${CUSTOM_PERF_PROFILE}${NC}"
    fi
}

apply_tuned_profile() {
    local profile=$1
    tuned-adm profile "$profile"
    echo -e "${GREEN}✓ tuned profile set to: $profile${NC}"
}

set_gpu_performance() {
    if command -v nvidia-settings &> /dev/null; then
        detect_display_env
        echo -e "${YELLOW}Optimizing GPU performance...${NC}"
        nvidia-settings -a "[gpu:0]/GpuPowerMizerMode=1" > /dev/null 2>&1
        nvidia-settings -a "[gpu:0]/GPUTextureFilteringMode=1" > /dev/null 2>&1
        nvidia-settings -a "[gpu:0]/OpenGLImageSettings=3" > /dev/null 2>&1
        echo -e "${GREEN}✓ GPU set to maximum performance${NC}"
    fi
}

set_gpu_balanced() {
    if command -v nvidia-settings &> /dev/null; then
        detect_display_env
        nvidia-settings -a "[gpu:0]/GpuPowerMizerMode=0" > /dev/null 2>&1
        nvidia-settings -a "[gpu:0]/GPUTextureFilteringMode=0" > /dev/null 2>&1
        echo -e "${GREEN}✓ GPU set to adaptive/balanced${NC}"
    fi
}

set_gpu_powersave() {
    if command -v nvidia-settings &> /dev/null; then
        detect_display_env
        nvidia-settings -a "[gpu:0]/GpuPowerMizerMode=2" > /dev/null 2>&1
        echo -e "${GREEN}✓ GPU set to power saving${NC}"
    fi
}

# PowerMizer mode is per-X-session and doesn't survive reboot on its own —
# unlike the tuned profile, which already persists natively. This adds a
# KDE autostart entry so it reapplies at login instead.
persist_gpu_autostart() {
    local mode=$1 mizer_mode
    case $mode in
        performance) mizer_mode=1 ;;
        balanced)    mizer_mode=0 ;;
        powersave)   mizer_mode=2 ;;
    esac

    local target_user
    target_user=$(logname 2>/dev/null || who | awk '{print $1; exit}')
    if [ -z "$target_user" ]; then
        echo -e "${YELLOW}Could not determine desktop user — skipping GPU autostart.${NC}"
        return
    fi

    local autostart_dir="/home/$target_user/.config/autostart"
    mkdir -p "$autostart_dir"
    cat > "$autostart_dir/perfopt-gpu.desktop" <<EOF
[Desktop Entry]
Type=Application
Exec=nvidia-settings -a "[gpu:0]/GpuPowerMizerMode=$mizer_mode"
Hidden=false
NoDisplay=true
X-KDE-autostart-phase=1
Name=GPU PowerMizer restore ($mode)
EOF
    chown "$target_user":"$target_user" "$autostart_dir/perfopt-gpu.desktop"
    echo -e "${GREEN}✓ GPU PowerMizer mode will reapply automatically at next login${NC}"
}

maybe_persist_gpu() {
    local mode=$1
    if command -v nvidia-settings &> /dev/null; then
        read -p "Reapply this GPU setting automatically at each login? (y/n): " -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]] && persist_gpu_autostart "$mode"
    fi
}

show_status() {
    echo -e "${PURPLE}=== System Performance Status ===${NC}"
    get_cpu_info
    get_gpu_info

    if command -v cpupower &> /dev/null; then
        echo -e "${CYAN}=== Current Frequencies ===${NC}"
        cpupower frequency-info | grep "current CPU frequency" | head -n 5
    fi

    echo -e "${CYAN}=== Memory Info ===${NC}"
    free -h

    if command -v nvidia-smi &> /dev/null; then
        echo -e "${CYAN}=== GPU Status ===${NC}"
        nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader
    fi
}

show_menu() {
    echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   Linux Performance Optimizer — Fedora        ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    echo "1) 🚀 ULTIMATE Performance (tuned throughput-performance + GPU)"
    echo "2) ⚖️  Balanced Mode (tuned balanced — recommended for daily use)"
    echo "3) 🔋 Power Saving Mode (tuned powersave)"
    echo "4) 📊 Show Detailed Status"
    echo "5) ❌ Exit"
    echo ""
}

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
                ensure_performance_profile
                apply_tuned_profile "$CUSTOM_PERF_PROFILE"
                set_gpu_performance
                echo ""
                maybe_persist_gpu "performance"
                echo ""
                read -p "Press Enter to continue..."
                clear
                ;;
            2)
                echo -e "${GREEN}⚖️ ACTIVATING BALANCED MODE${NC}"
                apply_tuned_profile "balanced"
                set_gpu_balanced
                echo ""
                maybe_persist_gpu "balanced"
                echo ""
                read -p "Press Enter to continue..."
                clear
                ;;
            3)
                echo -e "${BLUE}🔋 ACTIVATING POWER SAVE MODE${NC}"
                apply_tuned_profile "powersave"
                set_gpu_powersave
                echo ""
                maybe_persist_gpu "powersave"
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

main
