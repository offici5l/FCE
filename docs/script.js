(function(){
  const $ = (s, r=document)=>r.querySelector(s);
  const stepsEl = $("#steps");
  const badge = $("#statusBadge");
  const outWrap = $("#outWrap");
  const startBtn = $("#startBtn");
  const outputFooter = $("#output-footer");
  const proxyEndpoint = 'https://fce-proxy.vercel.app/api/trigger';

  const sleep = (ms)=>new Promise(r=>setTimeout(r,ms));

  function setBadge(text, cls){
    badge.textContent = text;
    badge.className = `badge ${cls||''}`.trim();
  }

  const stepRegistry = new Map();
  function makeStep(id, name, {isSubStep = false} = {}){
    const el = document.createElement('div');
    el.className = 'step' + (isSubStep ? ' sub-step' : '');
    el.innerHTML = `<div class="dot" aria-hidden="true"></div><div class="name"></div><div class="status"></div>`;
    $(".name", el).textContent = name;
    $(".status", el).textContent = 'pending';
    stepsEl.appendChild(el);
    stepRegistry.set(id, el);
    return el;
  }

  function setStepStatus(id, statusText){
    const el = stepRegistry.get(id);
    if(el) $(".status", el).textContent = statusText;
  }

  function setStepAs(id, state, conclusion){
    const el = stepRegistry.get(id);
    if(!el) return;
    const dot = $(".dot", el);
    const statEl = $(".status", el);
    if(state==='in_progress'){
      statEl.textContent = 'in progress…';
      dot.className = 'dot spin';
    } else if(state==='completed'){
      if(conclusion==='success'){
        statEl.textContent = 'done';
        dot.className = 'dot ok';
      } else {
        statEl.textContent = conclusion || 'failed';
        dot.className = 'dot err';
      }
    } else {
      statEl.textContent = state || 'pending';
      dot.className = 'dot';
    }
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

  $('#fceForm').addEventListener('submit', async (e)=>{
    e.preventDefault();

    stepsEl.innerHTML = '';
    outputFooter.style.visibility = 'hidden';
    outWrap.innerHTML = '<em>—</em>';
    stepRegistry.clear();

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
    let activeStepId = '';

    try {
      activeStepId = 'precheck';
      makeStep(activeStepId, 'Checking for pre-existing file');
      setStepAs(activeStepId, 'in_progress');
      setStepStatus(activeStepId, `Checking: ${outputUrl}`);
      const checkRes = await callProxy({ action: 'check_output', output_url: outputUrl });
      if (checkRes.status === 200) {
          setStepAs(activeStepId, 'completed', 'success');
          setStepStatus(activeStepId, 'Found. Download link is ready.');
          setBadge('Found', 'ok');
          showOutputLink(outputUrl);
          return;
      }
      setStepAs(activeStepId, 'completed', 'success');
      setStepStatus(activeStepId, 'Not found, proceeding.');

      activeStepId = 'trigger';
      makeStep(activeStepId, 'Triggering workflow');
      setStepAs(activeStepId, 'in_progress');
      await callProxy({ action: 'trigger', url, file, unique_id: uniqueId });
      setStepAs(activeStepId, 'completed', 'success');

      activeStepId = 'find_run';
      makeStep(activeStepId, 'Finding workflow run');
      setStepAs(activeStepId, 'in_progress');
      let delay = 10000;
      let runId;
      for(let attempt=1; attempt<=60; attempt++) {
        setStepStatus(activeStepId, `waiting... (attempt ${attempt}, delay ${delay/1000}s)`);
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
      setStepAs(activeStepId, 'completed', 'success');
      setStepStatus(activeStepId, `Detected Run ID: ${runId}`);

      activeStepId = 'track';
      makeStep(activeStepId, 'Executing workflow');
      setStepAs(activeStepId, 'in_progress');
      let status = 'in_progress';
      let conclusion = '';
      delay = 10000;
      const dynamicSteps = new Map();

      while(status !== 'completed'){
        await sleep(delay);
        delay = Math.min(delay + 1000, 15000);
        const run = await callProxy({ action: 'get_run_details', run_id: runId });
        status = run.status;
        conclusion = run.conclusion;
        setStepStatus(activeStepId, `Workflow status: ${status}`);

        const jobsData = await callProxy({ action: 'get_jobs', run_id: runId });
        const job = jobsData.jobs && jobsData.jobs[0];
        if(!job){ continue; }

        const jobDetails = await callProxy({ action: 'get_job_details', job_id: job.id });
        for(const s of (jobDetails.steps || [])){
          const subStepId = `sub_${s.name}`;
          if(!dynamicSteps.has(s.name)) dynamicSteps.set(s.name, makeStep(subStepId, s.name, {isSubStep: true}));
          setStepAs(subStepId, s.status, s.conclusion);
        }
      }
      if (conclusion !== 'success') throw new Error(`Workflow failed with conclusion: ${conclusion}.`);
      setStepAs(activeStepId, 'completed', 'success');
      
      activeStepId = 'output';
      makeStep(activeStepId, 'Checking for output');
      setStepAs(activeStepId, 'in_progress');
      delay = 10000;
      let outputFound = false;
      for(let i=0;i<30;i++){
        setStepStatus(activeStepId, `waiting... (attempt ${i+1}, delay ${delay/1000}s)`);
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
        setStepAs(activeStepId, 'completed', 'success');
        setBadge('Success', 'ok');
      } else {
        throw new Error("Output not found after 30 attempts.");
      }

    } catch (err) {
      console.error(err);
      setBadge('Error', 'err');
      if (activeStepId && stepRegistry.has(activeStepId)) {
        setStepAs(activeStepId, 'completed', 'failure');
        setStepStatus(activeStepId, err.message);
      }
    } finally {
      startBtn.disabled = false;
    }
  });
})();