"""Rebuild the bundled, silent H.264 location pack from attributed Commons footage.

Development-only dependencies: Python 3, Pillow, imageio-ffmpeg.
The iOS application has no Python, network or package-manager dependency.
"""
import html
import json
import re
import subprocess
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MEDIA = ROOT / "ScreensaverTrivia" / "Resources" / "Media"
CACHE = ROOT / ".media-cache"
PACK = [
    ("san-francisco", "San Francisco", "United States", "Fog rolls across the Golden Gate, linking San Francisco to the Marin Headlands.",
     ["world", "cities", "waterfront"], "Golden Gate Bridge Timelapse.webm"),
    ("paris", "Paris", "France", "The Eiffel Tower rises above the rooftops of the French capital.",
     ["world", "cities"], "Sunset on Eiffel Tower in Paris - Vimeo.webm"),
    ("sydney", "Sydney", "Australia", "The Opera House’s sail-like shells sit on Bennelong Point in Sydney Harbour.",
     ["world", "cities", "waterfront"], "Sydney Opera House drone.webm"),
    ("glanni", "Glanni Falls", "Iceland", "The Norðurá River tumbles over dark volcanic rock at Glanni in western Iceland.",
     ["world", "waterfront"], "Glanni waterfalls in northern Iceland.webm"),
    ("dubai", "Dubai", "United Arab Emirates", "The Burj Khalifa anchors the skyline of this city on the Arabian Gulf.",
     ["world", "cities"], "Dubai skyline 2013.webm"),
    ("new-york", "New York City", "United States", "Manhattan’s dense skyline rises between the Hudson and East rivers.",
     ["world", "cities", "waterfront"], "Time Lapse of New York City.ogv"),
]


def fetch(url, destination=None):
    for attempt in range(5):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "ScreensaverTrivia/0.1 (github.com/riverdevprojects/screensaver-trivia; offline educational game)"})
            with urllib.request.urlopen(req, timeout=120) as response:
                data = response.read()
            if destination:
                destination.write_bytes(data)
            return data
        except Exception:
            if attempt == 4:
                raise
            time.sleep(5 * (attempt + 1))


def plain(value):
    return " ".join(html.unescape(re.sub(r"<[^>]+>", "", value)).split())


def main():
    import imageio_ffmpeg
    from PIL import Image, ImageDraw
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    MEDIA.mkdir(parents=True, exist_ok=True)
    CACHE.mkdir(exist_ok=True)
    metadata_file = CACHE / "metadata.json"
    if metadata_file.exists():
        metadata = json.loads(metadata_file.read_text(encoding="utf-8"))
    else:
        query = urllib.parse.urlencode({
            "action": "query", "format": "json", "titles": "|".join("File:" + row[5] for row in PACK),
            "prop": "videoinfo", "viprop": "url|size|derivatives|extmetadata"
        })
        data = json.loads(fetch("https://commons.wikimedia.org/w/api.php?" + query))
        metadata = {p["title"]: p["videoinfo"][0] for p in data["query"]["pages"].values()}
        metadata_file.write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8")

    catalog = []
    for location_id, name, country, detail, collections, filename in PACK:
        print(f"Preparing {name}", flush=True)
        info = metadata["File:" + filename]
        ext = info["extmetadata"]
        source = CACHE / filename
        if not source.exists():
            url = info["url"]
            # For long source videos download the smaller 720p derivative.
            if info.get("size", 0) > 40 * 1024 * 1024:
                derivatives = [d for d in info.get("derivatives", []) if d.get("transcodekey") == "720p.vp9.webm"]
                if derivatives:
                    url = derivatives[0]["src"]
            fetch(url, source)
            time.sleep(1)
        video = MEDIA / (location_id + ".mp4")
        if not video.exists():
            subprocess.run([ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-stream_loop", "-1", "-i", str(source),
                "-t", "15", "-an", "-vf", "scale=1280:720:force_original_aspect_ratio=increase,crop=1280:720,setsar=1",
                "-r", "24", "-c:v", "libx264", "-preset", "fast", "-crf", "25", "-pix_fmt", "yuv420p",
                "-movflags", "+faststart", "-map_metadata", "-1", str(video)], check=True)
        poster = MEDIA / (location_id + ".jpg")
        subprocess.run([ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-ss", "1", "-i", str(video),
                        "-frames:v", "1", "-q:v", "3", str(poster)], check=True)
        catalog.append({
            "id": location_id, "name": name, "country": country, "detail": detail, "collectionIDs": collections,
            "sourceTitle": filename, "sourceURL": info["descriptionurl"],
            "author": plain(ext.get("Artist", {}).get("value", "See source page")),
            "license": plain(ext.get("LicenseShortName", {}).get("value", "See source page")),
            "licenseURL": html.unescape(ext.get("LicenseUrl", {}).get("value", info["descriptionurl"])).replace("http://", "https://", 1),
        })
    (MEDIA.parent / "locations.json").write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    credits = ["# Location media credits", "", "All game footage is bundled for offline playback. Each clip is a 15-second, muted, scaled/cropped H.264 adaptation of the source below; short originals are looped. Adapted media retains the source license. These licenses apply to the respective media files, independently of application source code. No Apple TV or SongPop media is included.", ""]
    for entry in catalog:
        credits.extend([f"## {entry['name']}", "", f"- File: `ScreensaverTrivia/Resources/Media/{entry['id']}.mp4` and its JPEG poster.",
            f"- Creator: {entry['author']}", f"- Source: [{entry['sourceTitle']}]({entry['sourceURL']})",
            f"- License: [{entry['license']}]({entry['licenseURL']})", ""])
    (ROOT / "MEDIA_CREDITS.md").write_text("\n".join(credits), encoding="utf-8")
    sheet = Image.new("RGB", (960, ((len(catalog) + 1) // 2) * 290), "#221141")
    draw = ImageDraw.Draw(sheet)
    for index, entry in enumerate(catalog):
        x, y = (index % 2) * 480, (index // 2) * 290
        with Image.open(MEDIA / (entry["id"] + ".jpg")) as image:
            sheet.paste(image.resize((480, 270)), (x, y))
        draw.text((x + 8, y + 273), entry["name"], fill="white")
    sheet.save(CACHE / "contact-sheet.jpg")
    print(f"Prepared {len(catalog)} offline locations. Contact sheet: {CACHE / 'contact-sheet.jpg'}", flush=True)


if __name__ == "__main__":
    main()
