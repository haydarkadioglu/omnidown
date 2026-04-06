from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
import yt_dlp
import os
import tempfile

app = FastAPI()

# CORS settings for Flutter app access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def read_root():
    return {"message": "OmniDown Python Backend is Running!"}


def _is_youtube(url: str) -> bool:
    lower = url.lower()
    return "youtube.com" in lower or "youtu.be" in lower


def _extract_youtube(url: str) -> dict:
    """Use pytubefix — works without cookies on datacenter IPs."""
    from pytubefix import YouTube
    from pytubefix.cli import on_progress

    yt = YouTube(url, use_oauth=False, allow_oauth_cache=False)
    yt.bypass_age_gate()

    formats = []

    # Progressive (video+audio) streams
    for stream in yt.streams.filter(progressive=True).order_by("resolution").desc():
        res = stream.resolution or "unknown"
        ext = stream.subtype or "mp4"
        size = stream.filesize or 0
        formats.append({
            "id": str(stream.itag),
            "label": f"{res} {ext.upper()} (video+audio)",
            "isAudioOnly": False,
            "downloadUrl": stream.url,
            "outputExtension": ext,
            "estimatedSizeBytes": size,
        })

    # Audio-only streams
    for stream in yt.streams.filter(only_audio=True).order_by("abr").desc():
        abr = stream.abr or "?"
        ext = stream.subtype or "mp4"
        size = stream.filesize or 0
        formats.append({
            "id": str(stream.itag),
            "label": f"Audio {ext.upper()} ({abr})",
            "isAudioOnly": True,
            "downloadUrl": stream.url,
            "outputExtension": ext,
            "estimatedSizeBytes": size,
        })

    return {
        "title": yt.title or "Unknown Title",
        "thumbnail": yt.thumbnail_url or "",
        "formats": formats,
    }


def _extract_ytdlp(url: str) -> dict:
    """Use yt-dlp as fallback for all other platforms."""
    local_cookies = os.path.join(os.path.dirname(__file__), 'cookies.txt')
    env_cookies = os.environ.get("YOUTUBE_COOKIES", "")

    ydl_opts = {
        'format': 'best',
        'quiet': True,
        'no_warnings': True,
        'nocheckcertificate': True,
        'ignoreerrors': False,
        'skip_download': True,
        'user_agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    }

    if os.path.isfile(local_cookies):
        ydl_opts['cookiefile'] = local_cookies
    elif env_cookies.strip():
        tmp = tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False)
        tmp.write(env_cookies)
        tmp.close()
        ydl_opts['cookiefile'] = tmp.name

    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(url, download=False)
        if not info:
            raise HTTPException(status_code=404, detail="Could not fetch video information.")

        formats = info.get("formats", [])
        if not formats and "url" in info:
            formats = [info]

        result_formats = []
        for f in formats:
            if not f.get("url"):
                continue
            ext = f.get("ext", "mp4")
            vcodec = f.get("vcodec", "none")
            acodec = f.get("acodec", "none")
            height = f.get("height")
            filesize = f.get("filesize") or f.get("filesize_approx") or 0
            is_audio = vcodec == "none" and acodec != "none"
            label = f"Audio {ext.upper()} ({f.get('abr', 0)}kbps)" if is_audio else (f"{height}p {ext.upper()}" if height else f"Video {ext.upper()}")
            result_formats.append({
                "id": f.get("format_id", "unknown"),
                "label": label,
                "isAudioOnly": is_audio,
                "downloadUrl": f.get("url"),
                "outputExtension": ext,
                "estimatedSizeBytes": int(filesize),
            })

        return {
            "title": info.get("title", "Unknown Title"),
            "thumbnail": info.get("thumbnail", ""),
            "formats": result_formats,
        }


@app.get("/api/extract")
def extract_video(url: str = Query(..., description="Video URL")):
    try:
        if _is_youtube(url):
            result = _extract_youtube(url)
        else:
            result = _extract_ytdlp(url)

        if not result.get("formats"):
            raise HTTPException(status_code=404, detail="No downloadable formats found.")

        return result
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
