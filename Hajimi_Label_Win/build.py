# Build Script for Hajimi Label
# Usage: python build.py

import os
import subprocess
import sys

try:
    from PIL import Image
except ImportError:
    Image = None

def build():
    # Change to script directory to ensure relative paths work
    script_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(script_dir)

    # Auto-convert PNG to ICO if needed
    if not os.path.exists("icon.ico") and os.path.exists("Hajimi_Label_icon.png"):
        if Image:
            print("Converting Hajimi_Label_icon.png to icon.ico...")
            try:
                img = Image.open("Hajimi_Label_icon.png")
                # Save as ICO containing multiple sizes for best scaling
                img.save("icon.ico", format='ICO', sizes=[(256, 256), (128, 128), (64, 64), (48, 48), (32, 32), (16, 16)])
                print("Conversion successful.")
            except Exception as e:
                print(f"Failed to convert icon: {e}")
        else:
            print("Warning: Pillow not installed. Cannot convert PNG to ICO automatically.")

    # Ensure PyInstaller is installed
    try:
        import PyInstaller
    except ImportError:
        print("PyInstaller not found. Installing...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "pyinstaller"])

    # Define build command
    # --noconfirm: Replace output directory without asking
    # --onedir: Create a directory containing the executable (easier for debugging than --onefile)
    # --windowed: Do not open a console window
    # --add-data: Include assets folder
    # --name: Name of the executable
    
    cmd = [
        "pyinstaller",
        "--noconfirm",
        "--onedir",
        "--windowed",
        "--add-data", "assets;assets",  # Windows separator is ;
        "--name", "HajimiLabel",
    ]

    # Check for icon
    if os.path.exists("icon.ico"):
        cmd.extend(["--icon", "icon.ico"])
        cmd.extend(["--add-data", "icon.ico;."])
        print("Using icon.ico")
    else:
        print("Warning: icon.ico not found. Executable will have default icon.")
        
    if os.path.exists("Hajimi_Label_icon.png"):
        cmd.extend(["--add-data", "Hajimi_Label_icon.png;."])

    cmd.append("main.py")
    
    print("Running build command:", " ".join(cmd))
    subprocess.check_call(cmd)
    
    print("\nBuild complete!")
    print(f"Executable is located at: {os.path.abspath('dist/HajimiLabel/HajimiLabel.exe')}")

if __name__ == "__main__":
    build()
