# Monitored timing readiness refused

After the combined compiler passed all full local gates, the fresh five-label build passed correctness and source/artifact barriers, and compiler jobs stopped, this prespecified load preflight failed on 2026-10-22 at 14:15 UTC. No timing phase or window started.

The first approximately two-second sample measured 15.20 outside-host core equivalents (limit 0.25) and a maximum outside process of 0.85 core equivalents (limit 0.10); the guest was effectively idle. The monitor refused readiness before the required 120-second quiet preflight. This is evidence of unsuitable measurement conditions, not a compiler performance result. No unrelated process was stopped or modified. Raw process names, PIDs, commands and working directories were neither retained nor published.

The exact frozen protocol, monitor, runner and aggregate result are retained. Their capability to observe this threshold violation was exercised; continuous child-process accounting and a successful complete timing campaign were not qualified by this failed preflight. Operational sampled thresholds would not establish exclusive hardware isolation even if they passed.

`campaign.json` binds the fresh build manifest and preparation hashes; `artifact-manifest.json` binds the original attempt files. The parent publication manifest additionally binds this README. The original noisy windows remain separate withdrawn diagnostics. A later measurement must use a separately labeled campaign, preserve this refusal, and run the full readiness and provenance checks.
