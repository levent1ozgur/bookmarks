---

# Stable Diffusion WebUI Auto-Installer for Arch Linux

A robust, automated installation script designed specifically for Arch Linux. This script resolves common dependency conflicts, Python versioning issues, and repository cloning errors (specifically the `stable-diffusion` and `generative-models` forks) to ensure a smooth setup of the AUTOMATIC1111 WebUI.

## 🚀 Quick Start

Run the following commands in your terminal to download and start the installation:

### 1. Download the Script

```bash
curl -O https://raw.githubusercontent.com/levent1ozgur/bookmarks/refs/heads/main/Stable%20Diffusion%20WebUI%20Auto-Installer%20for%20Arch%20Linux/install_sd_webui.sh

```

*Alternatively, create the file manually using `nano install_sd_webui.sh` and paste the script content.*

### 2. Make it Executable

```bash
chmod +x install_sd_webui.sh

```

### 3. Run the Installer

By default, the script installs to `~/stable-diffusion-webui`.

```bash
# Install to default location
./install_sd_webui.sh

# OR specify a custom directory
./install_sd_webui.sh /path/to/custom/directory

```

---

## 🛠️ What the Script Does

The installer automates the entire environment setup to bypass common Arch-specific hurdles:

* **Dependency Management:** Checks for and installs `Python 3.10` (via AUR), `git`, `bc`, `NVIDIA drivers`, and `CUDA`.
* **Repository Setup:** Clones the main AUTOMATIC1111 repository and pre-clones known problematic sub-repositories (including the `w-e-w` fork).
* **Environment Configuration:** Automatically sets up environment variables and Git configurations to prevent authentication prompts during the first launch.
* **Launch Utility:** Creates a simplified launch script for future use.
* **Safety Checks:** Interactive prompts ensure you remain in control of the installation process.

## ✨ Key Features

| Feature | Benefit |
| --- | --- |
| **Fully Automated** | Resolves "broken" fork issues without manual intervention. |
| **Python 3.10 Focus** | Specifically configures the correct Python environment required for SD. |
| **Clean Output** | Features color-coded logging for easy troubleshooting and status updates. |
| **Authentication Fix** | Bypasses common Git credential errors during the setup of sub-modules. |

---
