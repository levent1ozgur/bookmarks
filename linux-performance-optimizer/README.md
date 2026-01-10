# Ultimate Linux Performance Optimizer

A powerful Bash script for optimizing system performance on Linux, specifically tuned for AMD Ryzen processors and NVIDIA GPUs. This tool provides an interactive menu to easily switch between performance modes and optimize CPU, GPU, and system settings.

## 🎯 Features

- **🚀 Ultimate Performance Mode**: Maximum CPU and GPU performance for gaming and heavy workloads
- **⚖️ Balanced Mode**: Optimized daily use with good performance and efficiency
- **🔋 Power Saving Mode**: Reduce power consumption when on battery or idle
- **📊 Real-time Monitoring**: View detailed CPU, GPU, and memory status
- **💾 Persistent Settings**: Option to save configurations across reboots
- **🎨 Color-coded Interface**: Easy-to-read terminal output

## ⚙️ System Requirements

- **OS**: Any Linux distribution with `cpupower` (tested on Arch Linux)
- **CPU**: AMD Ryzen processors (tested on Ryzen 5 1600, works with other CPUs)
- **GPU**: NVIDIA graphics card (tested on GTX 1660 SUPER)
- **Privileges**: Root access required

## 📦 Dependencies

### Required
```bash
sudo pacman -S cpupower
```

### Optional (for GPU optimization)
```bash
sudo pacman -S nvidia-utils nvidia-settings
```

For other distributions:
- **Debian/Ubuntu**: `sudo apt install linux-cpupower nvidia-utils`
- **Fedora**: `sudo dnf install kernel-tools nvidia-settings`

## 🚀 Installation

1. Clone the repository:
```bash
git clone https://github.com/levent1ozgur/linux-performance-optimizer.git
cd linux-performance-optimizer
```

2. Make the script executable:
```bash
chmod +x performance-optimizer.sh
```

3. Run the script:
```bash
sudo ./performance-optimizer.sh
```

## 📖 Usage

Run the script with sudo privileges:
```bash
sudo ./performance-optimizer.sh
```

### Menu Options

**1. Ultimate Performance Mode**
- Sets CPU governor to `performance`
- Maximizes CPU frequency and boost
- Sets GPU to maximum performance mode
- Optimizes VM dirty ratios and swappiness
- Ideal for: Gaming, video editing, compiling, benchmarking

**2. Balanced Mode**
- Sets CPU governor to `schedutil` or `ondemand`
- Adaptive performance based on load
- GPU adaptive performance
- Default system settings
- Ideal for: Daily use, multitasking, general computing

**3. Power Saving Mode**
- Sets CPU governor to `powersave`
- Limits maximum CPU frequency
- GPU power-saving mode
- Ideal for: Battery life, light workloads, background tasks

**4. Show Detailed Status**
- Displays CPU information and current governor
- Shows GPU status, temperature, and utilization
- Memory usage statistics
- Current frequencies for all cores

## 🔧 What It Optimizes

### CPU Optimizations
- CPU frequency governor (performance/balanced/powersave)
- Scaling frequency limits
- Energy performance bias
- Per-core frequency management

### GPU Optimizations
- PowerMizer mode control
- Texture filtering quality
- OpenGL image settings

### System Optimizations
- VM dirty ratio (write caching)
- Swappiness (swap usage aggressiveness)
- File descriptor limits
- Network buffer sizes

## ⚠️ Important Notes

- **Always run with sudo**: Root privileges are required to modify system settings
- **Settings are temporary**: Unless you choose to make them persistent, settings reset on reboot
- **Persistent mode**: Uses systemd's `cpupower.service` to apply settings at boot
- **GPU optimization**: Requires NVIDIA proprietary drivers and `nvidia-settings`
- **Heat warning**: Performance mode generates more heat - ensure adequate cooling

## 🔄 Making Settings Persistent

When choosing a performance mode, the script will ask:
```
Make these settings persistent across reboots? (y/n):
```

Selecting `y` will:
- Enable the `cpupower` systemd service
- Configure `/etc/default/cpupower` with your chosen governor
- Apply settings automatically on every boot

## 📊 Monitoring

To monitor system performance while running the optimizations:

```bash
# CPU frequencies
watch -n 1 'grep MHz /proc/cpuinfo'

# GPU monitoring
watch -n 1 nvidia-smi

# Temperature monitoring
sensors
```

## 🛠️ Troubleshooting

**Script says "cpupower not found"**
```bash
sudo pacman -S cpupower
```

**GPU optimizations not working**
- Ensure NVIDIA proprietary drivers are installed
- Check if `nvidia-settings` is available
- Verify GPU is properly detected: `nvidia-smi`

**Settings not persisting**
- Check if `cpupower.service` is enabled: `systemctl status cpupower`
- Verify `/etc/default/cpupower` exists and has correct permissions

**Performance mode causing system instability**
- Switch to balanced mode
- Check system temperatures
- Ensure adequate power supply and cooling


## 🔗 Related Resources

- [Arch Wiki: CPU Frequency Scaling](https://wiki.archlinux.org/title/CPU_frequency_scaling)
- [NVIDIA Linux Documentation](https://download.nvidia.com/XFree86/Linux-x86_64/latest/README/)
- [Kernel Documentation: CPUFreq](https://www.kernel.org/doc/html/latest/admin-guide/pm/cpufreq.html)

---

**Disclaimer**: This script modifies system settings. While designed to be safe, use at your own risk. Always ensure you have adequate cooling and a stable power supply when using performance modes.
