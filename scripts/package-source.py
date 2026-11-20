"""Package and verify an exact source commit for the first toolkit release."""
from argparse import ArgumentParser
from hashlib import sha256
from io import BytesIO
from pathlib import Path
import re
import subprocess
from zipfile import ZipFile


VERSION = "v0.1.0"
ROOT = Path(__file__).resolve().parents[1]


def git(*arguments):
    return subprocess.check_output(
        ["git", "-c", f"safe.directory={ROOT.as_posix()}", *arguments], cwd=ROOT
    )


def save(path, content):
    if path.exists():
        if path.read_bytes() != content:
            raise ValueError(f"Existing candidate artifact differs: {path}")
        return
    path.write_bytes(content)


def package(commit):
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ValueError("Supply a full lowercase Git commit SHA")
    if git("rev-parse", f"{commit}^{{commit}}").decode().strip() != commit:
        raise ValueError("The supplied SHA must identify the source commit itself")

    prefix = f"reusable-ci-workflow-toolkit-{VERSION}/"
    entries = {}
    for record in git("ls-tree", "-rz", commit).split(b"\0"):
        if not record:
            continue
        metadata, path = record.split(b"\t", 1)
        mode, kind, _ = metadata.split()
        if kind != b"blob" or mode not in (b"100644", b"100755"):
            raise ValueError("The release expects regular source files")
        name = path.decode("utf-8")
        entries[prefix + name] = name

    required = {"LICENSE", "THIRD_PARTY_NOTICES.md", "README.md", "docs/RELEASE_EVIDENCE.md",
                ".github/workflows/reusable-go.yml", ".github/workflows/reusable-java.yml",
                ".github/workflows/reusable-verify.yml", "fixtures/go-caller/go.mod",
                "fixtures/java-caller/pom.xml"}
    if not required <= set(entries.values()):
        raise ValueError("Missing required release content")

    # Prevent Windows Git settings from exporting CRLF in place of recorded bytes.
    artifact = git("-c", "core.autocrlf=false", "-c", "core.eol=lf",
                   "archive", "--format=zip", f"--prefix={prefix}", commit)
    with ZipFile(BytesIO(artifact)) as archive:
        if archive.comment != commit.encode("ascii"):
            raise ValueError("Source commit missing from ZIP metadata")
        names = [item.filename for item in archive.infolist() if not item.is_dir()]
        if archive.testzip() or set(names) != set(entries) or len(names) != len(entries):
            raise ValueError("Archive inventory or CRC mismatch")
        for filename, path in entries.items():
            if archive.read(filename) != git("show", f"{commit}:{path}"):
                raise ValueError(f"Archive bytes differ from Git for {path}")

    destination = ROOT / "bin" / "release" / VERSION / commit
    destination.mkdir(parents=True, exist_ok=True)
    name = f"{prefix.rstrip('/')}-source.zip"
    digest = sha256(artifact).hexdigest()
    save(destination / name, artifact)
    save(destination / "SHA256SUMS.txt", f"{digest}  {name}\n".encode("ascii"))
    print(f"Source commit {commit}")
    print(f"Verified {len(entries)} file contents and archive CRC")
    print(f"SHA-256 {digest}")
    print(destination / name)


if __name__ == "__main__":
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("commit", help="full reviewed source commit SHA")
    package(parser.parse_args().commit)
