"""Fast, portable integrity checks; native compilation and XCTest run on macOS."""
import json
import plistlib
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "ScreensaverTrivia"


def main():
    catalog = json.loads((APP / "Resources/locations.json").read_text(encoding="utf-8"))
    assert len(catalog) >= 4
    assert len({row["id"] for row in catalog}) == len(catalog)
    for row in catalog:
        assert row["name"] and row["author"] and row["license"]
        assert row["sourceURL"].startswith("https://commons.wikimedia.org/")
        assert row["licenseURL"].startswith("https://")
        for ext in ["mp4", "jpg"]:
            path = APP / "Resources/Media" / (row["id"] + "." + ext)
            assert path.is_file() and path.stat().st_size > 10_000, path
        # MP4 must contain fast-start movie metadata before video data, and H.264.
        data = (APP / "Resources/Media" / (row["id"] + ".mp4")).read_bytes()
        assert b"avc1" in data
        assert data.index(b"moov") < data.index(b"mdat")
    for name in ["world", "cities", "waterfront"]:
        assert sum(name in row["collectionIDs"] for row in catalog) >= 4
    info = plistlib.loads((APP / "Resources/Info.plist").read_bytes())
    assert "_screen-trivia._tcp" in info["NSBonjourServices"]
    assert info["NSLocalNetworkUsageDescription"]
    assert set(info["UISupportedInterfaceOrientations"]) == {"UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"}
    plistlib.loads((APP / "Resources/PrivacyInfo.xcprivacy").read_bytes())
    project = (ROOT / "ScreensaverTrivia.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
    for path in APP.rglob("*.swift"):
        assert path.relative_to(APP).as_posix() in project, path
    ET.parse(ROOT / "ScreensaverTrivia.xcodeproj/xcshareddata/xcschemes/ScreensaverTrivia.xcscheme")
    size = sum(path.stat().st_size for path in (APP / "Resources/Media").iterdir())
    print(f"PASS: {len(catalog)} complete offline locations, attribution, H.264 assets, privacy/permissions, shared scheme and source membership. Media pack {size / 1024 / 1024:.1f} MiB.")


if __name__ == "__main__":
    main()
