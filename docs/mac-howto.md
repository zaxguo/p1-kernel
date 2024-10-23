9/19/24: tested on MBA M2, Sonoma 14.5, Homebrew 4.3.20

(notes-- cross toolchain can be tricky. e.g. aarch64-linux-gnu-gcc-9. gcc-9 unavaialble on newest mac.)
also - gdb-multiarch not available? configuration can be tough
also requires additional testing for anything we do in the future 

at this time, stick to linux/wsl2. provide tools for mac users to compile on server & download 
(or linux vm on mac??)

## Qemu
To install `qemu-system-aarch64` on macOS via Homebrew, you can follow these steps:

1. **Open Terminal** on your Mac.

2. **Update Homebrew** to ensure you have the latest formulas:
   ```bash
   brew update
   ```

3. **Install QEMU**, which includes `qemu-system-aarch64`:
   ```bash
   brew install qemu
   ```

4. Once the installation is complete, you can verify that `qemu-system-aarch64` is installed by running:
   ```bash
   qemu-system-aarch64 --version
   ```

This will display the version of QEMU, confirming that it's installed successfully.

Tested: qemu version 9.0.0 

## git
```bash
brew install git
```

## Compilation toolchain

To install `aarch64-linux-gnu-gcc-9` (version 9) via Homebrew on macOS, follow these steps:

### 1. **Install Homebrew (if not already installed)**
Make sure you have Homebrew installed. If it's not installed, run this command:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2. **Tap the Homebrew GCC ARM Toolchain**
Homebrew provides a cross-compilation toolchain for ARM, but to install a specific version like GCC 9, you need to tap into an older version of the package. You can use the `homebrew/cask-versions` or `homebrew/core` formula repository.

Run:
```bash
brew tap homebrew/cask-versions
```

### 3. **Install the Specific Version of GCC 9**
By default, Homebrew installs the latest version of `aarch64-linux-gnu-gcc`, but for a specific version like GCC 9, follow these steps:

1. **Check Available Versions**:
   ```bash
   brew search gcc@9
   ```

2. **Install `gcc@9`**:
   Install GCC 9 by running:
   ```bash
   brew install gcc@9
   ```

3. **Install the ARM Toolchain**:
   Next, install the ARM cross-compilation toolchain for Linux:
   ```bash
   brew install aarch64-linux-gnu
   ```

### 4. **Set up GCC 9 as the Cross-Compiler**
After installing GCC 9, you need to set the `gcc-9` binaries as your cross-compiler.

1. Set up environment variables for the specific version of GCC 9 you installed:
   ```bash
   export CC=/usr/local/opt/gcc@9/bin/aarch64-linux-gnu-gcc-9
   export CXX=/usr/local/opt/gcc@9/bin/aarch64-linux-gnu-g++-9
   ```

2. Verify the installation and the version:
   ```bash
   aarch64-linux-gnu-gcc-9 --version
   ```

This setup should allow you to use `aarch64-linux-gnu-gcc-9` for cross-compilation on macOS. Let me know if you run into any issues!



## Makefile

On macOS, `make` (which is used to execute Makefiles) is typically installed as part of the Xcode Command Line Tools. To install it, follow these steps:

### Method 1: Using Homebrew (If you prefer to use Homebrew)
1. **Open Terminal**.

2. **Install `make`** via Homebrew:
   ```bash
   brew install make
   ```

3. After installation, verify by checking the version:
   ```bash
   make --version
   ```

Either of these methods will install `make` on your Mac, allowing you to use Makefiles. Let me know if you need further help!
