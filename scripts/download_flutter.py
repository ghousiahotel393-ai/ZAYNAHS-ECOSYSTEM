import os
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor

URL = "https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_3.24.5-stable.zip"
TARGET = os.path.expanduser("~/flutter/flutter.zip")
NUM_THREADS = 16

import ssl

ctx = ssl._create_unverified_context()

def get_content_length(url):
    req = urllib.request.Request(url, method="HEAD")
    with urllib.request.urlopen(req, context=ctx) as resp:
        return int(resp.headers["Content-Length"])

def download_chunk(url, start, end, chunk_id, temp_dir):
    chunk_path = os.path.join(temp_dir, f"chunk_{chunk_id:03d}.part")
    req = urllib.request.Request(url, headers={"Range": f"bytes={start}-{end}"})
    with urllib.request.urlopen(req, context=ctx) as resp, open(chunk_path, "wb") as f:
        while True:
            data = resp.read(1024 * 1024)
            if not data:
                break
            f.write(data)
    return chunk_id, chunk_path

def main():
    os.makedirs(os.path.dirname(TARGET), exist_ok=True)
    temp_dir = os.path.expanduser("~/flutter/chunks")
    os.makedirs(temp_dir, exist_ok=True)

    print("Querying total archive size...")
    total_size = get_content_length(URL)
    print(f"Total size: {total_size / (1024*1024):.2f} MB ({total_size} bytes)")

    chunk_size = total_size // NUM_THREADS
    ranges = []
    for i in range(NUM_THREADS):
        start = i * chunk_size
        end = (start + chunk_size - 1) if i < NUM_THREADS - 1 else (total_size - 1)
        ranges.append((start, end, i))

    print(f"Starting parallel download with {NUM_THREADS} concurrent threads...")
    completed = 0
    with ThreadPoolExecutor(max_workers=NUM_THREADS) as executor:
        futures = [
            executor.submit(download_chunk, URL, start, end, idx, temp_dir)
            for start, end, idx in ranges
        ]
        for f in futures:
            idx, path = f.result()
            completed += 1
            print(f"  Chunk {completed}/{NUM_THREADS} downloaded.")

    print("Assembling chunks into final zip...")
    with open(TARGET, "wb") as outfile:
        for i in range(NUM_THREADS):
            chunk_file = os.path.join(temp_dir, f"chunk_{i:03d}.part")
            with open(chunk_file, "rb") as infile:
                while True:
                    data = infile.read(4 * 1024 * 1024)
                    if not data:
                        break
                    outfile.write(data)
            os.remove(chunk_file)

    os.rmdir(temp_dir)
    final_size = os.path.getsize(TARGET)
    print(f"Successfully assembled {final_size} bytes! Target: {TARGET}")

if __name__ == "__main__":
    main()
