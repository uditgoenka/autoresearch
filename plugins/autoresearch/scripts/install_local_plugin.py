#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import shutil
from pathlib import Path


PLUGIN_ROOT = Path(__file__).resolve().parents[1]


def create_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Install the Autoresearch Codex plugin into a local Codex plugin directory.")
    parser.add_argument("--destination-root", default="~/plugins", help="Directory that should contain the plugin folder.")
    parser.add_argument("--marketplace", default="~/.agents/plugins/marketplace.json", help="Marketplace manifest to create or update.")
    parser.add_argument("--codex-home", default=os.environ.get("CODEX_HOME", "~/.codex"), help="Codex config directory for the installed skill.")
    parser.add_argument("--force", action="store_true", help="Replace an existing plugin directory.")
    return parser


def load_marketplace(path: Path) -> dict:
    if path.exists():
        return json.loads(path.read_text(encoding="utf-8"))
    return {
        "name": "local-plugins",
        "interface": {
            "displayName": "Local Plugins"
        },
        "plugins": []
    }


def install_skill(codex_home: Path, force: bool) -> Path:
    destination = codex_home / "skills" / "autoresearch"
    if destination.exists():
        if not force:
            raise SystemExit(f"Destination already exists: {destination}. Re-run with --force to replace it.")
        shutil.rmtree(destination)

    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(
        PLUGIN_ROOT / "skills" / "autoresearch",
        destination,
        ignore=shutil.ignore_patterns("__pycache__", "*.pyc")
    )
    shutil.copytree(PLUGIN_ROOT / "resources", destination / "resources", dirs_exist_ok=True)
    shutil.copytree(
        PLUGIN_ROOT / "scripts",
        destination / "scripts",
        ignore=shutil.ignore_patterns("__pycache__", "*.pyc"),
        dirs_exist_ok=True
    )
    return destination


def install_plugin(destination_root: Path, marketplace_path: Path, codex_home: Path, force: bool) -> None:
    destination_root.mkdir(parents=True, exist_ok=True)
    destination = destination_root / "autoresearch"

    if destination.exists():
        if not force:
            raise SystemExit(f"Destination already exists: {destination}. Re-run with --force to replace it.")
        shutil.rmtree(destination)

    shutil.copytree(
        PLUGIN_ROOT,
        destination,
        ignore=shutil.ignore_patterns("__pycache__", "*.pyc")
    )

    marketplace_path.parent.mkdir(parents=True, exist_ok=True)
    marketplace = load_marketplace(marketplace_path)
    entry = {
        "name": "autoresearch",
        "source": {
            "source": "local",
            "path": "./plugins/autoresearch"
        },
        "policy": {
            "installation": "AVAILABLE",
            "authentication": "ON_INSTALL"
        },
        "category": "Productivity"
    }

    plugins = marketplace.setdefault("plugins", [])
    for index, plugin in enumerate(plugins):
        if plugin.get("name") == "autoresearch":
            plugins[index] = entry
            break
    else:
        plugins.append(entry)

    marketplace_path.write_text(json.dumps(marketplace, indent=2) + "\n", encoding="utf-8")
    skill_destination = install_skill(codex_home, force)

    print(f"Installed plugin to {destination}")
    print(f"Installed Codex skill to {skill_destination}")
    print(f"Updated marketplace manifest at {marketplace_path}")
    print("Restart Codex to pick up the new plugin.")


def main() -> int:
    parser = create_parser()
    args = parser.parse_args()
    destination_root = Path(args.destination_root).expanduser().resolve()
    marketplace_path = Path(args.marketplace).expanduser().resolve()
    codex_home = Path(args.codex_home).expanduser().resolve()
    install_plugin(destination_root, marketplace_path, codex_home, args.force)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
