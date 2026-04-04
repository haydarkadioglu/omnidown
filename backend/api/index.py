from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
import yt_dlp
import json

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

@app.get("/api/extract")
def extract_video(url: str = Query(..., description="Video URL")):
    ydl_opts = {
        'format': 'best',
        'quiet': True,
        'no_warnings': True,
        'nocheckcertificate': True,
        'ignoreerrors': True,
        'skip_download': True,
        'user_agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
            if not info:
                raise HTTPException(status_code=404, detail="Could not fetch video information.")
            
            # Main metadata
            result = {
                "title": info.get("title", "Unknown Title"),
                "thumbnail": info.get("thumbnail", ""),
                "formats": []
            }

            # Extract formats and map to our Dart model (FormatOption)
            formats = info.get("formats", [])
            if not formats and "url" in info:
                formats = [info]

            for f in formats:
                if not f.get("url"): continue
                
                ext = f.get("ext", "mp4")
                vcodec = f.get("vcodec", "none")
                acodec = f.get("acodec", "none")
                height = f.get("height")
                filesize = f.get("filesize") or f.get("filesize_approx") or 0
                
                is_audio = vcodec == "none" and acodec != "none"
                
                # Add bitrate if audio, resolution if video
                if is_audio:
                    label = f"Audio {ext.upper()} ({f.get('abr', 0)}kbps)"
                else:
                    label = f"{height}p {ext.upper()}" if height else f"Video {ext.upper()}"

                result["formats"].append({
                    "id": f.get("format_id", "unknown"),
                    "label": label,
                    "isAudioOnly": is_audio,
                    "downloadUrl": f.get("url"),
                    "outputExtension": ext,
                    "estimatedSizeBytes": int(filesize)
                })

            return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
