
(function() {
    // DOM elements
    const form = document.getElementById('fceForm');
    const urlInput = document.getElementById('url');
    const fileInput = document.getElementById('file');
    const startBtn = document.getElementById('startBtn');
    const statusMessage = document.getElementById('status-message');
    const badge = document.getElementById('badge');

    // The local endpoint for the Docker service
    const localEndpoint = 'https://fce-service.onrender.com/extract';

    function setStatus(message, badgeType, badgeText) {
        statusMessage.textContent = message;
        if (badgeType && badgeText) {
            badge.textContent = badgeText;
            badge.className = `badge ${badgeType}`;
        } else {
            badge.textContent = '';
        }
    }

    // Function to trigger file download in the browser
    function downloadFile(blob, filename) {
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.style.display = 'none';
        a.href = url;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        window.URL.revokeObjectURL(url);
        document.body.removeChild(a);
    }

    form.addEventListener('submit', async (e) => {
        e.preventDefault();

        const url = urlInput.value.trim();
        const file = fileInput.value.trim();

        if (!url || !file) {
            setStatus('Please provide both a URL and a file name.', 'err', 'Error');
            return;
        }

        // Disable button and set initial status
        startBtn.disabled = true;
        setStatus('Sending request to local server... This might take a very long time. Please be patient and check the Docker logs for progress.', 'warn', 'Working');

        try {
            const response = await fetch(localEndpoint, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ url, file })
            });

            const contentType = response.headers.get("content-type");

            if (response.ok && contentType && contentType.includes("application/zip")) {
                // --- Success: Handle File Download ---
                setStatus('Success! File is ready. Download will begin shortly.', 'ok', 'Success');
                const blob = await response.blob();
                downloadFile(blob, `${file}.zip`);
            } else {
                // --- Error: Handle JSON error from server ---
                const errorData = await response.json();
                const errorMessage = errorData.log || errorData.error || 'An unknown error occurred.';
                console.error('Server Error:', errorMessage);
                setStatus(`Error: ${errorMessage}`, 'err', 'Error');
            }

        } catch (err) {
            console.error('Network or other error:', err);
            setStatus('Could not connect to the local server. Is the Docker container running and is port 8080 mapped?', 'err', 'Error');
        } finally {
            // Re-enable the button
            startBtn.disabled = false;
        }
    });

})();
