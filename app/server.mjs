import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { tmpdir } from 'node:os';
import { readFileSync, writeFileSync, existsSync, mkdtempSync, rmSync } from 'node:fs';
import { join } from 'node:path';

loadDotEnv();

const PORT = Number(process.env.DISEASE_SCOUT_API_PORT || 8787);
const MODEL = process.env.OPENAI_MODEL || 'gpt-4.1-mini';
const CODEX_MODEL = process.env.DISEASE_SCOUT_CODEX_MODEL || 'gpt-5.5';
const CODEX_REASONING_EFFORT = process.env.DISEASE_SCOUT_CODEX_REASONING_EFFORT || 'low';
const MODEL_PROVIDER = process.env.DISEASE_SCOUT_MODEL_PROVIDER || (process.env.OPENAI_API_KEY ? 'openai' : 'codex-cli');
const CODEX_TIMEOUT_MS = Number(process.env.DISEASE_SCOUT_CODEX_TIMEOUT_MS || 180000);

const observationSchema = {
  type: 'object',
  additionalProperties: false,
  required: [
    'possible_disease',
    'confidence',
    'evidence_quality',
    'limitation_flags',
    'next_check',
    'review_status',
    'supervisor_action',
    'finding_why',
    'broad_state',
    'visible_symptoms',
    'treatment_recommendation',
  ],
  properties: {
    possible_disease: {
      type: 'string',
      description: 'A conservative possible ID, or not enough evidence / no visible disease concern.',
    },
    confidence: {
      type: 'string',
      enum: ['high', 'medium', 'low', 'unknown'],
    },
    evidence_quality: {
      type: 'string',
    },
    limitation_flags: {
      type: 'array',
      items: {
        type: 'string',
        enum: [
          'healthy_baseline',
          'single_view_only',
          'underside_missing',
          'no_healthy_comparison',
          'too_far',
          'blurred',
          'lighting_issue',
          'occluded',
          'non_leaf_subject',
          'model_uncertain',
        ],
      },
    },
    next_check: {
      type: 'string',
      description: 'One concrete next evidence capture/check for the field worker.',
    },
    review_status: {
      type: 'string',
      enum: ['clear', 'supervisor_review', 'recapture_needed'],
    },
    supervisor_action: {
      type: 'string',
    },
    finding_why: {
      type: 'string',
      description: 'Short image-grounded reason. No treatment advice.',
    },
    broad_state: {
      type: 'string',
      enum: ['healthy_or_low_concern', 'disease_like', 'stress_or_damage', 'not_enough_evidence'],
    },
    visible_symptoms: {
      type: 'array',
      items: { type: 'string' },
    },
    treatment_recommendation: {
      type: 'null',
    },
  },
};

const server = createServer(async (request, response) => {
  try {
    setCors(response);

    if (request.method === 'OPTIONS') {
      response.writeHead(204);
      response.end();
      return;
    }

    if (request.method === 'GET' && request.url === '/health') {
      sendJson(response, 200, {
        ok: true,
        provider: MODEL_PROVIDER,
        api_model: MODEL,
        codex_model: CODEX_MODEL,
        codex_reasoning_effort: CODEX_REASONING_EFFORT,
        has_api_key: Boolean(process.env.OPENAI_API_KEY),
      });
      return;
    }

    if (request.method !== 'POST' || request.url !== '/api/scout/analyze') {
      sendJson(response, 404, { error: 'not_found' });
      return;
    }

    if (MODEL_PROVIDER === 'openai' && !process.env.OPENAI_API_KEY) {
      sendJson(response, 503, {
        error: 'OPENAI_API_KEY missing. Set it in the app server environment or app/.env; never put it in frontend code.',
      });
      return;
    }

    const body = await readJsonBody(request);
    const startedAt = Date.now();
    validateAnalyzeRequest(body);

    const modelResult = await analyzePlantImage(body);
    const latencyMs = Date.now() - startedAt;
    const reviewStatus = modelResult.review_status || 'supervisor_review';

    sendJson(response, 200, {
      observation: {
        observation_id: body.observation_id,
        worker_id: body.worker_id || 'worker-07',
        crop: body.crop || 'tomato',
        zone: body.zone || 'field-test',
        image_uri: `web-upload://${body.upload_filename || 'uploaded-image'}`,
        capture_source: body.capture_source || 'web_upload',
        upload_filename: body.upload_filename || null,
        upload_size_bytes: body.upload_size_bytes || null,
        upload_mime_type: body.upload_mime_type || null,
        report_channel: body.report_channel || 'typed_report_voice_stand_in',
        wearer_note: body.wearer_note || '',
        possible_disease: modelResult.possible_disease,
        confidence: modelResult.confidence,
        limitation_flags: modelResult.limitation_flags,
        evidence_quality: modelResult.evidence_quality,
        next_check: modelResult.next_check,
        supervisor_action: modelResult.supervisor_action,
        review_status: reviewStatus,
        treatment_recommendation: null,
        finding_why: modelResult.finding_why,
        broad_state: modelResult.broad_state,
        visible_symptoms: modelResult.visible_symptoms,
        send_status: 'not_sent_demo_only',
        analysis_source: modelResult.analysis_source || 'openai_responses_vision',
        model_name: modelResult.model_name || MODEL,
        model_latency_ms: latencyMs,
      },
    });
  } catch (error) {
    sendJson(response, error.statusCode || 500, {
      error: error.message || 'analysis_failed',
    });
  }
});

server.listen(PORT, () => {
  console.log(`Disease Scout AI proxy listening on http://localhost:${PORT}`);
  console.log(`Model: ${MODEL}`);
});

function loadDotEnv() {
  const envPath = join(process.cwd(), '.env');
  if (!existsSync(envPath)) return;

  const lines = readFileSync(envPath, 'utf8').split(/\r?\n/);
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const equalsIndex = trimmed.indexOf('=');
    if (equalsIndex === -1) continue;
    const key = trimmed.slice(0, equalsIndex).trim();
    const rawValue = trimmed.slice(equalsIndex + 1).trim();
    const value = rawValue.replace(/^['"]|['"]$/g, '');
    if (key && !process.env[key]) process.env[key] = value;
  }
}

function setCors(response) {
  response.setHeader('Access-Control-Allow-Origin', '*');
  response.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  response.setHeader('Access-Control-Allow-Headers', 'Content-Type');
}

function sendJson(response, statusCode, payload) {
  response.writeHead(statusCode, { 'Content-Type': 'application/json' });
  response.end(JSON.stringify(payload));
}

function readJsonBody(request) {
  return new Promise((resolve, reject) => {
    let data = '';
    request.on('data', (chunk) => {
      data += chunk;
      if (data.length > 16 * 1024 * 1024) {
        const error = new Error('Request body too large for local demo proxy.');
        error.statusCode = 413;
        reject(error);
        request.destroy();
      }
    });
    request.on('end', () => {
      try {
        resolve(JSON.parse(data || '{}'));
      } catch {
        const error = new Error('Invalid JSON body.');
        error.statusCode = 400;
        reject(error);
      }
    });
    request.on('error', reject);
  });
}

function validateAnalyzeRequest(body) {
  if (!body.image_data_url || typeof body.image_data_url !== 'string') {
    const error = new Error('image_data_url is required.');
    error.statusCode = 400;
    throw error;
  }
  if (!body.image_data_url.startsWith('data:image/')) {
    const error = new Error('image_data_url must be a data:image URL.');
    error.statusCode = 400;
    throw error;
  }
}

async function analyzePlantImage(body) {
  if (MODEL_PROVIDER === 'codex-cli') {
    return analyzeWithCodexCli(body);
  }

  const prompt = [
    'You are Disease Scout Memory for a field scouting demo.',
    'Analyze the uploaded plant/leaf image and the worker note.',
    'Return a conservative scouting observation, not a treatment decision.',
    'Ignore filename and metadata. Use only the image pixels and worker note.',
    'If evidence is weak, say so and request one concrete next check.',
    'Do not recommend chemicals, sprays, removal, or treatment.',
    '',
    `Worker note: ${body.wearer_note || '(none)'}`,
    `Crop: ${body.crop || 'unknown'}`,
    `Zone: ${body.zone || 'unknown'}`,
  ].join('\n');

  const apiResponse = await fetch('https://api.openai.com/v1/responses', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${process.env.OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: MODEL,
      input: [
        {
          role: 'user',
          content: [
            { type: 'input_text', text: prompt },
            {
              type: 'input_image',
              image_url: body.image_data_url,
              detail: 'high',
            },
          ],
        },
      ],
      text: {
        format: {
          type: 'json_schema',
          name: 'disease_scout_observation',
          strict: true,
          schema: observationSchema,
        },
      },
      max_output_tokens: 900,
    }),
  });

  const payload = await apiResponse.json().catch(() => null);
  if (!apiResponse.ok) {
    const error = new Error(payload?.error?.message || `OpenAI request failed with ${apiResponse.status}`);
    error.statusCode = 502;
    throw error;
  }

  const outputText = extractOutputText(payload);
  if (!outputText) {
    const error = new Error('OpenAI response did not include output text.');
    error.statusCode = 502;
    throw error;
  }

  try {
    return {
      ...JSON.parse(outputText),
      analysis_source: 'openai_responses_vision',
      model_name: MODEL,
    };
  } catch {
    const error = new Error('OpenAI response was not valid JSON.');
    error.statusCode = 502;
    throw error;
  }
}

async function analyzeWithCodexCli(body) {
  const tempDir = mkdtempSync(join(tmpdir(), 'disease-scout-codex-'));
  const mime = body.upload_mime_type || 'image/jpeg';
  const ext = mime.includes('png') ? 'png' : mime.includes('webp') ? 'webp' : 'jpg';
  const imagePath = join(tempDir, `capture.${ext}`);
  const schemaPath = join(tempDir, 'schema.json');
  const outputPath = join(tempDir, 'output.json');

  try {
    const base64 = body.image_data_url.split(',')[1];
    if (!base64) {
      const error = new Error('image_data_url is missing base64 data.');
      error.statusCode = 400;
      throw error;
    }

    writeFileSync(imagePath, Buffer.from(base64, 'base64'));
    writeFileSync(schemaPath, JSON.stringify(observationSchema, null, 2));

    const prompt = [
      'You are Disease Scout Memory for a field scouting demo using Meta glasses style POV evidence.',
      'Analyze the attached plant/leaf image and the worker note.',
      'Return only the JSON object required by the output schema.',
      'Be image-grounded and conservative. Do not diagnose beyond visible evidence.',
      'Ignore filename and metadata. Use only image pixels and worker note.',
      'If the image is ambiguous or not a leaf, set confidence low or unknown and ask for recapture.',
      'Never recommend chemical treatment, sprays, removal, or field action beyond evidence capture or supervisor review.',
      '',
      `Worker note: ${body.wearer_note || '(none)'}`,
      `Crop: ${body.crop || 'unknown'}`,
      `Zone: ${body.zone || 'unknown'}`,
    ].join('\n');

    const args = [
      'exec',
      '--ephemeral',
      '--skip-git-repo-check',
      '--ignore-rules',
      '--color',
      'never',
      '--sandbox',
      'read-only',
      '-c',
      `model_reasoning_effort="${CODEX_REASONING_EFFORT}"`,
      '--image',
      imagePath,
      '--output-schema',
      schemaPath,
      '--output-last-message',
      outputPath,
    ];

    args.push('-m', CODEX_MODEL);

    args.push('-');

    await runCodex(args, prompt);

    const outputText = existsSync(outputPath) ? readFileSync(outputPath, 'utf8') : '';
    if (!outputText.trim()) {
      const error = new Error('Codex CLI did not write a model output.');
      error.statusCode = 502;
      throw error;
    }

    return {
      ...parseJsonText(outputText),
      analysis_source: 'codex_cli_subscription_vision',
      model_name: `codex-cli:${CODEX_MODEL}:${CODEX_REASONING_EFFORT}`,
    };
  } finally {
    rmSync(tempDir, { recursive: true, force: true });
  }
}

function runCodex(args, prompt) {
  return new Promise((resolve, reject) => {
    const command = 'codex';
    let settled = false;
    const child = spawn(command, args, {
      cwd: tmpdir(),
      shell: process.platform === 'win32',
      windowsHide: true,
      stdio: ['pipe', 'pipe', 'pipe'],
    });

    let stderr = '';
    child.stdout.on('data', () => {
      // Drain stdout so the child process cannot block on a full pipe.
    });
    child.stderr.on('data', (chunk) => {
      stderr += chunk.toString();
    });

    const timer = setTimeout(() => {
      if (settled) return;
      settled = true;
      child.kill();
      const error = new Error(`Codex CLI timed out after ${CODEX_TIMEOUT_MS}ms.`);
      error.statusCode = 504;
      reject(error);
    }, CODEX_TIMEOUT_MS);

    child.on('error', (error) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      error.statusCode = 502;
      reject(error);
    });

    child.on('close', (code) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      if (code === 0) {
        resolve();
        return;
      }

      const error = new Error(`Codex CLI exited with code ${code}. ${stderr.trim()}`.trim());
      error.statusCode = 502;
      reject(error);
    });

    child.stdin.write(prompt);
    child.stdin.end();
  });
}

function parseJsonText(text) {
  const trimmed = text.trim();
  const fenced = trimmed.match(/^```(?:json)?\s*([\s\S]*?)\s*```$/i);
  const candidate = fenced ? fenced[1] : trimmed;
  return JSON.parse(candidate);
}

function extractOutputText(payload) {
  if (typeof payload?.output_text === 'string') return payload.output_text;

  const chunks = [];
  for (const item of payload?.output || []) {
    for (const content of item.content || []) {
      if (content.type === 'output_text' && typeof content.text === 'string') {
        chunks.push(content.text);
      }
    }
  }
  return chunks.join('').trim();
}
