# Linux Performance Optimizer

A Bash script for switching between performance profiles on Fedora Linux. It is designed for systems with AMD Ryzen CPUs and NVIDIA GPUs, and provides a simple terminal menu for applying tuned profiles, adjusting GPU performance settings, and checking current system status.

This repository is a practical performance-tuning utility, not a framework. It is meant for manual use on Fedora systems where `tuned` handles system-wide performance profiles and NVIDIA settings are managed separately.

## Features

* **Ultimate Performance Mode**: maximises system performance for demanding workloads such as gaming, compiling, and heavy multitasking
* **Balanced Mode**: provides a practical middle ground between responsiveness and efficiency
* **Power Saving Mode**: reduces power consumption for light workloads or quieter operation
* **Detailed Status View**: shows CPU, GPU, memory, and frequency information from one menu
* **Persistent System Profiles**: uses Fedora’s tuning tools to keep selected performance profiles active
* **NVIDIA GPU Tuning**: applies PowerMizer-related settings when NVIDIA tools are available
* **Colour-coded Terminal Output**: makes the menu and status output easier to read

## System Requirements

* **OS**: Fedora Linux
* **CPU**: AMD Ryzen processors
* **GPU**: NVIDIA graphics card
* **Desktop Session**: best suited to KDE Plasma and other desktop sessions where NVIDIA settings can be applied per session
* **Privileges**: root access is required

## Dependencies

### Required

The script expects the following tools to be available:

* `tuned`
* `tuned-adm`
* `systemd`
* `kernel-tools`
* `nvidia-smi`

### Optional

For GPU tuning and status reporting:

* `nvidia-settings`

On Fedora, these are typically installed with `dnf`, for example:

```bash
sudo dnf install tuned kernel-tools nvidia-settings
```

If your system uses a different NVIDIA package set, install the tools provided by your driver stack.

## Installation

1. Clone the repository:

```bash
git clone https://github.com/levent1ozgur/bookmarks.git
cd bookmarks/linux-performance-optimizer
```

2. Make the script executable:

```bash
chmod +x performance-optimizer.sh
```

3. Run it with root privileges:

```bash
sudo ./performance-optimizer.sh
```

## Usage

Run the script with `sudo` so it can apply system-level tuning changes:

```bash
sudo ./performance-optimizer.sh
```

### Menu Options

**1. Ultimate Performance Mode**

* applies the highest-performance system profile available
* prioritises responsiveness and throughput
* applies NVIDIA settings for maximum performance where supported
* best for gaming, benchmarking, compiling, and heavy workloads

**2. Balanced Mode**

* uses a balanced tuning profile
* keeps the system responsive without pushing every component to maximum power
* best for daily desktop use, multitasking, and general workloads

**3. Power Saving Mode**

* applies a lower-power tuning profile
* reduces power draw and heat output
* best for light usage, idle systems, and quieter operation

**4. Show Detailed Status**

* displays CPU model and current tuning state
* shows GPU information and active NVIDIA status
* reports memory usage
* displays current frequency and system performance information

**5. Exit**

* closes the script

## What It Optimises

### CPU and System

* performance profile selection
* CPU scheduling and tuning behaviour through Fedora’s tuning stack
* system-wide responsiveness versus power efficiency

### GPU

* NVIDIA PowerMizer-related performance behaviour
* GPU performance mode selection where supported
* basic GPU status visibility through NVIDIA utilities

### Monitoring

* current CPU and GPU state
* memory usage
* frequency and performance-related status information

## Important Notes

* **Use Fedora**: this version of the script is written for Fedora, not Arch Linux
* **Run as root**: the script needs elevated privileges to change tuning settings
* **GPU tuning depends on NVIDIA tools**: some GPU options are only available if `nvidia-settings` and the proprietary driver stack are installed
* **Settings may be session-based**: some NVIDIA options may need to be reapplied after login depending on your desktop session
* **Performance mode increases heat and power use**: check temperatures and stability after switching profiles

## Troubleshooting

**`tuned` or `tuned-adm` not found**

```bash
sudo dnf install tuned
```

**NVIDIA options are not applied**

* confirm the proprietary NVIDIA driver is installed
* check that `nvidia-smi` works
* install `nvidia-settings` if it is missing

**Status view does not show GPU information**

* verify that the NVIDIA driver is loaded correctly
* check whether the system actually has an NVIDIA GPU
* run `nvidia-smi` manually to confirm detection

**Performance changes do not persist after reboot**

* check that Fedora’s tuning service is enabled
* verify that the selected tuning profile is active after restart
* re-run the script if the GPU settings are session-based

## Disclaimer

This script changes system performance settings. Use it on hardware you understand and are prepared to tune. Incorrect settings may increase heat, power draw, or instability.

## Related

* [Fedora documentation for automatic power management](https://docs.fedoraproject.org/en-US/quick-docs/automatic-power-management-power2top/)
* [NVIDIA Linux driver documentation](https://download.nvidia.com/XFree86/Linux-x86_64/550.142/README/installationandconfiguration.html)
* [TuneD manual](https://tuned-project.org/docs/manual.html)
