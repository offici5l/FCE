# fast_extractor.py
import sys
import os
import subprocess
from remotezip import RemoteZip

def main(url, file_to_extract):
    print("[INFO] Using fast extractor.")
    
    # Create output directory if it doesn't exist
    os.makedirs("./output", exist_ok=True)

    try:
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
        }
        with RemoteZip(url, headers=headers) as z:
            filenames = [f.filename for f in z.infolist()]
            
            target_img = f"{file_to_extract}.img"
            output_zip = f"./output/{file_to_extract}.zip"

            if target_img in filenames:
                print(f"[INFO] Found {target_img} in remote zip. Extracting...")
                z.extract(target_img, "./output")
                extracted_file = f"./output/{target_img}"
                
                print(f"[INFO] Compressing {extracted_file} to {output_zip}...")
                subprocess.run(["zip", "-9", output_zip, extracted_file], check=True, capture_output=True)
                os.remove(extracted_file)
                
            elif "payload.bin" in filenames:
                print("[INFO] Found payload.bin in remote zip. Extracting...")
                z.extract("payload.bin", ".")
                
                print("[INFO] Running payload_dumper...")
                subprocess.run(
                    ["python3", "/tools/payload_dumper.py", "--out", "./output", "--images", file_to_extract, "payload.bin"],
                    check=True, capture_output=True
                )
                
                output_img = f"./output/{file_to_extract}.img"
                if not os.path.exists(output_img):
                    print(f"ERROR: Could not find or extract '{file_to_extract}' from payload.bin.")
                    sys.exit(1)
                
                print(f"[INFO] Compressing {output_img} to {output_zip}...")
                subprocess.run(["zip", "-9", output_zip, output_img], check=True, capture_output=True)
                os.remove(output_img)
                os.remove("payload.bin")
            else:
                print(f"ERROR: Neither '{target_img}' nor 'payload.bin' were found in the archive.")
                sys.exit(1)
            
            print(f"[DONE] Extracted and compressed: {output_zip}")

    except Exception as e:
        print(f"An error occurred: {e}")
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python fast_extractor.py <URL> <FILE_TO_EXTRACT>")
        sys.exit(1)
    
    main(sys.argv[1], sys.argv[2])
