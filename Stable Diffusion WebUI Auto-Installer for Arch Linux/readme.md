# Download the script
curl -O https://raw.githubusercontent.com/[save-this-script-somewhere]/install_sd_webui.sh

# Or create it manually:
nano install_sd_webui.sh
# Paste the script content, save with Ctrl+X, Y, Enter

# Make it executable
chmod +x install_sd_webui.sh

# Run the installer (default location: ~/stable-diffusion-webui)
./install_sd_webui.sh

# Or specify a custom installation directory:
./install_sd_webui.sh /path/to/custom/directory
