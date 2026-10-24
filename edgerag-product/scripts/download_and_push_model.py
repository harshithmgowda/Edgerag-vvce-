import os
import sys
import time
import requests
import subprocess

MODELS = {
    "qwen": {
        "name": "qwen2.5-0.5b-instruct-q4_k_m.gguf",
        "url": "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf",
        "desc": "Qwen 2.5 0.5B Instruct Q4_K_M (468 MB - Fast, Low RAM, High Quality)"
    },
    "phi3": {
        "name": "Phi-3-mini-4k-instruct-q4.gguf",
        "url": "https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/Phi-3-mini-4k-instruct-q4.gguf",
        "desc": "Microsoft Phi-3 Mini 4K Instruct Q4 (2.39 GB - High Capacity, 6GB+ RAM)"
    }
}

def download_file(url, target_path):
    print(f"[*] Connecting to download URL: {url}")
    r = requests.get(url, stream=True, allow_redirects=True, timeout=30)
    if r.status_code != 200:
        raise Exception(f"Download failed with status {r.status_code}")

    total_size = int(r.headers.get("content-length", 0))
    print(f"[*] Total file size: {total_size / (1024*1024):.2f} MB")

    downloaded = 0
    start_time = time.time()
    last_print = start_time

    os.makedirs(os.path.dirname(target_path), exist_ok=True)
    with open(target_path, "wb") as f:
        for chunk in r.iter_content(chunk_size=1024 * 512):
            if chunk:
                f.write(chunk)
                downloaded += len(chunk)
                now = time.time()
                if now - last_print > 3:
                    last_print = now
                    pct = (downloaded / total_size * 100) if total_size else 0
                    mb = downloaded / (1024 * 1024)
                    speed = mb / (now - start_time)
                    print(f"[*] Progress: {mb:.1f} MB / {total_size/(1024*1024):.1f} MB ({pct:.1f}%) @ {speed:.2f} MB/s")

    elapsed = time.time() - start_time
    print(f"[✓] Download completed in {elapsed:.1f}s: {target_path}")

def push_to_phone(local_path, device_id="5B031XEBF1W30C"):
    adb = r"C:\Users\Harshith\AppData\Local\Android\Sdk\platform-tools\adb.exe"
    dest_dir = "/sdcard/Android/data/com.edgerag.mobile/files/models/"
    print(f"[*] Pushing {os.path.basename(local_path)} to device {device_id}...")
    cmd = [adb, "-s", device_id, "push", local_path, dest_dir]
    res = subprocess.run(cmd, capture_output=True, text=True)
    print(res.stdout)
    if res.returncode == 0:
        print("[✓] Push completed successfully to phone storage!")
        verify = subprocess.run([adb, "-s", device_id, "shell", f"ls -lh {dest_dir}"], capture_output=True, text=True)
        print("[*] Phone models folder contents:\n", verify.stdout)
    else:
        print("[!] ADB push error:\n", res.stderr)

if __name__ == "__main__":
    choice = sys.argv[1] if len(sys.argv) > 1 else "qwen"
    selected = MODELS.get(choice, MODELS["qwen"])
    print(f"=== EdgeRAG On-Device Offline Model Installer ===")
    print(f"Target: {selected['desc']}")

    save_dir = r"c:\Users\Harshith\OneDrive\Desktop\edgerag\edgerag-product\storage\models"
    target_file = os.path.join(save_dir, selected["name"])

    if not os.path.exists(target_file):
        download_file(selected["url"], target_file)
    else:
        print(f"[✓] Model file already exists locally: {target_file}")

    push_to_phone(target_file)
