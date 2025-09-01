(function(){
  const $ = (s, r=document)=>r.querySelector(s);
  const badge = $("#statusBadge");
  const outWrap = $("#outWrap");
  const startBtn = $("#startBtn");
  const outputFooter = $("#output-footer");
  const progressBar = $("#progressBar");
  const stepIcon = $("#stepIcon");
  const stepTitle = $("#stepTitle");
  const stepStatus = $("#stepStatus");
  const stepDisplay = $("#stepDisplay");
  const proxyEndpoint = 'https://fce-proxy.vercel.app/api/trigger';

  const sleep = (ms)=>new Promise(r=>setTimeout(r,ms));

  function setBadge(text, cls){
    badge.textContent = text;
    badge.className = `badge ${cls||''}`.trim();
  }

  function updateStepDisplay({ title, status, icon, progress }) {
    if (title) stepTitle.textContent = title;
    stepStatus.innerHTML = status || '';
    if (icon) stepIcon.className = `step-icon ${icon}`;
    if (progress !== undefined) progressBar.style.width = `${progress}%`;
  }

  function showOutputLink(url){
    outputFooter.style.visibility = 'visible';
    outWrap.innerHTML = `<a href="${url}" target="_blank" rel="noopener">${url}</a>`;
  }

  function createUniqueId(url, file){
    try{
      const b = url.split('/').pop() || '';
      const nameOnly = (b.split('?')[0]||'').split('.').slice(0,-1).join('.') || b.split('?')[0] || 'file';
      return `${file}_${nameOnly}`;
    }catch{ return `${file}_${Date.now()}` }
  }

  async function callProxy(body){
    const res = await fetch(proxyEndpoint, {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify(body)
    });
    const data = await res.json();
    if(!res.ok || data.ok === false){
        const errorMsg = data.error || `HTTP Error ${res.status}`;
        const err = new Error(errorMsg);
        err.status = res.status;
        throw err;
    }
    return data;
  }

  function resetUI(){
    outputFooter.style.visibility = 'hidden';
    outWrap.innerHTML = '<em>—</em>';
    updateStepDisplay({
      title: 'Ready to start',
      status: '',
      icon: '',
      progress: 0
    });
    setBadge('Idle');
    startBtn.disabled = false;
  }

  $('#fceForm').addEventListener('submit', async (e)=>{
    e.preventDefault();
    resetUI();

    const url = $("#url").value.trim();
    const file = $("#file").value.trim();

    if(!url || !file){
      setBadge('Missing input','err');
      return;
    }

    const uniqueId = createUniqueId(url, file);
    const outputUrl = `https://github.com/offici5l/FCE/releases/download/${encodeURIComponent(uniqueId)}/${encodeURIComponent(file)}.zip`;

    startBtn.disabled = true;
    setBadge('Working…', 'warn');

    try {
      updateStepDisplay({
        title: 'Checking for pre-existing file',
        status: `Checking: ${outputUrl}`,
        icon: 'spin',
        progress: 5
      });
      const checkRes = await callProxy({ action: 'check_output', output_url: outputUrl });
      if (checkRes.status === 200) {
          updateStepDisplay({
            title: 'File already exists',
            status: 'Found. Download link is ready.',
            icon: 'ok',
            progress: 100
          });
          setBadge('Found', 'ok');
          showOutputLink(outputUrl);
          return;
      }
      updateStepDisplay({ progress: 10 });

      updateStepDisplay({
        title: 'Triggering workflow',
        status: 'Sending request to start the process…',
        icon: 'spin',
        progress: 15
      });
      await callProxy({ action: 'trigger', url, file, unique_id: uniqueId });
      updateStepDisplay({ progress: 20 });

      updateStepDisplay({
        title: 'Finding workflow run',
        status: 'Waiting for the workflow to appear…',
        icon: 'spin',
        progress: 25
      });
      let delay = 10000;
      let runId;
      for(let attempt=1; attempt<=60; attempt++) {
        updateStepDisplay({ status: `waiting... (attempt ${attempt}, delay ${delay/1000}s)` });
        await sleep(delay);
        delay = Math.min(delay + 1000, 15000);
        const runsData = await callProxy({ action: 'get_runs' });
        for(const run of (runsData.workflow_runs || [])){
          const jobsData = await callProxy({ action: 'get_jobs', run_id: run.id });
          if(jobsData.jobs && jobsData.jobs.find(j=> j.name === uniqueId)){
            runId = run.id;
            break;
          }
        }
        if(runId) break;
      }
      if (!runId) throw new Error("Could not find a matching workflow run in 60 attempts.");
      updateStepDisplay({ status: `Detected Run ID: ${runId}`, progress: 40 });

      const ignoredSteps = ['set up job', 'initialize containers', 'checkout source', 'post checkout source', 'stop containers', 'complete job'];
      let status, conclusion;

      while(status !== 'completed'){
        await sleep(delay);
        delay = Math.min(delay + 1000, 15000);
        const run = await callProxy({ action: 'get_run_details', run_id: runId });
        status = run.status;
        conclusion = run.conclusion;

        const jobsData = await callProxy({ action: 'get_jobs', run_id: runId });
        const job = jobsData.jobs && jobsData.jobs[0];
        if(!job){ continue; }

        const jobDetails = await callProxy({ action: 'get_job_details', job_id: job.id });
        const workflowSteps = (jobDetails.steps || []).filter(s => !ignoredSteps.includes(s.name.toLowerCase()));
        const totalWorkflowSteps = workflowSteps.length;
        let completedWorkflowSteps = 0;

        for(const s of workflowSteps){
          if (s.status === 'completed') {
            completedWorkflowSteps++;
          } else if (s.status === 'in_progress') {
            updateStepDisplay({
              title: s.name,
              icon: 'spin'
            });
          }

          if (s.conclusion === 'failure' || s.conclusion === 'skipped') {
            const runUrl = `https://github.com/offici5l/FCE/actions/runs/${runId}`;
            throw new Error(`Step "${s.name}" failed. See <a href="${runUrl}" target="_blank" rel="noopener">details</a>.`);
          }
        }
        
        if (totalWorkflowSteps > 0) {
            const workflowProgress = (completedWorkflowSteps / totalWorkflowSteps) * 50; // 50% of total progress
            updateStepDisplay({ progress: 40 + workflowProgress });
        }
      }
      if (conclusion !== 'success') throw new Error(`Workflow failed with conclusion: ${conclusion}.`);
      updateStepDisplay({ progress: 90 });
      
      updateStepDisplay({
        title: 'Checking for output',
        status: 'Waiting for the download link to be ready…',
        icon: 'spin',
        progress: 95
      });
      delay = 10000;
      let outputFound = false;
      for(let i=0;i<30;i++){
        updateStepDisplay({ status: `waiting... (attempt ${i+1}, delay ${delay/1000}s)` });
        const res = await callProxy({ action: 'check_output', output_url: outputUrl });
        if(res.status === 200){
          showOutputLink(outputUrl);
          outputFound = true;
          break;
        }
        await sleep(delay);
        delay = Math.min(delay + 1000, 15000);
      }

      if(outputFound) {
        updateStepDisplay({
          title: 'Success!',
          status: 'Download link is ready.',
          icon: 'ok',
          progress: 100
        });
        setBadge('Success', 'ok');
      } else {
        throw new Error("Output not found after 30 attempts.");
      }

    } catch (err) {
      console.error(err);
      updateStepDisplay({
        title: 'Error',
        status: err.message,
        icon: 'err',
      });
      setBadge('Error', 'err');
    } finally {
      startBtn.disabled = false;
    }
  });

  resetUI();
})();