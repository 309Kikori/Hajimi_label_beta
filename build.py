# Build Script for Hajimi Label
# Usage: python build.py

import os
import subprocess
import sys

def build():
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
        "main.py"
    ]
    
    print("Running build command:", " ".join(cmd))
    subprocess.check_call(cmd)
    
    print("\nBuild complete!")
    print(f"Executable is located at: {os.path.abspath('dist/HajimiLabel/HajimiLabel.exe')}")

if __name__ == "__main__":
    build()
