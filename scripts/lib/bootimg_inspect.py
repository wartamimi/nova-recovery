#!/usr/bin/env python3
"""NOVA Recovery - read-only Android boot/recovery image inspector.

Parses boot image headers v0-v2 (citrus uses v2), checks the kernel is an
arm64 Image, lists the ramdisk and checks expected TWRP/NOVA files.
Prints a JSON report and exits non-zero on any failed check.

Usage: bootimg_inspect.py IMAGE [--max-size BYTES] [--expect-header N]
                                [--require PATH ...] [--json OUT]
"""
import argparse, gzip, hashlib, io, json, lzma, shutil, struct, subprocess, sys

BOOT_MAGIC = b"ANDROID!"


def page_align(n, page):
    return (n + page - 1) // page * page


def parse_header(d):
    if d[:8] != BOOT_MAGIC:
        raise ValueError("not an Android boot image (missing ANDROID! magic)")
    (kernel_size, kernel_addr, ramdisk_size, ramdisk_addr, second_size,
     second_addr, tags_addr, page_size, header_version, os_version) = struct.unpack_from("<10I", d, 8)
    if header_version > 2:
        raise ValueError(f"header v{header_version} not handled (citrus is v2)")
    name = d[48:64].split(b"\0")[0].decode(errors="replace")
    cmdline = d[64:576].split(b"\0")[0].decode(errors="replace")
    extra = d[608:1632].split(b"\0")[0].decode(errors="replace")
    h = dict(header_version=header_version, page_size=page_size,
             kernel_size=kernel_size, kernel_addr=hex(kernel_addr),
             ramdisk_size=ramdisk_size, ramdisk_addr=hex(ramdisk_addr),
             second_size=second_size, second_addr=hex(second_addr),
             tags_addr=hex(tags_addr), name=name, cmdline=(cmdline + extra))
    if header_version >= 1:
        dtbo_size, dtbo_off, header_size = struct.unpack_from("<IQI", d, 1632)
        h.update(recovery_dtbo_size=dtbo_size, recovery_dtbo_offset=dtbo_off, header_size=header_size)
    if header_version >= 2:
        dtb_size, dtb_addr = struct.unpack_from("<IQ", d, 1648)
        h.update(dtb_size=dtb_size, dtb_addr=hex(dtb_addr))
    return h


def sections(d, h):
    p = h["page_size"]
    off = p
    out = {}
    for key in ("kernel", "ramdisk", "second"):
        size = h[f"{key}_size"]
        out[key] = d[off:off + size]
        off += page_align(size, p)
    if h["header_version"] >= 1:
        size = h["recovery_dtbo_size"]
        out["recovery_dtbo"] = d[off:off + size]
        off += page_align(size, p)
    if h["header_version"] >= 2:
        size = h["dtb_size"]
        out["dtb"] = d[off:off + size]
        off += page_align(size, p)
    out["_end"] = off
    return out


def decompress(blob):
    if blob[:2] == b"\x1f\x8b":
        return "gzip", gzip.decompress(blob)
    if blob[:6] == b"\xfd7zXZ\x00":
        return "xz", lzma.decompress(blob)
    if blob[:4] in (b"\x02\x21\x4c\x18", b"\x04\x22\x4d\x18"):
        lz4 = shutil.which("lz4")
        if not lz4:
            return "lz4 (lz4 tool missing)", None
        r = subprocess.run([lz4, "-dc"], input=blob, capture_output=True, check=False)
        return "lz4", r.stdout if r.returncode == 0 else None
    return "raw", blob


def cpio_names(data):
    names, off = [], 0
    while off + 110 <= len(data):
        magic = data[off:off + 6]
        if magic not in (b"070701", b"070702"):
            break
        namesize = int(data[off + 94:off + 102], 16)
        filesize = int(data[off + 54:off + 62], 16)
        name = data[off + 110:off + 110 + namesize - 1].decode(errors="replace")
        if name == "TRAILER!!!":
            break
        names.append(name)
        off = (off + 110 + namesize + 3) & ~3
        off = (off + filesize + 3) & ~3
    return names


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("image")
    ap.add_argument("--max-size", type=int, default=0)
    ap.add_argument("--expect-header", type=int, default=None)
    ap.add_argument("--require", nargs="*", default=[])
    ap.add_argument("--json")
    a = ap.parse_args()

    d = open(a.image, "rb").read()
    rep = {"image": a.image, "size": len(d), "sha256": hashlib.sha256(d).hexdigest(), "checks": []}

    def check(name, cond, detail=""):
        rep["checks"].append({"check": name, "pass": bool(cond), "detail": detail})

    try:
        h = parse_header(d)
    except ValueError as e:
        check("boot image magic/header", False, str(e))
        h = None
    if h:
        rep["header"] = h
        check("boot image magic", True)
        if a.expect_header is not None:
            check("header version", h["header_version"] == a.expect_header,
                  f"found v{h['header_version']}, expected v{a.expect_header}")
        check("page size 4096", h["page_size"] == 4096, str(h["page_size"]))
        s = sections(d, h)
        check("sections within file", s["_end"] <= len(d), f"end={s['_end']} file={len(d)}")
        if a.max_size:
            check("fits partition", len(d) <= a.max_size, f"{len(d)} <= {a.max_size}")

        kfmt, kraw = decompress(s["kernel"])
        rep["kernel_format"] = kfmt
        is_arm64 = bool(kraw) and len(kraw) > 60 and kraw[56:60] == b"ARM\x64"
        check("kernel is arm64 Image", is_arm64, kfmt)
        if kraw:
            idx = kraw.find(b"Linux version ")
            if idx >= 0:
                rep["kernel_version"] = kraw[idx:kraw.find(b"\n", idx)].decode(errors="replace")
        if h["header_version"] >= 2:
            check("dtb present", h["dtb_size"] > 0 and s["dtb"][:4] == b"\xd0\x0d\xfe\xed",
                  f"dtb_size={h['dtb_size']}")

        rfmt, rraw = decompress(s["ramdisk"])
        rep["ramdisk_format"] = rfmt
        names = cpio_names(rraw) if rraw else []
        rep["ramdisk_entries"] = len(names)
        check("ramdisk is readable cpio", len(names) > 0, rfmt)
        nameset = set(n.lstrip("./") for n in names)
        for req in a.require:
            check(f"ramdisk contains {req}", req.lstrip("/") in nameset)

    rep["ok"] = all(c["pass"] for c in rep["checks"])
    out = json.dumps(rep, indent=2)
    if a.json:
        open(a.json, "w").write(out + "\n")
    print(out)
    sys.exit(0 if rep["ok"] else 1)


if __name__ == "__main__":
    main()
