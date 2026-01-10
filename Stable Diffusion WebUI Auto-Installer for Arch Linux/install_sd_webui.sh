#!/bin/bash

#############################################################################
# Stable Diffusion WebUI Auto-Installer for Arch Linux
# This script automates the installation process and handles common issues
#############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
INSTALL_DIR="${1:-$HOME/stable-diffusion-webui}"
PYTHON_VERSION="3.10"

print_info "==================================================================="
print_info "Stable Diffusion WebUI Auto-Installer for Arch Linux"
print_info "==================================================================="
print_info "Installation directory: $INSTALL_DIR"
echo ""

# Step 1: Check and install system dependencies
print_info "Step 1: Checking system dependencies..."

MISSING_PACKAGES=()

# Check for required packages
if ! command -v python${PYTHON_VERSION} &> /dev/null; then
    MISSING_PACKAGES+=("python310")
fi

if ! command -v git &> /dev/null; then
    MISSING_PACKAGES+=("git")
fi

if ! command -v bc &> /dev/null; then
    MISSING_PACKAGES+=("bc")
fi

if ! command -v wget &> /dev/null; then
    MISSING_PACKAGES+=("wget")
fi

# Check NVIDIA drivers
if ! pacman -Q nvidia-utils &> /dev/null; then
    MISSING_PACKAGES+=("nvidia-utils")
fi

# Check CUDA
if ! pacman -Q cuda &> /dev/null; then
    MISSING_PACKAGES+=("cuda")
fi

# Install missing packages
if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
    print_warning "Missing packages detected: ${MISSING_PACKAGES[*]}"
    read -p "Do you want to install missing packages? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Updating package database..."
        sudo pacman -Syy
        
        for package in "${MISSING_PACKAGES[@]}"; do
            if [ "$package" == "python310" ]; then
                print_info "Installing Python 3.10 from AUR..."
                if command -v yay &> /dev/null; then
                    yay -S --noconfirm python310
                else
                    print_warning "yay not found. Installing python310 manually from AUR..."
                    cd /tmp
                    git clone https://aur.archlinux.org/python310.git
                    cd python310
                    makepkg -si --noconfirm
                    cd -
                fi
            else
                print_info "Installing $package..."
                sudo pacman -S --noconfirm $package
            fi
        done
        print_info "All dependencies installed successfully!"
    else
        print_error "Installation cancelled. Please install missing packages manually."
        exit 1
    fi
else
    print_info "All system dependencies are already installed."
fi

# Step 2: Clone the repository
print_info "Step 2: Cloning Stable Diffusion WebUI repository..."

if [ -d "$INSTALL_DIR" ]; then
    print_warning "Installation directory already exists: $INSTALL_DIR"
    read -p "Do you want to remove it and reinstall? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Removing existing installation..."
        rm -rf "$INSTALL_DIR"
    else
        print_error "Installation cancelled."
        exit 1
    fi
fi

print_info "Cloning repository to $INSTALL_DIR..."
git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git "$INSTALL_DIR"

cd "$INSTALL_DIR"

# Step 3: Configure environment to use working repositories
print_info "Step 3: Configuring environment variables..."

# Create/update webui-user.sh with proper configuration
cat > webui-user.sh << 'EOF'
#!/bin/bash
#########################################################
# Stable Diffusion WebUI User Configuration
#########################################################

# Use working fork for Stability-AI repositories
# Using personal fork to ensure availability
export STABLE_DIFFUSION_REPO="https://github.com/levent1ozgur/stablediffusion.git"
export STABLE_DIFFUSION_XL_REPO="https://github.com/Stability-AI/generative-models.git"

# Use Python 3.10
export python_cmd="python3.10"

# Uncomment to add custom arguments (e.g., --medvram for low VRAM)
#export COMMANDLINE_ARGS="--medvram"

EOF

chmod +x webui-user.sh

print_info "Environment configuration complete!"

# Step 4: Create a clean Git configuration to avoid authentication issues
print_info "Step 4: Configuring Git..."

# Create a minimal gitconfig in the installation directory
cat > .gitconfig << 'EOF'
[credential]
    helper = 
[http]
    sslVerify = true
EOF

export GIT_CONFIG_GLOBAL="$INSTALL_DIR/.gitconfig"

print_info "Git configuration complete!"

# Step 5: Pre-clone the problematic repositories
print_info "Step 5: Pre-cloning required repositories..."

mkdir -p repositories

cd repositories

# Clone stable-diffusion using the working fork
if [ ! -d "stable-diffusion-stability-ai" ]; then
    print_info "Cloning stable-diffusion (using levent1ozgur fork)..."
    git clone https://github.com/levent1ozgur/stablediffusion.git stable-diffusion-stability-ai
fi

# Clone generative-models
if [ ! -d "generative-models" ]; then
    print_info "Cloning generative-models..."
    git clone https://github.com/Stability-AI/generative-models.git generative-models
fi

cd ..

print_info "Repository cloning complete!"

# Step 6: Create launch script
print_info "Step 6: Creating launch script..."

cat > launch.sh << 'EOF'
#!/bin/bash

# Change to the script's directory
cd "$(dirname "$0")"

# Export the working repository URLs
# Using personal fork to ensure availability
export STABLE_DIFFUSION_REPO="https://github.com/levent1ozgur/stablediffusion.git"
export STABLE_DIFFUSION_XL_REPO="https://github.com/Stability-AI/generative-models.git"

# Launch the WebUI
./webui.sh "$@"
EOF

chmod +x launch.sh

print_info "Launch script created!"

# Step 7: Summary and instructions
echo ""
print_info "==================================================================="
print_info "Installation Complete!"
print_info "==================================================================="
echo ""
print_info "Installation directory: $INSTALL_DIR"
echo ""
print_info "To start Stable Diffusion WebUI:"
print_info "  cd $INSTALL_DIR"
print_info "  ./launch.sh"
echo ""
print_info "Or directly:"
print_info "  ./webui.sh"
echo ""
print_info "The WebUI will be available at: http://127.0.0.1:7860"
echo ""
print_info "For low VRAM GPUs (6GB or less), edit webui-user.sh and uncomment:"
print_info "  export COMMANDLINE_ARGS=\"--medvram\""
echo ""
print_info "Your system specs:"
print_info "  GPU: $(lspci | grep -i vga | cut -d: -f3)"
print_info "  RAM: $(free -h | awk '/^Mem:/ {print $2}')"
echo ""
read -p "Do you want to start Stable Diffusion WebUI now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_info "Starting Stable Diffusion WebUI..."
    print_info "First launch will download the model (about 4GB) and may take several minutes..."
    ./launch.sh
else
    print_info "You can start it later by running: cd $INSTALL_DIR && ./launch.sh"
fi

print_info "Done!"
