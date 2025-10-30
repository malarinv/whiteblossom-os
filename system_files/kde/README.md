# KDE Plasma System Configuration Files

This directory contains KDE Plasma desktop environment configuration files
that will be copied to the system during image build.

## Directory Structure

Configuration files should follow the standard Linux filesystem hierarchy:

```
kde/
├── etc/
│   └── xdg/                    # XDG configuration
│       └── kdeglobals          # KDE global settings
├── usr/
│   └── share/
│       ├── plasma/             # Plasma desktop configs
│       ├── kconf_update/       # KDE configuration updates
│       └── applications/       # Desktop entry files
└── README.md
```

## Configuration Guidelines

- Use system-wide defaults that enhance the gaming and developer experience
- Don't override user preferences unnecessarily
- Follow Bazzite's KDE configuration patterns where applicable
- Keep configurations minimal and focused on WhiteBlossom OS specifics

## Key Configurations

Currently, KDE Plasma packages are installed with default configurations from
the bazzite-nvidia-open variant. Custom configurations can be added here as needed.

### Future Additions

Potential configurations to add:
- Keyboard shortcuts (Ctrl+Alt+T for Ptyxis terminal)
- Default panel layout optimized for gaming/development
- Application menu favorites
- Desktop wallpaper and theme
- KRunner search providers
- Plasma widgets for gaming and development

## Testing

After modifying configurations:
1. Build the image: `just build`
2. Test in VM: `just build-qcow2 && just run-vm-qcow2`
3. Log into KDE Plasma session
4. Verify configurations are applied correctly

