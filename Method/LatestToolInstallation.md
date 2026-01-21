# Latest Tool Installation Method

Documentation for installing Lazygit and Neovim via GitHub releases in `deploy.sh`.

## Method Summary

**Lazygit**: Direct binary download from GitHub releases  
**Neovim**: Pre-built tarball from GitHub releases

---

## Pros

### For Both Tools

1. **Always Latest Version**
   - Lazygit: v0.58.1+ (Ubuntu repos don't have it at all)
   - Neovim: v0.11.5+ (vs Ubuntu's outdated 0.9.5)

2. **Official Source**
   - Downloaded directly from official GitHub releases
   - No third-party PPA maintenance concerns
   - Trusted binaries built by maintainers

3. **Cross-Platform Consistency**
   - Same method works across all Ubuntu/Debian versions
   - Not tied to specific Ubuntu release schedules

4. **No Dependency Hell**
   - Pre-compiled binaries with dependencies bundled
   - No conflicts with system packages

5. **Clean Installation**
   - Standard locations: `/usr/local/bin/`, `/opt/`
   - Easy to identify and remove

6. **Idempotent**
   - Safe to run multiple times
   - Overwrites cleanly without accumulation

---

## Cons

### For Both Tools

1. **No Automatic Updates**
   - Must re-run script to upgrade
   - Unlike `apt upgrade` which updates everything
   - No notification of new versions

2. **Manual Dependency on curl/tar**
   - Assumes these tools exist (though virtually always do)
   - Network required at install time

3. **x86_64 Only**
   - Won't work on ARM64 systems (Raspberry Pi, etc.)
   - Would need architecture detection for broader support

4. **Larger Script Complexity**
   - ~50 lines of custom code vs 1-line apt install
   - More potential failure points to handle

5. **No Package Manager Integration**
   - Won't show up in `apt list --installed`
   - Can't use `apt remove` to uninstall
   - Package managers won't track files

### Neovim-Specific

6. **Non-Standard Installation Path**
   - Located in `/opt/` rather than `/usr/bin/`
   - Symlink required for PATH integration
   - Could confuse some package auditing tools

7. **Takes More Disk Space**
   - Tarball extracts full tree vs optimized package
   - ~50MB in `/opt/` vs apt's shared libraries

---

## Alternative Methods Considered

### 1. Use apt (Ubuntu repos)

**Lazygit**: Not available  
**Neovim**: Only v0.9.5 (18 months outdated)

### 2. Use PPA (Personal Package Archive)

**Pros**:
- `apt upgrade` works
- Package manager integration

**Cons**:
- Lazygit: No official PPA
- Neovim stable PPA: Outdated (v0.7.2)
- Neovim unstable PPA: Bleeding edge (v0.12.0 nightly) - risky
- Third-party PPAs = security/trust concerns
- PPA maintainer could abandon project

### 3. AppImage (Neovim only)

**Pros**:
- Self-contained single file
- No root needed
- Portable

**Cons**:
- Requires FUSE (may not be available)
- Less "traditional" installation feel
- Takes more space per app
- Can be slower to start

### 4. Build from Source

**Pros**:
- Ultimate control
- Can customize build flags
- Always latest commit if desired

**Cons**:
- Requires build toolchain (gcc, make, go, cmake, etc.)
- Takes 5-15 minutes to compile
- Complex error handling
- Build dependencies can conflict
- Overkill for most users

### 5. Snap/Flatpak

**Pros**:
- Automatic updates
- Sandboxed

**Cons**:
- Lazygit: No official snap
- Neovim snap: Permission issues with dotfiles
- Slower startup
- Plugin ecosystem issues
- Not universally liked in community

---

## Method Comparison

| Criteria | GitHub Releases | apt | PPA | AppImage | Build |
|----------|-----------------|-----|-----|----------|-------|
| Latest version | Yes | No | Partial | Yes | Yes |
| Official source | Yes | Yes | No | Yes | Yes |
| Complexity | Medium | Low | Low | Low | High |
| Dependencies | None | None | None | FUSE | Many |
| Auto-updates | No | Yes | Yes | Partial | No |
| Trust/Security | High | High | Medium | High | High |

**Winner**: GitHub releases - balances latest version with reliability

---

## Future Improvements

To address the "no auto-updates" con:

1. **Add update script**
   ```bash
   # ~/dotfiles/update_tools.sh
   bash ~/dotfiles/deploy.sh  # Re-run relevant sections
   ```

2. **Add version checker**
   ```bash
   # Compare installed vs latest, prompt if outdated
   ```

3. **Use cron/systemd timer**
   ```bash
   # Weekly check for updates
   ```

4. **Add architecture detection**
   ```bash
   # Support ARM64 in addition to x86_64
   ARCH=$(uname -m)
   case $ARCH in
       x86_64) ARCH_SUFFIX="x86_64" ;;
       aarch64) ARCH_SUFFIX="arm64" ;;
   esac
   ```

---

## Installation Details

### Lazygit

- **Source**: `https://github.com/jesseduffield/lazygit/releases/latest`
- **Install location**: `/usr/local/bin/lazygit`
- **Config**: `~/.config/lazygit/config.yml` (Catppuccin Frappe theme)

### Neovim

- **Source**: `https://github.com/neovim/neovim/releases/latest`
- **Install location**: `/opt/nvim-linux-x86_64/`
- **Symlink**: `/usr/local/bin/nvim` -> `/opt/nvim-linux-x86_64/bin/nvim`

---

## Platform Behavior in deploy.sh

| Platform | Lazygit | Neovim |
|----------|---------|--------|
| Ubuntu/apt | Custom installer (latest) | Custom installer (latest) |
| macOS/brew | `brew install lazygit` | `brew install neovim` |
| Arch/pacman | `pacman -S lazygit` | `pacman -S neovim` |
