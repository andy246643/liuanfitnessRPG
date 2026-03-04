import urllib.request
import re

url = "https://elements.envato.com/game-point-HQUX8GN"
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'})
try:
    html = urllib.request.urlopen(req).read().decode('utf-8')
    match = re.search(r'https://[^"]+\.mp3\b', html)
    if match:
        audio_url = match.group(0)
        print("FOUND:", audio_url)
        # Handle envato redirect or direct url
        urllib.request.urlretrieve(audio_url, "C:/dev/liuan_fitness_rpg_flutter/fitness_rpg_app/assets/audio/game_point.mp3")
        print("Downloaded to game_point.mp3")
    else:
        print("No .mp3 links found in the HTML source.")
except Exception as e:
    print("Error:", e)
