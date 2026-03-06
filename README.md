````markdown
# 🧙 Nixorcist

**Nixorcist** is a modular package orchestration system for **NixOS** that manages packages through generated modules instead of manually editing `environment.systemPackages`.

It introduces a **lock-driven workflow**, where the desired package list becomes the source of truth and everything else is generated automatically.

The project is designed to:

- Reduce manual editing of `configuration.nix`
- Keep packages modular
- Allow safe and reproducible rebuilds
- Provide an interactive way to search and add packages
- Automatically resolve some rebuild warnings
- Separate *package intent* from *system configuration structure*

---

# Philosophy

Traditional NixOS setups usually look like this:

```nix
environment.systemPackages = with pkgs; [
  firefox
  git
  neovim
  ripgrep
];
````

This works, but as systems grow it becomes harder to manage:

* large monolithic lists
* duplicate declarations
* hard to split packages logically
* harder to automate

**Nixorcist** changes the workflow:

```
user selection
      ↓
lock file
      ↓
module generator
      ↓
generated modules
      ↓
hub module
      ↓
system rebuild
```

Instead of editing Nix files manually, you manage packages through **lock entries** and the system generates the Nix modules automatically.

---

# Core Components

The system consists of two main parts:

1. **Nixorcist package orchestration**
2. **Smart rebuild script**

---

# Repository Structure

Example configuration layout:

```
.
├── assets
│   └── login.png
├── bluetooth.nix
├── configuration.nix
├── external
│   ├── ags
│   ├── catppuccin
│   ├── home-manager
│   ├── nixvim
│   └── quickshell
├── modules
│   ├── all-packages.nix
│   ├── audio.nix
│   ├── bootloader.nix
│   ├── environment.nix
│   ├── grub-theme.nix
│   ├── kernel-params.nix
│   ├── kernel-params-nvidia.nix
│   ├── locale.nix
│   ├── networking.nix
│   ├── nixvim.nix
│   ├── quickshell.nix
│   ├── sddm.nix
│   ├── users.nix
│   ├── window-managers.nix
│   └── zsh.nix
│
├── nixorcist
│   ├── generated
│   │   ├── all-packages.nix
│   │   └── default.nix
│   │
│   ├── lib
│   │   ├── dirs.sh
│   │   ├── generate-packages.sh
│   │   ├── gen.sh
│   │   ├── hub.sh
│   │   ├── index.sh
│   │   ├── lock.sh
│   │   ├── rebuild.sh
│   │   └── utils.sh
│   │
│   ├── lock
│   ├── modules
│   └── nixorcist.sh
│
├── packages
│   ├── all-packages.nix
│   ├── communication.nix
│   ├── core.nix
│   ├── development.nix
│   ├── eclipse.nix
│   ├── games.nix
│   ├── hyprland.nix
│   ├── kde.nix
│   ├── pkg-dump.nix
│   ├── simplex-chat.nix
│   ├── waybar-weather.nix
│   ├── window-managers.nix
│   └── zsh.nix
│
└── scripts
    └── nix-rebuild-smart.sh
```

Important directories:

| Directory    | Purpose                                 |
| ------------ | --------------------------------------- |
| `modules/`   | Core system modules                     |
| `packages/`  | Custom curated package groups           |
| `nixorcist/` | Package generation engine               |
| `scripts/`   | Utility scripts including smart rebuild |

---

# Nixorcist Architecture

The system is built from several layers.

---

# 1. Lock File

The lock file stores the **desired packages**.

Example:

```
firefox
git
ripgrep
neovim
```

The lock file is treated as the **source of truth**.

Everything else is generated from it.

---

# 2. Module Generation

For every entry in the lock file, Nixorcist generates a module:

Example generated module:

```nix
{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    firefox
  ];
}
```

Each package becomes its **own Nix module**.

Advantages:

* no giant lists
* easy diffing
* clean imports
* modular structure

---

# 3. Hub Module

Generated modules are imported into a **hub module**.

Example:

```nix
{
  imports = [
    ./modules/firefox.nix
    ./modules/git.nix
    ./modules/neovim.nix
  ];
}
```

The hub acts as a **single entry point** for the generated modules.

Your main configuration can then simply import:

```nix
imports = [
  ./nixorcist/generated/all-packages.nix
];
```

---

# ⚠️ Important Hub Warning

If you already have a hub file that contains **declared functions or complex logic**, **do NOT reuse it as the Nixorcist hub**.

Example of problematic hub:

```nix
{ config, pkgs, ... }:

let
  myCustomFunction = ...
in
{
  imports = [ ... ];
}
```

Why this matters:

Nixorcist regenerates the hub automatically.

During regeneration it only reconstructs **imports**, so:

* functions may be removed
* declarations may be misplaced
* the file may be overwritten

This can break evaluation or produce incorrect module structure.

### Recommendation

Keep the **Nixorcist hub completely isolated**:

```
nixorcist/generated/all-packages.nix
```

And import it from another module instead.

Example:

```nix
imports = [
  ./modules/all-packages.nix
  ./nixorcist/generated/all-packages.nix
];
```

This prevents accidental overwrites.

---

# CLI Usage

Main command:

```
nixorcist <command>
```

---

# Commands

## Select packages

```
nixorcist select
```

Interactive selector powered by **fzf**.

Features:

* fuzzy search
* namespace detection
* multiple selection
* add or remove packages
* automatic lock update

---

## Generate modules

```
nixorcist gen
```

Reads the lock file and creates package modules.

---

## Regenerate hub

```
nixorcist hub
```

Updates the hub file that imports all generated modules.

---

## Run rebuild

```
nixorcist rebuild
```

Executes the **smart rebuild pipeline**.

---

## Run full pipeline

```
nixorcist all
```

Equivalent to:

```
select
gen
hub
rebuild
```

---

## Import packages from file

```
nixorcist import packages.txt
```

Supported separators:

```
firefox git neovim
```

```
firefox,git,neovim
```

```
firefox
git
neovim
```

---

## Purge generated modules

```
nixorcist purge
```

Deletes:

* generated modules
* lock entries

---

# Smart Rebuild Script

Located in:

```
scripts/nix-rebuild-smart.sh
```

This script extends the standard:

```
nixos-rebuild switch
```

---

# Purpose

It automatically detects and fixes **evaluation warnings caused by renamed options**.

Example warning:

```
evaluation warning:
'services.xserver.desktopManager.plasma5'
was moved.
Please use 'services.desktopManager.plasma6'
```

---

# Smart Rebuild Workflow

The script performs several steps:

### 1. Run rebuild

```
nixos-rebuild switch --upgrade
```

The output is captured.

---

### 2. Parse warnings

The script scans rebuild output for:

```
evaluation warning:
```

---

### 3. Extract rename information

Example extraction:

```
OLD: services.xserver.desktopManager.plasma5
NEW: services.desktopManager.plasma6
```

---

### 4. Locate occurrences

Searches inside:

```
/etc/nixos
```

Example result:

```
configuration.nix:42: services.xserver.desktopManager.plasma5.enable = true
```

---

### 5. Replacement options

The script provides interactive options:

```
[Y] Replace ALL
[n] Skip
[c] Controlled
```

---

## Replace ALL

Automatically updates every occurrence across the configuration.

---

## Controlled mode

Shows each occurrence individually:

```
File : configuration.nix
Line : 42
Code : services.xserver.desktopManager.plasma5.enable = true
```

Then asks:

```
Replace this occurrence? [y/N]
```

---

## Skip

Ignore the warning.

---

# Safety Features

The rebuild system includes several safeguards:

### Staging configuration

Before rebuild:

```
/etc/nixos/.staging
```

is created and populated.

---

### Build validation

The configuration is built before switching.

If build fails:

```
system configuration is not activated
```

---

### Safe activation

Only successful builds are switched into the running system.

---

# Dependencies

Required:

```
nix
nixos-rebuild
fzf
grep
sed
awk
```

Recommended:

```
git
ripgrep
```

---

# Example Workflow

Typical usage:

### 1. Select packages

```
nixorcist select
```

---

### 2. Generate modules

```
nixorcist gen
```

---

### 3. Regenerate hub

```
nixorcist hub
```

---

### 4. Rebuild system

```
nixorcist rebuild
```

---

### Or simply

```
nixorcist all
```

---

# Design Goals

Nixorcist was built with several design goals:

* **modularity**
* **automation**
* **safety**
* **clean configuration**
* **reproducibility**

It separates the concerns of:

| Layer            | Responsibility       |
| ---------------- | -------------------- |
| Lock file        | desired packages     |
| Module generator | produce Nix modules  |
| Hub              | collect imports      |
| Rebuild          | deploy configuration |

---

# Future Ideas

Possible improvements:

* flake support
* profile-based package groups
* automatic orphan module cleanup
* package dependency graph
* package usage statistics
* home-manager integration
* remote lock import

---

# License

MIT

