"""Update the pipeline version manifest for one template.

This script updates the version entry for a single template key in
manifests/versions.yml, commits the change, and optionally creates a git tag.

Examples:
  python .scripts/release.py --template github/demo-hello --version v0.0.1
  python .scripts/release.py --template github/demo-hello --version v0.0.1 --tag
"""

import argparse
import subprocess
from pathlib import Path

import yaml


def run(cmd: list[str]):
    subprocess.run(cmd, check=True)


def tag_exists(tag: str) -> bool:
    return (
        subprocess.run(
            ["git", "rev-parse", "-q", "--verify", f"refs/tags/{tag}"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        ).returncode
        == 0
    )


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--template", required=True)
    p.add_argument("--version", required=True)
    p.add_argument(
        "--tag", action="store_true", help="Create a git tag for this release"
    )
    args = p.parse_args()

    template = args.template
    version = args.version
    tag = f"{template}/{version}"

    if args.tag and tag_exists(tag):
        raise SystemExit(f"Tag already exists: {tag}")

    manifest_path = Path("manifests/versions.yml")
    data = yaml.safe_load(manifest_path.read_text()) or {}

    data[template] = version
    manifest_path.write_text(yaml.safe_dump(data, sort_keys=False))

    run(["git", "add", str(manifest_path)])
    run(["git", "commit", "-m", f"Release {template} {version}"])

    if args.tag:
        run(["git", "tag", "-a", tag, "-m", f"{template} {version}"])


if __name__ == "__main__":
    main()
