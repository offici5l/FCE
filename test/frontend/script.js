(function() {
    // DOM elements
    const form = document.getElementById('fceForm');
    const urlInput = document.getElementById('url');
    const fileInput = document.getElementById('file');
    const startBtn = document.getElementById('startBtn');
    const statusArea = document.getElementById('statusArea');
    const logContainer = document.getElementById('log');
    const downloadBtn = document.getElementById('downloadBtn');

    // The Render service endpoint base URL
    const apiBaseUrl = 'https://fce-service.onrender.com';

    function resetUI() {
        startBtn.disabled = false;
        statusArea.classList.add('hidden');
        downloadBtn.classList.add('hidden');
        logContainer.innerHTML = '';
    }

    form.addEventListener('submit', async (e) => {
        e.preventDefault();
        resetUI();

        const url = urlInput.value.trim();
        const file = fileInput.value.trim();

        if (!url || !file) {
            alert('Please provide both a URL and a file name.');
            return;
        }

        startBtn.disabled = true;
        statusArea.classList.remove('hidden');
        logContainer.innerHTML = 'Requesting task...\n';

        try {
            // 1. Start the extraction task
            const startResponse = await fetch(`${apiBaseUrl}/extract`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ url, file })
            });

            const responseText = await startResponse.text();
            let task_id;

            try {
                const jsonData = JSON.parse(responseText);
                if (jsonData.task_id) {
                    task_id = jsonData.task_id;
                } else {
                    throw new Error(jsonData.error || 'Unknown error in server response.');
                }
            } catch (e) {
                console.error("Could not parse JSON response from /extract. Raw response:", responseText);
                throw new Error('Server returned an invalid response. It might be running an old version of the code. Check browser console for details.');
            }

            logContainer.innerHTML += `Task started with ID: ${task_id}\nConnecting to live log...\n\n`;

            // 2. Connect to the live status stream
            const eventSource = new EventSource(`${apiBaseUrl}/status/${task_id}`);

            // 3. Handle incoming log messages
            eventSource.onmessage = (event) => {
                logContainer.innerHTML += `${event.data}\n`;
                logContainer.scrollTop = logContainer.scrollHeight;
            };

            // 4. Handle the 'done' event
            eventSource.addEventListener('done', (event) => {
                eventSource.close();
                logContainer.innerHTML += `\nSUCCESS: ${event.data}\n`;
                downloadBtn.href = `${apiBaseUrl}/download/${task_id}`;
                downloadBtn.classList.remove('hidden');
                startBtn.disabled = false;
            });

            // 5. Handle any errors
            const errorHandler = (err) => {
                eventSource.close();
                const message = (err && err.type === 'error' && err.data) ? err.data : 'Connection to status stream failed. Please check the server logs on Render.';
                logContainer.innerHTML += `\nERROR: ${message}`;
                console.error("EventSource failed:", err);
                startBtn.disabled = false;
            };
            eventSource.onerror = errorHandler;
            eventSource.addEventListener('error', errorHandler);

        } catch (err) {
            logContainer.innerHTML += `\nFATAL: ${err.message}`;
            console.error('Fatal error:', err);
            startBtn.disabled = false;
        }
    });

})();