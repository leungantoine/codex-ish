#!/usr/bin/env python3
"""Patch the checked upstream checkout, without replacing its manifests."""
import hashlib
import io
import json
from pathlib import Path
import subprocess
import sys
import tarfile
import tomllib
import urllib.request

kit = Path(__file__).resolve().parents[1]
root = Path(sys.argv[1]).resolve()
pin = json.loads((kit / "codex-upstream.json").read_text())
upstream_commit = pin["upstream_commit"]
upstream_tag = pin["upstream_tag"]
tokio_version = pin["tokio_version"]
assert upstream_tag == f"rust-v{pin['upstream_version']}"
assert subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip() == upstream_commit
subprocess.run(["git", "apply", str(kit / "patches/process-group.patch")], cwd=root, check=True)

lock_path = root / "codex-rs/Cargo.lock"
lock_text = lock_path.read_text()
tokio = next(p for p in tomllib.loads(lock_text)["package"] if p["name"] == "tokio")
assert tokio["version"] == tokio_version
data = urllib.request.urlopen(f"https://static.crates.io/crates/tokio/tokio-{tokio_version}.crate", timeout=60).read()
assert hashlib.sha256(data).hexdigest() == tokio["checksum"]
vendor = root / "codex-rs/vendor"
vendor.mkdir(exist_ok=True)
with tarfile.open(fileobj=io.BytesIO(data)) as archive:
    archive.extractall(vendor, filter="data")
pidfd = vendor / f"tokio-{tokio_version}/src/process/unix/pidfd_reaper.rs"
s = pidfd.read_text()
old = """        } else {
            // Safety: pidfd_open returns -1 on error or a valid fd with ownership."""
new = """        } else {
            // iSH implements pidfd_open but rejects waitid(P_PIDFD). Probe
            // reaping support before selecting this path; WNOWAIT preserves
            // an already exited child for the normal try_wait call.
            let mut info = std::mem::MaybeUninit::<libc::siginfo_t>::zeroed();
            let wait_result = unsafe {
                libc::waitid(
                    libc::P_PIDFD,
                    fd as libc::id_t,
                    info.as_mut_ptr(),
                    libc::WEXITED | libc::WNOHANG | libc::WNOWAIT,
                )
            };
            if wait_result == -1 && io::Error::last_os_error().raw_os_error() == Some(libc::EINVAL) {
                unsafe { libc::close(fd as i32) };
                NO_PIDFD_SUPPORT.store(true, Relaxed);
                return None;
            }
            // Safety: pidfd_open returns -1 on error or a valid fd with ownership."""
assert s.count(old) == 1
pidfd.write_text(s.replace(old, new))

manifest = root / "codex-rs/Cargo.toml"
s = manifest.read_text()
assert s.count("[patch.crates-io]") == 1
s = s.replace("[patch.crates-io]", f'[patch.crates-io]\ntokio = {{ path = "vendor/tokio-{tokio_version}" }}')
s += "\n[profile.release.package.zbus]\ncodegen-units = 1\n\n[profile.release.package.codex-model-provider]\ncodegen-units = 1\n"
manifest.write_text(s)
blocks = lock_text.split("[[package]]")
for i, block in enumerate(blocks):
    if '\nname = "tokio"\n' in block:
        blocks[i] = "\n".join(line for line in block.split("\n") if not line.startswith(("source = ", "checksum = ")))
lock_path.write_text("[[package]]".join(blocks))

catalog = json.loads((root / "codex-rs/models-manager/models.json").read_text())
changed = []
for model in catalog["models"]:
    if model["slug"].startswith(("gpt-6-", "gpt-6.", "gpt-5.6-")):
        assert model["tool_mode"] == "code_mode_only"
        model["tool_mode"] = "direct"
        changed.append(model["slug"])
compat = root / "ish-compat"
compat.mkdir()
(compat / "models-direct.json").write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n")
(compat / "PATCHINFO.json").write_text(json.dumps({
    "upstream_commit": upstream_commit,
    "upstream_tag": upstream_tag,
    "tokio_registry_sha256": tokio["checksum"],
    "direct_tool_models": changed,
    "patched_source_sha256": {
        str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
        for p in (root / "codex-rs/utils/pty/src/process_group.rs", pidfd,
                  manifest, lock_path, compat / "models-direct.json")
    },
}, indent=2) + "\n")
print("Prepared checked source, Tokio, manifests, and direct models:", changed)
