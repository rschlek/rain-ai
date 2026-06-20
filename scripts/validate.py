#!/usr/bin/env python3
"""Validate the marketplace catalog, every plugin manifest, and skill frontmatter."""

import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
MARKETPLACE_JSON = REPO_ROOT / ".claude-plugin" / "marketplace.json"
PLUGINS_DIR = REPO_ROOT / "plugins"

errors: list[str] = []


def validate_json(path: Path) -> bool:
    if not path.is_file():
        errors.append(f"Missing manifest: {path}")
        return False
    try:
        with open(path, "r", encoding="utf-8") as f:
            json.load(f)
        print(f"  OK  {path.relative_to(REPO_ROOT)}")
        return True
    except json.JSONDecodeError as e:
        errors.append(f"Invalid JSON in {path}: {e}")
        return False


def validate_skill(skill_dir: Path) -> None:
    skill_md = skill_dir / "SKILL.md"
    if not skill_md.is_file():
        errors.append(f"Skill directory {skill_dir.name} is missing SKILL.md")
        return

    with open(skill_md, "r", encoding="utf-8") as f:
        content = f.read()

    # Check for YAML frontmatter delimiters
    if not content.startswith("---"):
        errors.append(f"{skill_md.relative_to(REPO_ROOT)}: missing YAML frontmatter (no opening ---)")
        return

    parts = content.split("---", 2)
    if len(parts) < 3:
        errors.append(f"{skill_md.relative_to(REPO_ROOT)}: malformed YAML frontmatter (no closing ---)")
        return

    frontmatter = parts[1]
    has_name = any(line.strip().startswith("name:") for line in frontmatter.splitlines())
    has_desc = any(line.strip().startswith("description:") for line in frontmatter.splitlines())

    if not has_name:
        errors.append(f"{skill_md.relative_to(REPO_ROOT)}: frontmatter missing 'name:' key")
    if not has_desc:
        errors.append(f"{skill_md.relative_to(REPO_ROOT)}: frontmatter missing 'description:' key")

    if has_name and has_desc:
        print(f"  OK  {skill_md.relative_to(REPO_ROOT)}")


def discover_plugins() -> list[Path]:
    """Every plugins/<name>/ directory that carries a plugin manifest."""
    if not PLUGINS_DIR.is_dir():
        return []
    return sorted(
        d for d in PLUGINS_DIR.iterdir()
        if d.is_dir() and (d / ".claude-plugin" / "plugin.json").is_file()
    )


def validate_plugin(plugin_dir: Path) -> None:
    print(f"Validating plugin: {plugin_dir.name}")
    validate_json(plugin_dir / ".claude-plugin" / "plugin.json")
    skills_dir = plugin_dir / "skills"
    skill_dirs = [d for d in skills_dir.iterdir() if d.is_dir()] if skills_dir.is_dir() else []
    if not skill_dirs:
        print("  (no skills found — nothing to validate)")
    for skill_dir in sorted(skill_dirs):
        validate_skill(skill_dir)


def check_catalog_versions() -> None:
    """A plugin's version belongs in its own plugin.json, never in the
    marketplace catalog. Flag any 'version' key found inside a marketplace
    plugin entry so the single-source-of-truth rule stays self-enforcing.
    Also confirm every catalogued plugin's source directory exists."""
    if not MARKETPLACE_JSON.is_file():
        return
    try:
        with open(MARKETPLACE_JSON, "r", encoding="utf-8") as f:
            data = json.load(f)
    except json.JSONDecodeError:
        return  # validate_json already reported the parse failure
    for entry in data.get("plugins", []):
        if not isinstance(entry, dict):
            continue
        name = entry.get("name", "<unnamed>")
        if "version" in entry:
            errors.append(
                f"marketplace.json: plugin entry '{name}' has a 'version' key; "
                f"remove it (the version belongs in that plugin's plugin.json)"
            )
        source = entry.get("source")
        if source:
            source_path = (REPO_ROOT / source).resolve()
            if not (source_path / ".claude-plugin" / "plugin.json").is_file():
                errors.append(
                    f"marketplace.json: plugin '{name}' source '{source}' has no "
                    f".claude-plugin/plugin.json"
                )


def main() -> None:
    print("Validating marketplace catalog...")
    validate_json(MARKETPLACE_JSON)
    check_catalog_versions()

    print()
    plugins = discover_plugins()
    if not plugins:
        print("No plugins found under plugins/.")
    for plugin_dir in plugins:
        validate_plugin(plugin_dir)

    if errors:
        print()
        print("ERRORS:")
        for err in errors:
            print(f"  X {err}")
        sys.exit(1)
    else:
        print()
        print("All checks passed.")


if __name__ == "__main__":
    main()
