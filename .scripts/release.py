import argparse
import subprocess
from pathlib import Path
import yaml


def run(cmd):
    try:
        subprocess.run(cmd, check=True)
    except Exception as exc:
        raise exc


def main():
    p = argparse.ArgumentParser()

    p.add_argument("--template", required=True)
    p.add_argument("--version", required=True)

    args = p.parse_args()

    manifest_path = Path("manifests/versions.yml")
    data = yaml.safe_load(manifest_path.read_text()) or {}

    data[args.template] = args.version
    manifest_path.write_text(yaml.safe_dump(data, sort_keys=False))

    run(["git", "add", str(manifest_path)])
    run(["git", "commit", "-m", f"Release {args.template} {args.version}"])
    run(
        [
            "git",
            "tag",
            "-a",
            f"{args.template}/{args.version}",
            "-m",
            f"{args.template} {args.version}",
        ]
    )


if __name__ == "__main__":
    main()
