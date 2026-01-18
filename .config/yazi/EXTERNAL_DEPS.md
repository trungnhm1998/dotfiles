# Yazi External Dependencies

This directory contains vendored themes (flavors) and plugins for the Yazi file manager. These are managed by Yazi's built-in package manager and should not be manually edited.

## Package Management

All external dependencies are defined in `package.toml` and installed via:
```bash
ya pack -i  # Install all dependencies
ya pack -u  # Update all dependencies
```

## ⚠️ DO NOT MODIFY

The following directories are **auto-generated** and will be overwritten:
- `flavors/` - Theme files
- `plugins/` - Plugin files

Manual changes to these directories will be lost when packages are updated.

## Installed Flavors (Themes)

| Flavor | Source | Commit | Description |
|--------|--------|--------|-------------|
| catppuccin-frappe | yazi-rs/flavors | fd85060 | Catppuccin Frappe (active theme) |
| catppuccin-macchiato | yazi-rs/flavors | fd85060 | Catppuccin Macchiato |
| kanagawa | dangooddd/kanagawa | d98f0c3 | Kanagawa color scheme |

**Active Theme**: Catppuccin Frappe (set in `theme.toml`)

## Installed Plugins

| Plugin | Source | Commit | Purpose |
|--------|--------|--------|---------|
| git.yazi | yazi-rs/plugins | 4e55902 | Git integration and status display |
| rich-preview.yazi | AnirudhG07/rich-preview | 573b275 | Rich file previews (PDFs, images, archives) |
| nbpreview.yazi | AnirudhG07/nbpreview | b504594 | Jupyter notebook preview support |
| thumbnail.yazi | tasnimAlam/thumbnail | 50d24b8 | Thumbnail generation for images/videos |
| piper.yazi | yazi-rs/plugins | 4e55902 | Pipe content through external commands |

## Managing Dependencies

### Installing a New Plugin

1. Edit `package.toml` and add a new `[[plugin.deps]]` entry:
   ```toml
   [[plugin.deps]]
   use = "owner/repo"
   rev = "commit-hash"
   ```

2. Install:
   ```bash
   ya pack -i
   ```

3. Configure in `yazi.toml` to use the plugin

### Installing a New Flavor

1. Edit `package.toml` and add a new `[[flavor.deps]]` entry:
   ```toml
   [[flavor.deps]]
   use = "owner/repo"
   rev = "commit-hash"
   ```

2. Install:
   ```bash
   ya pack -i
   ```

3. Activate in `theme.toml`:
   ```toml
   [flavor]
   use = "flavor-name"
   ```

### Updating All Dependencies

```bash
ya pack -u  # Updates to latest commits
```

This will modify `package.toml` with new commit hashes.

### Removing a Dependency

1. Remove the entry from `package.toml`
2. Delete the directory from `flavors/` or `plugins/`
3. Remove any references from `yazi.toml` or `theme.toml`

## Why Vendor These?

The plugins and flavors are tracked in this repository to:
1. **Guarantee working configuration** - Locked to specific commits
2. **Offline functionality** - No network required for deployment
3. **Consistency** - Same setup across all machines
4. **Version control** - Track when dependencies change

## Platform-Specific Notes

### Windows
Yazi config is symlinked to:
```
$env:APPDATA\yazi\config → C:\Users\<user>\dotfiles\.config\yazi
```

### macOS/Linux
Yazi config is symlinked to:
```
~/.config/yazi → ~/dotfiles/.config/yazi
```

## Troubleshooting

### Plugins Not Loading
- Verify plugin is listed in `package.toml`
- Check `yazi.toml` for correct plugin configuration
- Run `ya pack -i` to reinstall
- Restart Yazi

### Theme Not Applying
- Check `theme.toml` for correct `[flavor] use` value
- Ensure flavor is installed in `flavors/` directory
- Flavor name must match directory name (without `.yazi` suffix)

### Update Errors
- Delete `flavors/` and `plugins/` directories
- Run `ya pack -i` to fresh install
- Check for conflicting package.toml entries

## Official Documentation

- **Yazi Package Manager**: https://yazi-rs.github.io/docs/plugins/overview
- **Plugin Development**: https://yazi-rs.github.io/docs/plugins/overview
- **Flavor Development**: https://yazi-rs.github.io/docs/flavors/overview

## Safe-to-Edit Files

These files are **safe to modify** (not auto-generated):
- `yazi.toml` - Main configuration
- `theme.toml` - Theme overrides and selection
- `package.toml` - Dependency declarations
- `init.lua` - Custom Lua initialization (if present)

Edit these to customize Yazi behavior without losing changes.
