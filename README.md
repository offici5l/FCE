# Firmware Content Extractor (FCE)

A tool to extract specific image files (e.g., `boot.img`) from firmware.zip

---

## Usage

<details>
<summary><strong>🌐 Web Interface (Recommended)</strong></summary>

> The easiest method. No installation needed.

1.  **[➡️ Go to the Web Interface](https://offici5l.github.io/FCE)**
2.  Paste the ROM download URL.
3.  Select the image file to extract.
4.  Click **Start** and wait for the download link.

</details>

<details>
<summary><strong>❯_ CLI Script</strong></summary>

> Remotely triggers and monitors the extraction process from your terminal.

-   **Prerequisites:** `curl` and `jq`
-   **Usage:**
    ```bash
    chmod +x script/fce.sh
    ./script/fce.sh "<rom_url>" "<file_to_extract>"
    ```
-   **Example:**
    ```bash
    ./script/fce.sh "https://example.com/firmware.zip" "boot"
    ```

</details>

<details>
<summary><strong>🐳 Docker Container</strong></summary>

> Runs the entire extraction process locally. Useful for automation.

-   **Prerequisite:** Docker
-   **Usage:**
    ```bash
    docker run --rm -v "$(pwd)/output:/workspace/output" ghcr.io/offici5l/fce:latest "<rom_url>" "<file_to_extract>"
    ```
-   **Note:** Extracted files will appear in a new `output` directory in your current location.

</details>