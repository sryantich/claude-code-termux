# Claude Code on Termux (Android)

This guide covers installing and running Claude Code inside [Termux](https://termux.dev) on Android devices.

## Prerequisites

| Requirement | Details |
|---|---|
| **Android version** | 7.0 (Nougat) or later |
| **Termux** | Latest version from [F-Droid](https://f-droid.org/en/packages/com.termux/) or [GitHub Releases](https://github.com/termux/termux-app/releases). **Do not use the Play Store version** — it is outdated and no longer maintained. |
| **Architecture** | ARM64 (`arm64-v8a`) — most modern phones. ARMv7 (`armeabi-v7a`) is also supported. |
| **Internet** | Required for installation and API access |

## Quick Install

Run the one-line installer inside Termux:

```bash
curl -fsSL https://raw.githubusercontent.com/sryantich/claude-code-termux/main/scripts/install-termux.sh | bash
```

Or clone the repository and run the script:

```bash
pkg install git -y
git clone https://github.com/sryantich/claude-code-termux.git
cd claude-code-termux
bash scripts/install-termux.sh
```

After installation, restart your Termux session (close and reopen, or run `source ~/.bashrc`) and then:

```bash
claude
```

## Manual Installation

If you prefer to set things up step by step:

### 1. Update Termux

```bash
pkg update -y && pkg upgrade -y
```

### 2. Install Node.js and essential tools

```bash
pkg install nodejs-lts git openssl curl build-essential python -y
```

Verify your Node.js version (≥ 18 is required):

```bash
node --version
npm --version
```

### 3. Configure npm for Termux

Set a user-local prefix to avoid permission errors with global installs:

```bash
mkdir -p ~/.npm-global
npm config set prefix '~/.npm-global'
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### 4. Install Claude Code

```bash
npm install -g @anthropic-ai/claude-code
```

### 5. Fix shebangs (if needed)

Termux handles most shebang rewrites automatically via `termux-exec`. If `claude` doesn't start, try:

```bash
termux-fix-shebang ~/.npm-global/bin/claude
```

### 6. Tune memory limits

Mobile devices have limited RAM. Set a memory cap for Node.js:

```bash
echo 'export NODE_OPTIONS="--max-old-space-size=2048"' >> ~/.bashrc
source ~/.bashrc
```

### 7. Verify

```bash
claude --version
```

## Validate Your Setup

Run the included validation script to check for common issues:

```bash
bash scripts/test-termux-setup.sh
```

## Configuration

### API Key

Set your Anthropic API key as an environment variable:

```bash
echo 'export ANTHROPIC_API_KEY="sk-ant-..."' >> ~/.bashrc
source ~/.bashrc
```

Or log in interactively when prompted by `claude`.

### Storage Access

To let Claude Code work with files on your device's internal storage:

```bash
termux-setup-storage
```

This creates a `~/storage` symlink to `/sdcard`. Note that npm packages **must** be installed inside Termux's home directory (`$HOME`), not on shared storage, due to Android filesystem restrictions.

### Recommended `.bashrc` Additions

```bash
# Claude Code Termux environment
export PATH="$HOME/.npm-global/bin:$PATH"
export NODE_OPTIONS="--max-old-space-size=2048"
export EDITOR="nano"  # or vi/vim
```

## Troubleshooting

### `command not found: claude`

The npm global binary directory is not on your PATH. Run:

```bash
source ~/.bashrc
```

If that doesn't help, check your npm prefix:

```bash
npm config get prefix
ls "$(npm config get prefix)/bin/"
```

### Permission errors during `npm install`

Do **not** use `sudo` in Termux. Instead:

1. Ensure npm prefix is set to `~/.npm-global` (see step 3 above).
2. Make sure you're working inside `$HOME`, not shared/external storage.
3. If needed, add `--unsafe-perm=true`:
   ```bash
   npm install -g @anthropic-ai/claude-code --unsafe-perm=true
   ```

### `EPERM: operation not permitted, symlink`

You're likely running in shared storage (`/sdcard`). Move your working directory to Termux's home:

```bash
cd ~
```

### Node.js version too old

Termux can only install one Node.js version at a time. Upgrade:

```bash
pkg uninstall nodejs
pkg install nodejs-lts
```

### Native module build failures

Install the build toolchain:

```bash
pkg install build-essential python -y
```

### Slow performance

- Close unused apps to free RAM.
- Reduce Node.js memory limit if your device has less than 4 GB RAM:
  ```bash
  export NODE_OPTIONS="--max-old-space-size=1024"
  ```
- Consider connecting to a remote machine via SSH and running Claude Code there.

### Shebang errors (`bad interpreter`)

```bash
termux-fix-shebang ~/.npm-global/bin/claude
```

Or ensure `termux-exec` is installed and working:

```bash
pkg install termux-exec -y
```

### `claude doctor`

Claude Code includes a built-in diagnostic command:

```bash
claude doctor
```

## Known Limitations

| Limitation | Details |
|---|---|
| **Performance** | Mobile hardware is slower than desktop. Expect longer startup times and slower operations. |
| **Memory** | Android may kill background processes. Keep Termux in the foreground or acquire a wake lock with `termux-wake-lock`. |
| **Storage** | npm packages must be installed within `$HOME`, not on shared/external storage. |
| **Single Node.js version** | Termux only supports one Node.js version at a time (LTS or current). |
| **No Docker** | Docker does not run on Android. The devcontainer workflow is not available. |
| **Some native modules** | Packages relying on platform-specific native code compiled for `x86_64` Linux will not work. |
| **Screen size** | The terminal experience is optimised for wide terminals. Consider using a Bluetooth keyboard or Termux in Samsung DeX / desktop mode. |

## Updating Claude Code

```bash
npm update -g @anthropic-ai/claude-code
```

## Uninstalling

```bash
npm uninstall -g @anthropic-ai/claude-code
rm -rf ~/.claude
```

To remove the environment tweaks, edit `~/.bashrc` and remove the lines added by the installer.

## Tips for a Better Experience

- **Use a Bluetooth keyboard** for comfortable coding sessions.
- **Use `termux-wake-lock`** to prevent Android from killing your session.
- **Use tmux or screen** for persistent sessions:
  ```bash
  pkg install tmux -y
  tmux new -s claude
  ```
- **Increase font size** in Termux: pinch-to-zoom or go to Settings > Font size.
- **Use SSH** to connect to Termux from your computer for a hybrid workflow:
  ```bash
  pkg install openssh -y
  sshd
  ```
