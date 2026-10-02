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
libc_version = pin["libc_version"]
assert upstream_tag == f"rust-v{pin['upstream_version']}"
assert subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip() == upstream_commit
subprocess.run(["git", "apply", str(kit / "patches/process-group.patch")], cwd=root, check=True)

lock_path = root / "codex-rs/Cargo.lock"
lock_text = lock_path.read_text()
packages = tomllib.loads(lock_text)["package"]
tokio = next(p for p in packages if p["name"] == "tokio")
libc = next(p for p in packages if p["name"] == "libc")
assert tokio["version"] == tokio_version
assert libc["version"] == libc_version
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
cargo_manifest = tomllib.loads(s)
assert s.count("[patch.crates-io]") == 1
tokio_path = f"vendor/tokio-{tokio_version}"
crates_io_patches = cargo_manifest.get("patch", {}).get("crates-io", {})
tokio_override = crates_io_patches.get("tokio")
if tokio_override is None:
    s = s.replace("[patch.crates-io]", f'[patch.crates-io]\ntokio = {{ path = "{tokio_path}" }}')
elif not isinstance(tokio_override, dict) or tokio_override.get("path") != tokio_path:
    raise RuntimeError("Upstream already patches Tokio; review and reconcile that patch instead of adding a duplicate.")
release_packages = cargo_manifest.get("profile", {}).get("release", {}).get("package", {})
profile_additions = []
for package_name in ("zbus", "codex-model-provider"):
    settings = release_packages.get(package_name, {})
    codegen_units = settings.get("codegen-units")
    if codegen_units == 1:
        continue
    if codegen_units is not None or package_name in release_packages:
        raise RuntimeError(
            f"Upstream already configures release profile for {package_name}; "
            "review and merge its settings instead of appending a duplicate table."
        )
    profile_additions.append(
        f"[profile.release.package.{package_name}]\ncodegen-units = 1"
    )
if profile_additions:
    s += "\n" + "\n\n".join(profile_additions) + "\n"
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
        assert model["tool_mode"] in ("code_mode_only", "direct")
        model["tool_mode"] = "direct"
        changed.append(model["slug"])
assert changed, "No supported GPT-6 or GPT-5.6 models found in upstream catalog"
compat = root / "ish-compat"
compat.mkdir(exist_ok=True)
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
