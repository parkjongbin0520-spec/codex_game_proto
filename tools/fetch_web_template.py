"""Fetch only Godot's web template from the official archive using HTTPS ranges.

zipfile verifies the selected member's CRC. No TLS or checksum checks are disabled.
"""
import io
import pathlib
import urllib.request
import zipfile

VERSION = "4.6.3"
URL = f"https://github.com/godotengine/godot/releases/download/{VERSION}-stable/Godot_v{VERSION}-stable_export_templates.tpz"


class RemoteZip(io.RawIOBase):
    def __init__(self):
        with urllib.request.urlopen(urllib.request.Request(URL, method="HEAD")) as response:
            self.url = response.url
            self.size = int(response.headers["Content-Length"])
        self.pos = 0

    def seekable(self):
        return True

    def seek(self, offset, whence=0):
        self.pos = offset if whence == 0 else (self.pos if whence == 1 else self.size) + offset
        return self.pos

    def tell(self):
        return self.pos

    def read(self, size=-1):
        if size < 0:
            size = self.size - self.pos
        if size == 0:
            return b""
        end = min(self.size, self.pos + size) - 1
        request = urllib.request.Request(self.url, headers={"Range": f"bytes={self.pos}-{end}"})
        with urllib.request.urlopen(request, timeout=120) as response:
            if response.status != 206:
                raise RuntimeError("Server did not honor Range; refusing full 1GB archive download")
            data = response.read()
        if len(data) != end - self.pos + 1:
            raise RuntimeError("Incomplete archive range")
        self.pos += len(data)
        return data


if __name__ == "__main__":
    target = pathlib.Path(__file__).resolve().parents[1] / ".tools" / "web_nothreads_release.zip"
    target.parent.mkdir(exist_ok=True)
    if target.exists():
        with zipfile.ZipFile(target) as saved:
            if saved.testzip() is not None:
                raise RuntimeError("Existing web template is corrupt")
        print("Web template already verified")
    else:
        with zipfile.ZipFile(RemoteZip()) as archive:
            name = next(n for n in archive.namelist() if n.endswith("/web_nothreads_release.zip"))
            data = archive.read(name)
        target.write_bytes(data)
        print(f"Fetched verified ZIP member: {target.name} ({len(data):,} bytes)")
