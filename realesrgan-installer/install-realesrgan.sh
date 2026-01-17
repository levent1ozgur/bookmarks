#!/bin/bash

###############################################################################
# Real-ESRGAN FULLY AUTOMATED Installer
# Installs EVERYTHING: Python, PyTorch, Models, WebUI with Image & Video support
# Works on: Arch, Ubuntu, Debian, Fedora
# Supports: NVIDIA, AMD, Intel GPUs with automatic optimization
# Self-contained: Everything in current directory
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Self-contained installation (auto-detect current directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_ROOT="${INSTALL_ROOT:-$SCRIPT_DIR}"
PYENV_DIR="$INSTALL_ROOT/.pyenv"
VENV_DIR="$INSTALL_ROOT/venv"
INSTALL_DIR="$INSTALL_ROOT/Real-ESRGAN"
PYTHON_VERSION="3.11.11"

###############################################################################
# System Detection
###############################################################################

detect_distro() {
    print_info "Detecting Linux distribution..."

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        print_success "Distribution: $NAME"
    else
        print_warning "Cannot detect distribution, assuming Arch-based"
        DISTRO="arch"
    fi
}

detect_gpu() {
    print_info "Detecting GPU hardware..."

    GPU_TYPE="none"
    GPU_NAME="Unknown"
    USE_HALF_PRECISION=false

    # Check for NVIDIA GPU
    if command -v nvidia-smi &> /dev/null; then
        GPU_TYPE="nvidia"
        GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n1 || echo "NVIDIA GPU")
        print_success "NVIDIA GPU detected: $GPU_NAME"

        # Known problematic GPUs for FP16
        if [[ "$GPU_NAME" == *"1660"* ]] || [[ "$GPU_NAME" == *"1650"* ]] || \
           [[ "$GPU_NAME" == *"1060"* ]] || [[ "$GPU_NAME" == *"1050"* ]] || \
           [[ "$GPU_NAME" == *"1630"* ]] || [[ "$GPU_NAME" == *"16"[0-9][0-9]* ]]; then
            print_warning "GPU known to have FP16 issues. Using FP32 for stability."
            USE_HALF_PRECISION=false
        else
            print_info "Enabling half-precision (FP16) for faster processing."
            USE_HALF_PRECISION=true
        fi

    # Check for AMD GPU
    elif command -v rocm-smi &> /dev/null || lspci 2>/dev/null | grep -i 'vga.*amd' &> /dev/null; then
        GPU_TYPE="amd"
        GPU_NAME="AMD GPU"
        print_success "AMD GPU detected: $GPU_NAME"
        print_warning "Using FP32 for AMD compatibility."
        USE_HALF_PRECISION=false

    # Check for Intel GPU
    elif lspci 2>/dev/null | grep -i 'vga.*intel' &> /dev/null; then
        GPU_TYPE="cpu"
        GPU_NAME="Intel iGPU (using CPU mode)"
        print_success "Intel GPU detected, using CPU mode"
        USE_HALF_PRECISION=false
    else
        print_warning "No dedicated GPU detected. Using CPU mode."
        GPU_TYPE="cpu"
        USE_HALF_PRECISION=false
    fi

    print_info "Configuration: GPU_TYPE=$GPU_TYPE, HALF_PRECISION=$USE_HALF_PRECISION"
}

###############################################################################
# Installation Functions
###############################################################################

install_system_packages() {
    print_info "Installing system dependencies (git, wget, ffmpeg)..."

    case $DISTRO in
        arch|manjaro|endeavouros)
            # Try with sudo first, fallback to direct if in distrobox
            if sudo -n true 2>/dev/null; then
                sudo pacman -S --needed --noconfirm git wget curl ffmpeg base-devel openssl zlib xz tk || true
            else
                pacman -S --needed --noconfirm git wget curl ffmpeg base-devel openssl zlib xz tk 2>/dev/null || {
                    print_warning "Cannot install system packages without sudo. Continuing anyway..."
                }
            fi
            ;;
        ubuntu|debian|pop|linuxmint)
            if sudo -n true 2>/dev/null; then
                sudo apt update && sudo apt install -y git wget curl ffmpeg build-essential \
                    libssl-dev zlib1g-dev libbz2-dev libreadline-dev \
                    libsqlite3-dev llvm libncurses5-dev tk-dev || true
            else
                print_warning "Cannot install system packages without sudo. Continuing anyway..."
            fi
            ;;
        fedora|rhel|centos)
            if sudo -n true 2>/dev/null; then
                sudo dnf install -y git wget curl ffmpeg gcc gcc-c++ make \
                    openssl-devel zlib-devel bzip2-devel readline-devel \
                    sqlite-devel llvm ncurses-devel tk-devel || true
            else
                print_warning "Cannot install system packages without sudo. Continuing anyway..."
            fi
            ;;
    esac

    # Verify ffmpeg
    if command -v ffmpeg &> /dev/null; then
        print_success "ffmpeg installed - video support enabled"
    else
        print_warning "ffmpeg not found - video support disabled"
    fi

    print_success "System packages installation completed"
}

install_pyenv() {
    print_info "Setting up pyenv in $PYENV_DIR..."

    if [ -d "$PYENV_DIR" ]; then
        print_info "pyenv already installed"
    else
        print_info "Installing pyenv..."
        export PYENV_ROOT="$PYENV_DIR"
        curl -s https://pyenv.run | bash

        # Move to custom location if needed
        if [ -d "$HOME/.pyenv" ] && [ "$HOME/.pyenv" != "$PYENV_DIR" ]; then
            mv "$HOME/.pyenv" "$PYENV_DIR"
        fi
    fi

    # Setup pyenv for current session
    export PYENV_ROOT="$PYENV_DIR"
    export PATH="$PYENV_ROOT/bin:$PATH"

    if command -v pyenv &> /dev/null; then
        eval "$(pyenv init -)"
    else
        print_error "pyenv installation failed"
        exit 1
    fi

    print_success "pyenv configured"
}

install_python() {
    print_info "Installing Python $PYTHON_VERSION (this may take 5-10 minutes)..."

    if pyenv versions 2>/dev/null | grep -q "$PYTHON_VERSION"; then
        print_info "Python $PYTHON_VERSION already installed"
    else
        print_info "Compiling Python $PYTHON_VERSION from source..."
        pyenv install $PYTHON_VERSION || {
            print_error "Failed to install Python $PYTHON_VERSION"
            exit 1
        }
    fi

    PYTHON_CMD="$PYENV_DIR/versions/$PYTHON_VERSION/bin/python"
    print_success "Python $PYTHON_VERSION installed successfully"
}

create_venv() {
    print_info "Creating isolated Python environment..."

    if [ -d "$VENV_DIR" ]; then
        print_warning "Removing existing virtual environment..."
        rm -rf "$VENV_DIR"
    fi

    $PYTHON_CMD -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"

    print_info "Upgrading pip..."
    pip install --upgrade pip setuptools wheel -q

    print_success "Virtual environment created"
}

install_pytorch() {
    print_info "Installing PyTorch with $GPU_TYPE support..."

    case $GPU_TYPE in
        nvidia)
            print_info "Installing PyTorch with CUDA 12.1 support..."
            pip install torch torchvision --index-url https://download.pytorch.org/whl/cu121
            ;;
        amd)
            print_info "Installing PyTorch with ROCm support..."
            pip install torch torchvision --index-url https://download.pytorch.org/whl/rocm6.2
            ;;
        cpu|*)
            print_info "Installing CPU-only PyTorch..."
            pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu
            ;;
    esac

    print_success "PyTorch installed"
}

install_realesrgan() {
    print_info "Installing Real-ESRGAN and dependencies..."

    if [ -d "$INSTALL_DIR" ]; then
        print_warning "Removing existing Real-ESRGAN directory..."
        rm -rf "$INSTALL_DIR"
    fi

    print_info "Cloning Real-ESRGAN repository..."
    git clone https://github.com/xinntao/Real-ESRGAN.git "$INSTALL_DIR" -q
    cd "$INSTALL_DIR"

    print_info "Installing BasicSR framework..."
    pip install -q git+https://github.com/XPixelGroup/BasicSR.git

    print_info "Installing face enhancement libraries..."
    pip install -q facexlib gfpgan

    print_info "Installing image processing libraries..."
    pip install -q opencv-python pillow numpy tqdm lmdb pyyaml yapf

    print_info "Installing Gradio for web interface..."
    pip install -q gradio

    print_info "Installing Real-ESRGAN package..."
    pip install -q -e .

    print_success "Real-ESRGAN and all dependencies installed"
}

download_models() {
    print_info "Downloading AI models (this will take a few minutes)..."

    mkdir -p "$INSTALL_DIR/weights"
    cd "$INSTALL_DIR/weights"

    models=(
        "RealESRGAN_x4plus.pth|https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth|General purpose 4x upscaler"
        "RealESRGAN_x4plus_anime_6B.pth|https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.2.4/RealESRGAN_x4plus_anime_6B.pth|Anime/illustration upscaler"
        "RealESRNet_x4plus.pth|https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.1/RealESRNet_x4plus.pth|Sharp upscaler"
        "GFPGANv1.3.pth|https://github.com/TencentARC/GFPGAN/releases/download/v1.3.0/GFPGANv1.3.pth|Face enhancement"
    )

    for model in "${models[@]}"; do
        IFS='|' read -r filename url description <<< "$model"
        if [ ! -f "$filename" ]; then
            print_info "Downloading $description..."
            wget -q --show-progress "$url" -O "$filename"
        else
            print_info "$description already downloaded"
        fi
    done

    cd "$INSTALL_DIR"
    print_success "All models downloaded (total ~500MB)"
}

create_webui() {
    print_info "Creating hardware-optimized WebUI with Image & Video support..."

    cat > "$INSTALL_DIR/webui.py" << 'WEBUI_EOF'
import gradio as gr
import cv2
import torch
import numpy as np
from basicsr.archs.rrdbnet_arch import RRDBNet
from realesrgan import RealESRGANer
from gfpgan import GFPGANer
import os
import tempfile
import subprocess
import shutil

# Hardware configuration - AUTO-CONFIGURED BY INSTALLER
USE_HALF_PRECISION = USE_HALF_PRECISION_PLACEHOLDER
GPU_TYPE = "GPU_TYPE_PLACEHOLDER"

def upscale_image(image, model_name, scale, face_enhance):
    """Upscale a single image"""
    if image is None:
        return None

    if image.dtype == np.float32 or image.dtype == np.float64:
        if image.max() <= 1.0:
            image = (image * 255).astype(np.uint8)
        else:
            image = image.astype(np.uint8)

    upsampler = get_upsampler(model_name)

    try:
        if face_enhance and os.path.exists('weights/GFPGANv1.3.pth'):
            face_enhancer = GFPGANer(
                model_path='weights/GFPGANv1.3.pth',
                upscale=scale,
                arch='clean',
                channel_multiplier=2,
                bg_upsampler=upsampler
            )
            _, _, output = face_enhancer.enhance(image, has_aligned=False, only_center_face=False, paste_back=True)
        else:
            output, _ = upsampler.enhance(image, outscale=scale)

        if np.isnan(output).any() or np.isinf(output).any() or output.max() == 0:
            print("ERROR: Invalid output detected!")
            return None

        return np.clip(output, 0, 255).astype(np.uint8)
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        return None

def upscale_video(video_path, model_name, scale, face_enhance, fps=None, progress=gr.Progress()):
    """Upscale video with audio preservation"""
    if not video_path:
        return None, "No video uploaded"

    try:
        progress(0, desc="Initializing...")

        # Check ffmpeg
        ffmpeg_path = shutil.which('ffmpeg')
        if not ffmpeg_path:
            for path in ['/usr/bin/ffmpeg', '/usr/local/bin/ffmpeg', '/bin/ffmpeg']:
                if os.path.exists(path):
                    ffmpeg_path = path
                    break

        if not ffmpeg_path:
            return None, "❌ ffmpeg not found. Install: sudo pacman -S ffmpeg"

        cap = cv2.VideoCapture(video_path)
        if not cap.isOpened():
            return None, "Error: Could not open video"

        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        original_fps = cap.get(cv2.CAP_PROP_FPS)
        width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        output_fps = fps if fps else original_fps

        upsampler = get_upsampler(model_name)

        temp_video = tempfile.NamedTemporaryFile(delete=False, suffix='_novideo.mp4').name
        final_output = tempfile.NamedTemporaryFile(delete=False, suffix='.mp4').name

        out = None
        frame_count = 0

        progress(0.1, desc=f"Processing {total_frames} frames...")

        while True:
            ret, frame = cap.read()
            if not ret:
                break

            frame_count += 1

            try:
                if face_enhance and os.path.exists('weights/GFPGANv1.3.pth'):
                    face_enhancer = GFPGANer(
                        model_path='weights/GFPGANv1.3.pth',
                        upscale=scale,
                        arch='clean',
                        channel_multiplier=2,
                        bg_upsampler=upsampler
                    )
                    _, _, enhanced = face_enhancer.enhance(frame, has_aligned=False, only_center_face=False, paste_back=True)
                else:
                    enhanced, _ = upsampler.enhance(frame, outscale=scale)

                if out is None:
                    h, w = enhanced.shape[:2]
                    out = cv2.VideoWriter(temp_video, cv2.VideoWriter_fourcc(*'mp4v'), output_fps, (w, h))

                out.write(enhanced)
            except Exception as e:
                print(f"Frame {frame_count} error: {e}")
                continue

            progress(0.1 + (frame_count / total_frames) * 0.7, desc=f"Frame {frame_count}/{total_frames}")

        cap.release()
        if out:
            out.release()

        progress(0.85, desc="Merging audio...")

        # Merge audio
        try:
            result = subprocess.run([
                ffmpeg_path, '-y',
                '-i', temp_video,
                '-i', video_path,
                '-c:v', 'libx264',
                '-preset', 'medium',
                '-crf', '23',
                '-c:a', 'aac',
                '-b:a', '192k',
                '-map', '0:v:0',
                '-map', '1:a:0?',
                '-shortest',
                final_output
            ], capture_output=True, text=True)

            if result.returncode != 0:
                final_output = temp_video
                audio_status = "⚠️ Audio merge failed"
            else:
                audio_status = "✅ Audio preserved"
                try:
                    os.unlink(temp_video)
                except:
                    pass
        except Exception as e:
            print(f"Audio merge error: {e}")
            final_output = temp_video
            audio_status = "⚠️ No audio"

        progress(1.0, desc="Complete!")

        info = f"""✅ Video upscaled!

Original: {width}x{height} @ {original_fps:.1f} FPS
Upscaled: {int(width*scale)}x{int(height*scale)} @ {output_fps:.1f} FPS
Frames: {frame_count}
Model: {model_name}
Audio: {audio_status}"""

        return final_output, info
    except Exception as e:
        import traceback
        traceback.print_exc()
        return None, f"Error: {e}"

def get_upsampler(model_name):
    """Get configured upsampler with memory-optimized settings"""
    configs = {
        "RealESRGAN_x4plus": {
            "scale": 4,
            "filename": "RealESRGAN_x4plus.pth",
            "model": RRDBNet(num_in_ch=3, num_out_ch=3, num_feat=64, num_block=23, num_grow_ch=32, scale=4)
        },
        "RealESRGAN_x4plus_anime": {
            "scale": 4,
            "filename": "RealESRGAN_x4plus_anime_6B.pth",
            "model": RRDBNet(num_in_ch=3, num_out_ch=3, num_feat=64, num_block=6, num_grow_ch=32, scale=4)
        },
        "RealESRNet_x4plus": {
            "scale": 4,
            "filename": "RealESRNet_x4plus.pth",
            "model": RRDBNet(num_in_ch=3, num_out_ch=3, num_feat=64, num_block=23, num_grow_ch=32, scale=4)
        }
    }

    config = configs[model_name]
    device = 'cuda' if torch.cuda.is_available() and GPU_TYPE == 'nvidia' else 'cpu'

    # Reduced tile size for 6GB VRAM GPUs (GTX 1660 SUPER, etc.)
    tile_size = 200 if device == 'cuda' else 100

    return RealESRGANer(
        scale=config["scale"],
        model_path=f'weights/{config["filename"]}',
        model=config["model"],
        tile=tile_size,
        tile_pad=10,
        pre_pad=0,
        half=USE_HALF_PRECISION and device == 'cuda',
        device=device
    )

# Gradio interface
with gr.Blocks(title="Real-ESRGAN") as demo:
    gr.Markdown("# 🎨 Real-ESRGAN Image & Video Upscaler")

    device = "CUDA (GPU)" if torch.cuda.is_available() and GPU_TYPE == 'nvidia' else "CPU"
    gpu = torch.cuda.get_device_name(0) if device == "CUDA (GPU)" else "None"
    precision = "FP16" if USE_HALF_PRECISION else "FP32"

    gr.Markdown(f"**Device:** {device} | **GPU:** {gpu} | **Precision:** {precision}")

    with gr.Tabs():
        with gr.Tab("📷 Image"):
            with gr.Row():
                with gr.Column():
                    img_in = gr.Image(label="Upload Image")
                    img_model = gr.Dropdown(
                        ["RealESRGAN_x4plus", "RealESRGAN_x4plus_anime", "RealESRNet_x4plus"],
                        value="RealESRGAN_x4plus",
                        label="Model"
                    )
                    img_scale = gr.Slider(2, 4, 4, 1, label="Upscale Factor")
                    img_face = gr.Checkbox(label="Face Enhancement")
                    img_btn = gr.Button("🚀 Upscale", variant="primary", size="lg")
                with gr.Column():
                    img_out = gr.Image(label="Result")
            img_btn.click(upscale_image, [img_in, img_model, img_scale, img_face], img_out)

        with gr.Tab("🎬 Video"):
            gr.Markdown("⚠️ **Video processing:** Start with short clips. Requires ffmpeg. Processing time: ~5-10 min per 30s video with GPU.")
            with gr.Row():
                with gr.Column():
                    vid_in = gr.Video(label="Upload Video")
                    vid_model = gr.Dropdown(
                        ["RealESRGAN_x4plus", "RealESRGAN_x4plus_anime", "RealESRNet_x4plus"],
                        value="RealESRGAN_x4plus",
                        label="Model"
                    )
                    vid_scale = gr.Slider(2, 4, 4, 1, label="Upscale Factor")
                    vid_fps = gr.Number(label="FPS (optional)", value=None)
                    vid_face = gr.Checkbox(label="Face Enhancement")
                    vid_btn = gr.Button("🚀 Upscale Video", variant="primary", size="lg")
                with gr.Column():
                    vid_out = gr.Video(label="Result")
                    vid_info = gr.Textbox(label="Info", lines=6)
            vid_btn.click(upscale_video, [vid_in, vid_model, vid_scale, vid_face, vid_fps], [vid_out, vid_info])

    gr.Markdown("""
### 💡 Tips
- **RealESRGAN_x4plus:** Photos, real images
- **RealESRGAN_x4plus_anime:** Anime, illustrations
- **RealESRNet_x4plus:** Maximum sharpness
- **Memory:** Lower upscale factor (2x) uses less VRAM
""")

if __name__ == "__main__":
    print("=" * 60)
    print("Real-ESRGAN Image & Video Upscaler")
    print("=" * 60)
    print(f"GPU: {GPU_TYPE.upper()}")
    print(f"Precision: {'FP16' if USE_HALF_PRECISION else 'FP32'}")
    print(f"Device: {'CUDA' if torch.cuda.is_available() else 'CPU'}")
    print("=" * 60)
    print("WebUI: http://localhost:7860")
    print("=" * 60)
    demo.launch(server_name="0.0.0.0", server_port=7860, share=False, theme=gr.themes.Soft())
WEBUI_EOF

    # Replace placeholders
    PYTHON_BOOL=$([ "$USE_HALF_PRECISION" = true ] && echo "True" || echo "False")
    sed -i "s/USE_HALF_PRECISION_PLACEHOLDER/$PYTHON_BOOL/g" "$INSTALL_DIR/webui.py"
    sed -i "s/GPU_TYPE_PLACEHOLDER/$GPU_TYPE/g" "$INSTALL_DIR/webui.py"

    print_success "WebUI created with Image & Video support"
}

create_launcher() {
    print_info "Creating launcher scripts..."

    cat > "$INSTALL_ROOT/run.sh" << LAUNCHER
#!/bin/bash
source "$VENV_DIR/bin/activate"
cd "$INSTALL_DIR"
python webui.py
LAUNCHER

    chmod +x "$INSTALL_ROOT/run.sh"

    cat > "$INSTALL_ROOT/README.txt" << README
Real-ESRGAN Installation
========================

Location: $INSTALL_ROOT

START:
  cd $INSTALL_ROOT
  ./run.sh

UNINSTALL:
  rm -rf $INSTALL_ROOT

Structure:
  .pyenv/         - Python 3.11
  venv/           - Virtual environment
  Real-ESRGAN/    - App + models
  run.sh          - Launcher

Total size: ~3-4 GB
README

    print_success "Launchers created"
}

###############################################################################
# Main
###############################################################################

main() {
    clear
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                                                           ║"
    echo "║     Real-ESRGAN Installer with Video Support             ║"
    echo "║                                                           ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""

    detect_distro
    detect_gpu

    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                  Installation Plan                        ║"
    echo "╠═══════════════════════════════════════════════════════════╣"
    printf "║ %-25s %-30s ║\n" "Location:" "${INSTALL_ROOT:0:30}"
    printf "║ %-25s %-30s ║\n" "Distribution:" "$DISTRO"
    printf "║ %-25s %-30s ║\n" "GPU Type:" "$GPU_TYPE"
    printf "║ %-25s %-30s ║\n" "GPU Name:" "${GPU_NAME:0:30}"
    printf "║ %-25s %-30s ║\n" "Precision:" "$([ "$USE_HALF_PRECISION" = true ] && echo "FP16 (Fast)" || echo "FP32 (Stable)")"
    printf "║ %-25s %-30s ║\n" "Python:" "$PYTHON_VERSION"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""

    print_info "Will install:"
    echo "  ✓ Python 3.11 (via pyenv)"
    echo "  ✓ PyTorch with $([ "$GPU_TYPE" = "nvidia" ] && echo "CUDA" || echo "CPU")"
    echo "  ✓ Real-ESRGAN + dependencies"
    echo "  ✓ AI models (~500MB)"
    echo "  ✓ WebUI (Image & Video support)"
    echo ""

    read -p "Continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi

    echo ""
    print_info "Starting installation (~10-15 minutes)..."
    echo ""

    mkdir -p "$INSTALL_ROOT"

    install_system_packages
    install_pyenv
    install_python
    create_venv
    install_pytorch
    install_realesrgan
    download_models
    create_webui
    create_launcher

    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║          ✨ Installation Complete! ✨                    ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    print_success "Everything installed to: $INSTALL_ROOT"
    echo ""
    print_info "TO START:"
    print_info "  cd $INSTALL_ROOT"
    print_info "  ./run.sh"
    echo ""
    print_info "TO UNINSTALL:"
    print_info "  rm -rf $INSTALL_ROOT"
    echo ""
    print_info "GPU: $GPU_NAME"
    print_info "Precision: $([ "$USE_HALF_PRECISION" = true ] && echo "FP16" || echo "FP32 (prevents VRAM issues)")"
    print_info "Tile size: 200 (optimized for 6GB VRAM)"
    echo ""

    read -p "🚀 Start now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        source "$VENV_DIR/bin/activate"
        cd "$INSTALL_DIR"
        python webui.py
    fi
}

# Run main function
main
