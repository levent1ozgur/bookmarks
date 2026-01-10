# Stable Diffusion WebUI Auto-Installer for Arch Linux

An automated installation script for AUTOMATIC1111's Stable Diffusion WebUI on Arch Linux. This script handles all common installation issues and automatically configures your system based on GPU capabilities.

## Features

- ✅ **Fully Automated** - One command installation
- ✅ **Dependency Management** - Automatically installs all required packages
- ✅ **VRAM Auto-Detection** - Configures optimization flags based on your GPU
- ✅ **Fixed Repositories** - Uses working forks to avoid authentication issues
- ✅ **Python 3.10** - Automatically handles Python version requirements
- ✅ **Git Configuration** - Avoids common Git authentication problems

## System Requirements

### Minimum
- **OS**: Arch Linux
- **GPU**: NVIDIA GPU with 4GB+ VRAM
- **RAM**: 8GB+ recommended
- **Storage**: 10GB+ free space
- **Internet**: Required for downloading models

### Recommended
- **GPU**: NVIDIA GTX 1660 SUPER or better (6GB+ VRAM)
- **RAM**: 16GB+
- **Storage**: 20GB+ on SSD

## Quick Start

### 1. Download the Script

```bash
# Create the script file
nano install_sd_webui.sh

# Copy and paste the script content, then save (Ctrl+X, Y, Enter)
```

### 2. Make it Executable

```bash
chmod +x install_sd_webui.sh
```

### 3. Run the Installer

```bash
# Install to default location (~/stable-diffusion-webui)
./install_sd_webui.sh

# OR install to custom location
./install_sd_webui.sh /path/to/installation
```

### 4. Launch Stable Diffusion

```bash
cd ~/stable-diffusion-webui  # or your custom path
./webui.sh
```

Open your browser and go to: **http://127.0.0.1:7860**

## What Gets Installed

The script will automatically install:

- **System Packages**:
  - `python310` (from AUR)
  - `git`
  - `bc`
  - `wget`
  - `nvidia-utils` (NVIDIA drivers)
  - `cuda` (CUDA toolkit)

- **Stable Diffusion Components**:
  - AUTOMATIC1111 WebUI
  - Required Python dependencies
  - Stable Diffusion v1.5 model (~4GB)
  - All necessary repositories

## VRAM Optimization

The script automatically detects your GPU VRAM and configures optimization:

| VRAM | Optimization Flags | Performance |
|------|-------------------|-------------|
| < 4GB | `--lowvram --opt-split-attention` | Slower, but works |
| 4-8GB | `--medvram --opt-split-attention` | Balanced |
| ≥ 8GB | `--xformers` | Fastest |

**GTX 1660 SUPER (6GB)** will automatically use `--medvram` mode.

## Usage

### Starting the WebUI

```bash
cd ~/stable-diffusion-webui
./webui.sh
```

Or use the convenience script:

```bash
cd ~/stable-diffusion-webui
./launch.sh
```

### Stopping the WebUI

Press `Ctrl+C` in the terminal

### Accessing the Interface

Open browser: **http://127.0.0.1:7860**

## Customization

### Change Output Directory

Edit `webui-user.sh`:

```bash
export COMMANDLINE_ARGS="--medvram --output-dir /path/to/outputs"
```

### Adjust VRAM Settings

Edit `webui-user.sh` and modify:

```bash
# For lower VRAM usage
export COMMANDLINE_ARGS="--lowvram --opt-split-attention"

# For higher performance (if you have enough VRAM)
export COMMANDLINE_ARGS="--xformers"
```

### Additional Arguments

```bash
# Multiple arguments
export COMMANDLINE_ARGS="--medvram --autolaunch --theme dark"
```

Common options:
- `--autolaunch` - Auto-open browser
- `--share` - Create public link
- `--port 7861` - Change port
- `--theme dark` - Dark theme

## Moving to Another Drive

The installation is completely portable:

```bash
# Move the entire directory
mv ~/stable-diffusion-webui /mnt/other-drive/stable-diffusion-webui

# Run from new location
cd /mnt/other-drive/stable-diffusion-webui
./webui.sh
```

Everything (models, settings, outputs) moves with it!

## Troubleshooting

### Installation Fails

```bash
# Update package database
sudo pacman -Syy

# Run the installer again
./install_sd_webui.sh
```

### Out of VRAM Errors

Edit `webui-user.sh` and use lower VRAM settings:

```bash
export COMMANDLINE_ARGS="--lowvram --opt-split-attention"
```

### Slow Performance

- **First generation is always slower** (model loading)
- Reduce image resolution (512x512 instead of 768x768)
- Use fewer sampling steps (20 instead of 50)
- Enable xformers if you have enough VRAM

### Models Not Loading

Check that models are in:
```
stable-diffusion-webui/models/Stable-diffusion/
```

## File Structure

```
stable-diffusion-webui/
├── models/               # Downloaded models
│   └── Stable-diffusion/
├── outputs/              # Generated images
├── extensions/           # Installed extensions
├── repositories/         # Dependencies
├── webui.sh             # Main launch script
├── webui-user.sh        # User configuration
└── launch.sh            # Convenience launcher
```

## Updating

```bash
cd ~/stable-diffusion-webui
git pull
./webui.sh
```

## Uninstalling

```bash
# Simply delete the directory
rm -rf ~/stable-diffusion-webui
```

## Credits

- **WebUI**: [AUTOMATIC1111/stable-diffusion-webui](https://github.com/AUTOMATIC1111/stable-diffusion-webui)
- **Original Fork**: [w-e-w/stablediffusion](https://github.com/w-e-w/stablediffusion)

## License

This installer script is provided as-is. Please refer to the original projects for their respective licenses.

## Support

For issues with:
- **Stable Diffusion WebUI**: Check [AUTOMATIC1111's repo](https://github.com/AUTOMATIC1111/stable-diffusion-webui/issues)
- **Arch Linux packages**: Consult Arch Wiki

## Tips

- **First launch** takes 5-10 minutes (downloads model)
- **Subsequent launches** take ~30 seconds
- **Save your prompts** - the interface doesn't save them by default
- **Use the PNG Info tab** to view generation settings from saved images

---

**Enjoy creating AI art! 🎨**
