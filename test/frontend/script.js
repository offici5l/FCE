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

            if (!startResponse.ok) {
                throw new Error('Failed to start the task on the server.');
            }

            const { task_id } = await startResponse.json();
            logContainer.innerHTML += `Task started with ID: ${task_id}\nConnecting to live log...\n\n`;

            // 2. Connect to the live status stream
            const eventSource = new EventSource(`${apiBaseUrl}/status/${task_id}`);

            // 3. Handle incoming log messages
            eventSource.onmessage = (event) => {
                logContainer.innerHTML += `${event.data}\n`;
                // Auto-scroll to the bottom
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
            eventSource.onerror = (err) => {
                eventSource.close();
                logContainer.innerHTML += '\nERROR: Connection to status stream failed. Please check the server logs on Render.';
                console.error("EventSource failed:", err);
                startBtn.disabled = false;
            };
            
            eventSource.addEventListener('error', (event) => {
                eventSource.close();
                logContainer.innerHTML += `\nERROR: ${event.data}\n`;
                startBtn.disabled = false;
            });

        } catch (err) {
            logContainer.innerHTML += `\nFATAL: ${err.message}`;
            console.error('Fatal error:', err);
            startBtn.disabled = false;
        }
    });

})();
