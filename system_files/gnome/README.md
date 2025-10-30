# GNOME Desktop Configuration Files

This directory contains GNOME-specific configuration files that will be
copied to the system during image build.

## Purpose

GNOME is already provided by the bazzite-gnome-nvidia-open base image with
Bazzite's gaming optimizations. This directory is for WhiteBlossom OS specific
GNOME customizations.

## Directory Structure

```
gnome/
├── etc/
│   └── dconf/                  # GNOME dconf overrides
│       └── db/
│           └── local.d/        # System defaults
├── usr/
│   └── share/
│       ├── glib-2.0/           # GSettings schemas
│       │   └── schemas/
│       └── gnome-shell/        # GNOME Shell configs
│           └── extensions/     # System extensions
└── README.md
```

## Current State

The base image provides a complete GNOME desktop with Bazzite gaming
optimizations. Additional customizations can be added here as needed.

## Potential Customizations

- Privacy-focused GNOME extensions
- Custom keyboard shortcuts
- Default application associations
- Theme and appearance overrides
- Privacy panel presets

