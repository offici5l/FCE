import fetch from "node-fetch";
import { exec } from "child_process";

export default async function handler(req, res) {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    return res.status(200).end();
  }

  if (req.method !== "POST") {
    return res.status(405).json({ ok: false, error: "Method Not Allowed" });
  }

  const {
    action, // 'trigger', 'get_runs', 'get_jobs', 'get_run_details', 'get_job_details', 'check_output'
    url,
    file,
    unique_id,
    run_id,
    job_id,
    output_url,
  } = req.body;

  if (!action) {
    return res.status(400).json({ ok: false, error: "Missing 'action' parameter" });
  }

  const GITHUB_API_BASE = "https://api.github.com/repos/offici5l/FCE";
  const GITHUB_TOKEN = process.env.GITHUB_TOKEN;

  const fetchOptions = {
    headers: {
      Authorization: `Bearer ${GITHUB_TOKEN}`,
      "Content-Type": "application/json",
      "User-Agent": "FCE-Proxy",
    },
  };

  let targetUrl;
  let response;

  try {
    switch (action) {
      case "trigger":
        if (!url || !file || !unique_id) {
          return res.status(400).json({ ok: false, error: "Missing parameters for 'trigger'" });
        }
        targetUrl = `${GITHUB_API_BASE}/actions/workflows/fce.yml/dispatches`;
        response = await fetch(targetUrl, {
          method: "POST",
          headers: fetchOptions.headers,
          body: JSON.stringify({
            ref: "main",
            inputs: { url, file_to_extract: file, unique_id },
          }),
        });
        if (!response.ok) throw new Error(`GitHub API Error: ${await response.text()}`);
        return res.status(200).json({ ok: true });

      case "get_runs":
        targetUrl = `${GITHUB_API_BASE}/actions/workflows/fce.yml/runs?per_page=10`;
        break;

      case "get_jobs":
        if (!run_id) return res.status(400).json({ ok: false, error: "Missing 'run_id'" });
        targetUrl = `${GITHUB_API_BASE}/actions/runs/${run_id}/jobs`;
        break;

      case "get_run_details":
        if (!run_id) return res.status(400).json({ ok: false, error: "Missing 'run_id'" });
        targetUrl = `${GITHUB_API_BASE}/actions/runs/${run_id}`;
        break;
        
      case "get_job_details":
        if (!job_id) return res.status(400).json({ ok: false, error: "Missing 'job_id'" });
        targetUrl = `${GITHUB_API_BASE}/actions/jobs/${job_id}`;
        break;

      case "check_output":
        if (!output_url) {
          return res.status(400).json({ ok: false, error: "Missing 'output_url'" });
        }
        const statusCode = await new Promise((resolve) => {
          const command = `curl -s -o /dev/null -w "%{http_code}" -IL "${output_url}"`;
          exec(command, (error, stdout) => {
            resolve(parseInt(stdout.trim(), 10) || 0);
          });
        });
        return res.status(200).json({ status: statusCode });

      default:
        return res.status(400).json({ ok: false, error: "Invalid action" });
    }

    if (targetUrl) {
      response = await fetch(targetUrl, { headers: fetchOptions.headers });
      const data = await response.json();
      if (!response.ok) throw new Error(`GitHub API Error: ${JSON.stringify(data)}`);
      return res.status(200).json(data);
    }

  } catch (error) {
    return res.status(500).json({ ok: false, error: error.message });
  }
}