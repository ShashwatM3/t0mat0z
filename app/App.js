import { StatusBar } from 'expo-status-bar';
import { useEffect, useMemo, useState } from 'react';
import { Image, Pressable, ScrollView, StyleSheet, Text, TextInput, useWindowDimensions, View } from 'react-native';

const colors = {
  paper: '#f3efe6',
  paperWarm: '#fffaf0',
  panel: '#fffdf7',
  ink: '#1f2321',
  mutedInk: '#665f55',
  rule: '#c8bead',
  ruleDark: '#958977',
  burgundy: '#6d1827',
  burgundyDark: '#481019',
  ochre: '#a86f25',
  ochreSoft: '#f2ddba',
  fieldGreen: '#365b43',
  fieldGreenSoft: '#e2eadf',
  asphalt: '#2e3333',
  asphaltSoft: '#e4e1d9',
  danger: '#8f2130',
};

const fixtures = [
  {
    id: 'zone-a-baseline',
    zone: 'Zone A',
    crop: 'tomato',
    station: 'Healthy baseline plant',
    workerNote: 'leaves look normal',
    possibleDisease: 'no visible disease concern',
    confidence: 'high',
    evidenceQuality: 'baseline view is sufficient',
    limitationFlags: ['healthy_baseline'],
    nextCheck: 'No follow-up view needed. Use as comparison for nearby plants.',
    reviewStatus: 'clear',
    supervisorAction: 'No action. Keep as healthy comparison record.',
    packetColor: colors.fieldGreen,
    plantVisual: 'healthy',
    findingWhy:
      'Leaves are evenly green with no visible lesions, yellow halos, curled edges, or clustered spots in the captured view.',
  },
  {
    id: 'zone-b-suspicious',
    zone: 'Zone B',
    crop: 'tomato',
    station: 'Suspicious lower-leaf plant',
    workerNote: 'yellowing and spots on lower leaves',
    possibleDisease: 'possible early blight or leaf spot',
    confidence: 'medium',
    evidenceQuality: 'missing underside view and nearby healthy comparison plant',
    limitationFlags: ['single_view_only', 'underside_missing', 'no_healthy_comparison'],
    nextCheck: 'Capture underside of the affected leaf and one neighboring healthy plant.',
    reviewStatus: 'supervisor_review',
    supervisorAction: 'Supervisor should review evidence before treatment or removal decisions.',
    packetColor: colors.ochre,
    plantVisual: 'suspicious',
    findingWhy:
      'The first image shows lower-leaf yellowing and clustered dark spots. That pattern can be disease-like, but one view is not enough to separate disease from stress or damage.',
  },
  {
    id: 'zone-c-uncertain',
    zone: 'Zone C',
    crop: 'tomato',
    station: 'Ambiguous poor-evidence plant',
    workerNote: 'I see damage but the view is not clear',
    possibleDisease: 'not enough evidence to identify',
    confidence: 'low',
    evidenceQuality: 'image is too far away and symptom context is incomplete',
    limitationFlags: ['too_far', 'blurred', 'single_view_only'],
    nextCheck: 'Move closer, steady the view, and capture the affected leaf plus a nearby normal leaf.',
    reviewStatus: 'recapture_needed',
    supervisorAction: 'Do not escalate as disease yet. Ask worker for clearer evidence.',
    packetColor: colors.danger,
    plantVisual: 'ambiguous',
    findingWhy:
      'The captured view does not show the lesion pattern clearly. A responsible scout workflow should ask for better evidence instead of inventing a diagnosis.',
  },
];

const initialStatuses = {
  'Zone A': 'unscouted',
  'Zone B': 'unscouted',
  'Zone C': 'unscouted',
};

const MODEL_API_PATH = '/api/scout/analyze';
const CONFIGURED_MODEL_API_URL =
  typeof process !== 'undefined' && process.env?.EXPO_PUBLIC_DISEASE_SCOUT_API_URL
    ? process.env.EXPO_PUBLIC_DISEASE_SCOUT_API_URL
    : '';

function inferModelApiUrl() {
  if (CONFIGURED_MODEL_API_URL) return CONFIGURED_MODEL_API_URL;
  if (typeof window !== 'undefined' && window.location?.hostname) {
    const protocol = window.location.protocol === 'https:' ? 'https:' : 'http:';
    return `${protocol}//${window.location.hostname}:8787${MODEL_API_PATH}`;
  }
  return `http://localhost:8787${MODEL_API_PATH}`;
}

const MODEL_API_URL = inferModelApiUrl();
const DEFERRED_QUEUE_KEY = 'diseaseScoutDeferredQueue:v1';

function readDeferredQueue() {
  if (typeof window === 'undefined' || !window.localStorage) return [];
  try {
    const parsed = JSON.parse(window.localStorage.getItem(DEFERRED_QUEUE_KEY) || '[]');
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeDeferredQueue(records) {
  if (typeof window === 'undefined' || !window.localStorage) return;
  window.localStorage.setItem(DEFERRED_QUEUE_KEY, JSON.stringify(records.slice(0, 12)));
}

function PlantVisual({ type }) {
  const leaves = {
    healthy: [
      { top: 18, left: 58, width: 78, height: 34, rotate: '-18deg', color: '#3f9b5f' },
      { top: 55, left: 120, width: 84, height: 36, rotate: '18deg', color: '#2f855a' },
      { top: 97, left: 70, width: 88, height: 38, rotate: '-8deg', color: '#46a36a' },
    ],
    suspicious: [
      { top: 18, left: 58, width: 78, height: 34, rotate: '-18deg', color: '#5f8f45' },
      { top: 58, left: 120, width: 84, height: 36, rotate: '18deg', color: '#a3a047' },
      { top: 99, left: 70, width: 88, height: 38, rotate: '-8deg', color: '#b7791f' },
    ],
    ambiguous: [
      { top: 22, left: 50, width: 86, height: 36, rotate: '-20deg', color: '#687076' },
      { top: 60, left: 122, width: 76, height: 34, rotate: '21deg', color: '#8b8f5a' },
      { top: 98, left: 64, width: 92, height: 36, rotate: '-8deg', color: '#6f7b62' },
    ],
  };

  const spots = type === 'suspicious'
    ? [
        { top: 66, left: 152 },
        { top: 75, left: 176 },
        { top: 110, left: 92 },
        { top: 121, left: 118 },
      ]
    : type === 'ambiguous'
      ? [
          { top: 76, left: 154 },
          { top: 116, left: 102 },
        ]
      : [];

  return (
    <View style={styles.plantFrame}>
      <View style={styles.stem} />
      {leaves[type].map((leaf, index) => (
        <View
          key={`${type}-${index}`}
          style={[
            styles.leaf,
            {
              top: leaf.top,
              left: leaf.left,
              width: leaf.width,
              height: leaf.height,
              backgroundColor: leaf.color,
              transform: [{ rotate: leaf.rotate }],
            },
          ]}
        />
      ))}
      {spots.map((spot, index) => (
        <View key={`spot-${index}`} style={[styles.spot, { top: spot.top, left: spot.left }]} />
      ))}
      {type === 'ambiguous' ? <View style={styles.blurBand} /> : null}
    </View>
  );
}

function StepPill({ active, done, label }) {
  return (
    <View style={[styles.stepPill, done && styles.stepDone, active && styles.stepActive]}>
      <Text style={[styles.stepText, (active || done) && styles.stepTextActive]}>{label}</Text>
    </View>
  );
}

function ActionButton({ disabled, label, onPress, variant = 'primary' }) {
  return (
    <Pressable
      disabled={disabled}
      onPress={onPress}
      style={({ pressed }) => [
        styles.button,
        variant === 'secondary' && styles.secondaryButton,
        variant === 'danger' && styles.dangerButton,
        disabled && styles.disabledButton,
        pressed && !disabled && styles.pressedButton,
      ]}
    >
      <Text style={[styles.buttonText, variant === 'secondary' && styles.secondaryButtonText]}>
        {label}
      </Text>
    </Pressable>
  );
}

function statusLabel(value) {
  if (value === 'clear') return 'clear';
  if (value === 'supervisor_review') return 'review';
  if (value === 'recapture_needed') return 'recapture';
  return 'unscouted';
}

function assessmentStatusLabel(stage, reviewStatus) {
  if (stage === 'ready') return 'Waiting for capture';
  if (stage === 'packet') return statusLabel(reviewStatus);
  return 'Draft assessment';
}

function packetColorForStatus(reviewStatus) {
  if (reviewStatus === 'clear') return colors.fieldGreen;
  if (reviewStatus === 'recapture_needed') return colors.danger;
  if (reviewStatus === 'supervisor_review') return colors.ochre;
  return colors.ruleDark;
}

function humanFlag(flag) {
  const labels = {
    healthy_baseline: 'Healthy baseline',
    single_view_only: 'Single view only',
    underside_missing: 'Underside missing',
    no_healthy_comparison: 'No healthy comparison',
    too_far: 'Too far',
    blurred: 'Blurred',
  };

  return labels[flag] ?? flag.replaceAll('_', ' ');
}

function VerificationRow({ check }) {
  return (
    <View style={styles.verifyRow}>
      <Text style={[styles.verifyMark, check.pass ? styles.verifyPass : styles.verifyWait]}>
        {check.pass ? 'pass' : 'wait'}
      </Text>
      <View style={styles.verifyTextBlock}>
        <Text style={styles.verifyName}>{check.name}</Text>
        <Text style={styles.verifyDetail}>{check.detail}</Text>
      </View>
    </View>
  );
}

function RecordRow({ label, value, muted = false }) {
  return (
    <View style={styles.recordRow}>
      <Text style={styles.recordLabel}>{label}</Text>
      <Text style={[styles.recordValue, muted && styles.recordValueMuted]}>{value}</Text>
    </View>
  );
}

export default function App() {
  const { width: viewportWidth } = useWindowDimensions();
  const [selectedId, setSelectedId] = useState(fixtures[1].id);
  const [stage, setStage] = useState('ready');
  const [statuses, setStatuses] = useState(initialStatuses);
  const [history, setHistory] = useState([]);
  const [reportText, setReportText] = useState(fixtures[1].workerNote);
  const [uploadedImage, setUploadedImage] = useState(null);
  const [modelObservation, setModelObservation] = useState(null);
  const [modelStatus, setModelStatus] = useState('idle');
  const [modelError, setModelError] = useState(null);
  const [deferredRecords, setDeferredRecords] = useState(readDeferredQueue);

  const selected = fixtures.find((fixture) => fixture.id === selectedId) ?? fixtures[1];
  const operatorReport = reportText.trim();
  const evidenceSource = uploadedImage ? 'web_upload' : 'web_simulator_dat_like_capture';
  const retryableRecord = deferredRecords.find((record) => ['needs_connectivity', 'failed'].includes(record.queue_status));
  const isCompact = viewportWidth < 760;
  const isDesktop = viewportWidth >= 1180;
  const panelLayoutStyle = {
    flexBasis: isDesktop ? '31.5%' : isCompact ? '100%' : '48%',
    maxWidth: isDesktop ? '32%' : '100%',
  };
  const widePanelLayoutStyle = {
    flexBasis: isDesktop ? '64%' : '100%',
    maxWidth: isDesktop ? '65%' : '100%',
  };
  const panelStyle = [styles.panel, panelLayoutStyle];

  useEffect(() => {
    writeDeferredQueue(deferredRecords);
  }, [deferredRecords]);

  const observation = useMemo(() => {
    const hasCapture = stage !== 'ready';
    const hasPacket = stage === 'packet';
    const useFixture = !uploadedImage;
    const modelPending = uploadedImage && hasCapture && !modelObservation;
    const limitationFlags = modelObservation?.limitation_flags
      ?? (useFixture && hasCapture ? selected.limitationFlags : modelPending ? ['model_uncertain'] : []);
    const reviewStatus = modelObservation?.review_status
      ?? (useFixture ? selected.reviewStatus : 'recapture_needed');

    return {
      observation_id: `${selected.zone.toLowerCase().replace(' ', '-')}-${selected.id}`,
      worker_id: 'worker-07',
      crop: selected.crop,
      zone: selected.zone,
      image_uri: hasCapture
        ? uploadedImage
          ? `web-upload://${uploadedImage.name}`
          : `simulator://${selected.id}/pov-capture.jpg`
        : null,
      capture_source: hasCapture ? evidenceSource : 'not_captured',
      upload_filename: hasCapture && uploadedImage ? uploadedImage.name : null,
      upload_size_bytes: hasCapture && uploadedImage ? uploadedImage.size : null,
      upload_mime_type: hasCapture && uploadedImage ? uploadedImage.type : null,
      report_channel: 'typed_report_voice_stand_in',
      wearer_note: stage === 'ready' ? null : operatorReport,
      possible_disease: stage === 'ready'
        ? null
        : modelObservation?.possible_disease ?? (useFixture ? selected.possibleDisease : null),
      confidence: stage === 'ready'
        ? null
        : modelObservation?.confidence ?? (useFixture ? selected.confidence : null),
      limitation_flags: stage === 'ready' ? [] : limitationFlags,
      evidence_quality: stage === 'ready'
        ? null
        : modelObservation?.evidence_quality ?? (useFixture ? selected.evidenceQuality : 'Waiting for image model result'),
      next_check: stage === 'ready'
        ? null
        : modelObservation?.next_check ?? (useFixture ? selected.nextCheck : 'Run image analysis before assigning follow-up.'),
      supervisor_action: hasPacket
        ? modelObservation?.supervisor_action ?? (useFixture ? selected.supervisorAction : 'Request model analysis or supervisor review before action.')
        : 'pending',
      review_status: hasPacket ? reviewStatus : 'draft',
      treatment_recommendation: null,
      finding_why: modelObservation?.finding_why ?? (useFixture ? selected.findingWhy : null),
      broad_state: modelObservation?.broad_state ?? null,
      visible_symptoms: modelObservation?.visible_symptoms ?? [],
      send_status: 'not_sent_demo_only',
      analysis_source: modelObservation ? 'openai_responses_vision' : useFixture ? 'fixture_simulator' : 'awaiting_model',
      model_name: modelObservation?.model_name ?? null,
      model_latency_ms: modelObservation?.model_latency_ms ?? null,
    };
  }, [evidenceSource, modelObservation, operatorReport, selected, stage, uploadedImage]);

  const verificationChecks = useMemo(() => {
    const hasCapture = stage !== 'ready';
    const hasPacket = stage === 'packet';
    const validReviewStatus = ['clear', 'supervisor_review', 'recapture_needed'].includes(observation.review_status);

    return [
      {
        name: 'Evidence captured',
        pass: Boolean(observation.image_uri && observation.capture_source !== 'not_captured'),
        detail: hasCapture ? observation.capture_source : 'waiting for capture',
      },
      {
        name: 'Operator context present',
        pass: Boolean(observation.worker_id && observation.crop && observation.zone),
        detail: `${observation.worker_id} / ${observation.crop} / ${observation.zone}`,
      },
      {
        name: 'Report captured',
        pass: Boolean(hasCapture && observation.wearer_note),
        detail: observation.wearer_note ?? 'typed report required before capture',
      },
      {
        name: 'Uncertainty visible',
        pass: Boolean(observation.possible_disease && observation.confidence),
        detail: hasCapture ? `${observation.confidence} confidence` : 'waiting for ID',
      },
      {
        name: 'Limitations named',
        pass: observation.limitation_flags.length > 0,
        detail: observation.limitation_flags.length > 0 ? observation.limitation_flags.join(', ') : 'none yet',
      },
      {
        name: 'Next check exists',
        pass: Boolean(observation.next_check),
        detail: observation.next_check ?? 'waiting for analysis',
      },
      {
        name: 'No treatment advice',
        pass: observation.treatment_recommendation === null,
        detail: 'diagnosis/treatment intentionally blocked',
      },
      {
        name: 'Review status safe',
        pass: hasPacket && validReviewStatus,
        detail: hasPacket ? observation.review_status : 'packet not created yet',
      },
      {
        name: 'Supervisor packet ready',
        pass: hasPacket && observation.supervisor_action !== 'pending',
        detail: hasPacket ? observation.supervisor_action : 'waiting for packet',
      },
    ];
  }, [observation, stage]);

  const verificationPassed = verificationChecks.filter((check) => check.pass).length;

  const resetForFixture = (id) => {
    const next = fixtures.find((fixture) => fixture.id === id);
    setSelectedId(id);
    setStage('ready');
    setReportText(next?.workerNote ?? '');
    setUploadedImage(null);
    setModelObservation(null);
    setModelStatus('idle');
    setModelError(null);
  };

  const uploadEvidence = (event) => {
    const file = event?.target?.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      setUploadedImage({
        name: file.name,
        size: file.size,
        type: file.type || 'image/*',
        uri: reader.result,
      });
      setStage('ready');
      setModelObservation(null);
      setModelStatus('idle');
      setModelError(null);
      setHistory((items) => [
        `Uploaded evidence image "${file.name}" for ${selected.zone}.`,
        ...items,
      ]);
    };
    reader.readAsDataURL(file);
  };

  const clearUploadedImage = () => {
    setUploadedImage(null);
    setStage('ready');
    setModelObservation(null);
    setModelStatus('idle');
    setModelError(null);
    setHistory((items) => [
      'Cleared uploaded evidence image. Simulator fixture image is active.',
      ...items,
    ]);
  };

  const buildAnalyzePayload = () => ({
    observation_id: `${selected.zone.toLowerCase().replace(' ', '-')}-${selected.id}`,
    worker_id: 'worker-07',
    crop: selected.crop,
    zone: selected.zone,
    capture_source: 'web_upload',
    upload_filename: uploadedImage.name,
    upload_size_bytes: uploadedImage.size,
    upload_mime_type: uploadedImage.type,
    report_channel: 'typed_report_voice_stand_in',
    wearer_note: operatorReport,
    image_data_url: uploadedImage.uri,
  });

  const queueDeferredAnalysis = (payload, errorMessage) => {
    const record = {
      queue_id: `queued-${Date.now()}`,
      fixture_id: selected.id,
      observation_id: payload.observation_id,
      crop: payload.crop,
      zone: payload.zone,
      upload_filename: payload.upload_filename,
      upload_size_bytes: payload.upload_size_bytes,
      upload_mime_type: payload.upload_mime_type,
      image_data_url: payload.image_data_url,
      wearer_note: payload.wearer_note,
      local_created_at: new Date().toISOString(),
      queue_status: 'needs_connectivity',
      provider_attempts: 1,
      last_error: errorMessage,
      next_retry_at: new Date(Date.now() + 60_000).toISOString(),
    };

    setDeferredRecords((records) => [
      record,
      ...records.filter((item) => item.observation_id !== record.observation_id),
    ].slice(0, 12));
  };

  const capture = () => {
    setStage('captured');
    setModelObservation(null);
    setModelStatus('idle');
    setModelError(null);
    setHistory((items) => [
      `Captured ${uploadedImage ? 'uploaded' : 'simulated POV'} evidence for ${selected.zone}. Operator report: "${operatorReport}".`,
      ...items,
    ]);
  };

  const identify = async () => {
    if (!uploadedImage) {
      setStage('identified');
      setHistory((items) => [
        `Worker asked: "What disease might this be?" Fixture result: ${selected.possibleDisease}, ${selected.confidence} confidence.`,
        ...items,
      ]);
      return;
    }

    setModelStatus('running');
    setModelError(null);
    setHistory((items) => [
      `Worker asked: "What disease might this be?" Sending uploaded image to vision model.`,
      ...items,
    ]);

    try {
      const analyzePayload = buildAnalyzePayload();
      const response = await fetch(MODEL_API_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(analyzePayload),
      });
      const payload = await response.json().catch(() => ({}));
      if (!response.ok) {
        throw new Error(payload.error || `Model server returned ${response.status}`);
      }

      setModelObservation(payload.observation);
      setModelStatus('done');
      setStage('identified');
      setDeferredRecords((records) => records.filter((item) => item.observation_id !== payload.observation.observation_id));
      setHistory((items) => [
        `Vision model result: ${payload.observation.possible_disease}, ${payload.observation.confidence} confidence.`,
        ...items,
      ]);
    } catch (error) {
      setModelStatus('error');
      setModelError(error.message);
      setStage('captured');
      queueDeferredAnalysis(buildAnalyzePayload(), error.message);
      setHistory((items) => [
        `Vision model failed: ${error.message}. Capture was queued locally for retry.`,
        ...items,
      ]);
    }
  };

  const retryDeferredAnalysis = async () => {
    if (!retryableRecord) return;

    setSelectedId(retryableRecord.fixture_id);
    setReportText(retryableRecord.wearer_note || '');
    setUploadedImage({
      name: retryableRecord.upload_filename,
      size: retryableRecord.upload_size_bytes,
      type: retryableRecord.upload_mime_type,
      uri: retryableRecord.image_data_url,
    });
    setStage('captured');
    setModelStatus('running');
    setModelError(null);
    setDeferredRecords((records) => records.map((record) => (
      record.queue_id === retryableRecord.queue_id
        ? { ...record, queue_status: 'processing', provider_attempts: record.provider_attempts + 1 }
        : record
    )));

    try {
      const response = await fetch(MODEL_API_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          observation_id: retryableRecord.observation_id,
          worker_id: 'worker-07',
          crop: retryableRecord.crop,
          zone: retryableRecord.zone,
          capture_source: 'web_upload',
          upload_filename: retryableRecord.upload_filename,
          upload_size_bytes: retryableRecord.upload_size_bytes,
          upload_mime_type: retryableRecord.upload_mime_type,
          report_channel: 'typed_report_voice_stand_in',
          wearer_note: retryableRecord.wearer_note,
          image_data_url: retryableRecord.image_data_url,
        }),
      });
      const payload = await response.json().catch(() => ({}));
      if (!response.ok) {
        throw new Error(payload.error || `Model server returned ${response.status}`);
      }

      setModelObservation(payload.observation);
      setModelStatus('done');
      setStage('identified');
      setDeferredRecords((records) => records.map((record) => (
        record.queue_id === retryableRecord.queue_id
          ? { ...record, queue_status: 'done', last_error: null, completed_at: new Date().toISOString() }
          : record
      )));
      setHistory((items) => [
        `Queued capture processed: ${payload.observation.possible_disease}, ${payload.observation.confidence} confidence.`,
        ...items,
      ]);
    } catch (error) {
      setModelStatus('error');
      setModelError(error.message);
      setStage('captured');
      setDeferredRecords((records) => records.map((record) => (
        record.queue_id === retryableRecord.queue_id
          ? {
              ...record,
              queue_status: 'failed',
              last_error: error.message,
              next_retry_at: new Date(Date.now() + 60_000).toISOString(),
            }
          : record
      )));
      setHistory((items) => [
        `Queued capture retry failed: ${error.message}`,
        ...items,
      ]);
    }
  };

  const askWhy = () => {
    setStage('explained');
    setHistory((items) => [
      `Worker asked why. System returned short evidence and one next check for ${selected.zone}.`,
      ...items,
    ]);
  };

  const sendPacket = () => {
    setStage('packet');
    setStatuses((current) => ({
      ...current,
      [selected.zone]: observation.review_status === 'draft' ? 'supervisor_review' : observation.review_status,
    }));
    setHistory((items) => [
      `Supervisor packet created for ${selected.zone}. External sends are disabled in this demo.`,
      ...items,
    ]);
  };

  const clearRun = () => {
    setStage('ready');
    setStatuses(initialStatuses);
    setHistory([]);
    setReportText(selected.workerNote);
    setUploadedImage(null);
    setModelObservation(null);
    setModelStatus('idle');
    setModelError(null);
  };

  return (
    <View style={styles.app}>
      <StatusBar style="dark" />
      <ScrollView contentContainerStyle={styles.page}>
        <View style={styles.header}>
          <View>
            <Text style={styles.kicker}>Disease Scout Memory</Text>
            <Text style={styles.title}>Field evidence memory</Text>
            <Text style={styles.subtitle}>Plant disease scouting simulator</Text>
          </View>
          <View style={styles.headerBadge}>
            <Text style={styles.headerBadgeText}>Operator proof mode</Text>
          </View>
        </View>

        <View style={styles.flowRow}>
          <StepPill label="camera trigger" active={stage === 'ready'} done={stage !== 'ready'} />
          <StepPill label="possible ID" active={stage === 'captured'} done={['identified', 'explained', 'packet'].includes(stage)} />
          <StepPill label="ask why" active={stage === 'identified'} done={['explained', 'packet'].includes(stage)} />
          <StepPill label="review packet" active={stage === 'explained'} done={stage === 'packet'} />
        </View>

        <View style={styles.grid}>
          <View style={panelStyle}>
            <Text style={styles.panelTitle}>Plant stations</Text>
            <Text style={styles.panelHint}>Use real plants or greenhouse samples. The simulator treats each station as a deterministic fixture.</Text>
            {fixtures.map((fixture) => (
              <Pressable
                key={fixture.id}
                onPress={() => resetForFixture(fixture.id)}
                style={[
                  styles.fixtureButton,
                  selected.id === fixture.id && styles.fixtureButtonActive,
                ]}
              >
                <Text style={styles.fixtureZone}>{fixture.zone}</Text>
                <Text style={styles.fixtureName}>{fixture.station}</Text>
                <Text style={styles.fixtureNote}>{fixture.workerNote}</Text>
              </Pressable>
            ))}
            <ActionButton label="Reset demo run" onPress={clearRun} variant="secondary" />
          </View>

          <View style={panelStyle}>
            <Text style={styles.panelTitle}>Glasses view</Text>
            <View style={styles.cameraMeta}>
              <Text style={styles.cameraMetaText}>Selected: {selected.zone}</Text>
              <Text style={styles.cameraMetaText}>Source: {uploadedImage ? 'upload' : 'simulator'}</Text>
            </View>
            {uploadedImage ? (
              <View style={styles.uploadFrame}>
                <Image source={{ uri: uploadedImage.uri }} style={styles.uploadPreview} resizeMode="cover" />
                <View style={styles.uploadBadge}>
                  <Text style={styles.uploadBadgeText}>{uploadedImage.name}</Text>
                </View>
              </View>
            ) : (
              <PlantVisual type={selected.plantVisual} />
            )}
            <View style={styles.commandBox}>
              <Text style={styles.commandTitle}>Evidence image</Text>
              {typeof document !== 'undefined' ? (
                <input
                  accept="image/*"
                  onChange={uploadEvidence}
                  style={{
                    color: colors.asphalt,
                    fontSize: 13,
                    width: '100%',
                  }}
                  type="file"
                />
              ) : (
                <Text style={styles.commandText}>Image upload is available in web mode.</Text>
              )}
              <Text style={styles.reportMeta}>
                {uploadedImage ? `${uploadedImage.type} / ${Math.round(uploadedImage.size / 1024)} KB` : 'No upload selected'}
              </Text>
              {uploadedImage ? (
                <ActionButton label="Clear upload" onPress={clearUploadedImage} variant="secondary" />
              ) : null}
            </View>
            <View style={styles.commandBox}>
              <Text style={styles.commandTitle}>Operator report</Text>
              <TextInput
                multiline
                onChangeText={setReportText}
                placeholder="Type the worker report..."
                placeholderTextColor={colors.ruleDark}
                style={styles.reportInput}
                value={reportText}
              />
              <Text style={styles.reportMeta}>Channel: typed report / voice stand-in</Text>
            </View>
            <View style={styles.commandBox}>
              <Text style={styles.commandTitle}>Scout conversation</Text>
              <Text style={styles.commandText}>1. Active glasses session captures the worker POV</Text>
              <Text style={styles.commandText}>2. "What disease might this be?" calls the local vision backend</Text>
              <Text style={styles.commandText}>3. "Why?"</Text>
              <Text style={styles.reportMeta}>Model: {modelObservation?.model_name ?? 'vision proxy on configured host'}</Text>
              {modelStatus === 'running' ? (
                <Text style={styles.commandCaution}>Analyzing uploaded image...</Text>
              ) : null}
              {modelError ? (
                <Text style={styles.commandCaution}>{modelError}</Text>
              ) : null}
              <Text style={styles.commandCaution}>Camera-button auto-launch remains a device test, not a claim.</Text>
            </View>
            <View style={styles.commandBox}>
              <Text style={styles.commandTitle}>Deferred processing</Text>
              <Text style={styles.commandText}>
                {deferredRecords.length === 0
                  ? 'No queued captures. Uploaded evidence will be saved locally if analysis is unavailable.'
                  : `${deferredRecords.filter((record) => record.queue_status !== 'done').length} queued capture(s), ${deferredRecords.filter((record) => record.queue_status === 'done').length} completed.`}
              </Text>
              {retryableRecord ? (
                <Text style={styles.commandCaution}>
                  {retryableRecord.queue_status}: {retryableRecord.last_error}
                </Text>
              ) : null}
              <ActionButton
                disabled={!retryableRecord || modelStatus === 'running'}
                label="Retry queued analysis"
                onPress={retryDeferredAnalysis}
                variant="secondary"
              />
            </View>
            <View style={styles.buttonStack}>
              <ActionButton disabled={stage !== 'ready' || !operatorReport} label="Trigger capture" onPress={capture} />
              <ActionButton
                disabled={stage !== 'captured' || modelStatus === 'running'}
                label={modelStatus === 'running' ? 'Analyzing image...' : 'Ask identify disease'}
                onPress={identify}
              />
              <ActionButton disabled={stage !== 'identified'} label="Ask why" onPress={askWhy} />
              <ActionButton disabled={stage !== 'explained'} label="Create supervisor packet" onPress={sendPacket} />
            </View>
          </View>

          <View style={panelStyle}>
            <Text style={styles.panelTitle}>Scout assessment</Text>
            <View
              style={[
                styles.assessmentRecord,
                stage !== 'ready' && {
                  borderLeftColor: packetColorForStatus(observation.review_status),
                  borderLeftWidth: 4,
                },
              ]}
            >
              <Text style={styles.assessmentKicker}>
                {stage === 'ready' ? 'Capture pending' : 'Evidence record'}
              </Text>
              <Text style={styles.assessmentTitle}>
                {stage === 'ready'
                  ? 'Waiting for plant evidence'
                  : observation.possible_disease ?? (modelStatus === 'running' ? 'Analyzing uploaded image' : 'Model result required')}
              </Text>
              <View style={styles.recordRows}>
                <RecordRow
                  label="Confidence"
                  value={stage === 'ready' || !observation.confidence ? 'Not available' : observation.confidence}
                  muted={stage === 'ready' || !observation.confidence}
                />
                <RecordRow
                  label="Status"
                  value={assessmentStatusLabel(stage, observation.review_status)}
                />
                <RecordRow
                  label="Evidence quality"
                  value={stage === 'ready' ? 'No image captured yet' : observation.evidence_quality}
                  muted={stage === 'ready'}
                />
                <RecordRow
                  label="Limitations"
                  value={stage === 'ready'
                    ? 'Waiting for capture'
                    : observation.limitation_flags.length > 0
                      ? observation.limitation_flags.map(humanFlag).join(', ')
                      : 'None named'}
                  muted={stage === 'ready'}
                />
                <RecordRow
                  label="Next check"
                  value={stage === 'ready' ? 'Capture a plant view first' : observation.next_check}
                />
              </View>
              {['explained', 'packet'].includes(stage) && observation.finding_why ? (
                <View style={styles.assessmentInset}>
                  <Text style={styles.assessmentInsetLabel}>Short why</Text>
                  <Text style={styles.assessmentInsetText}>{observation.finding_why}</Text>
                </View>
              ) : null}
            </View>
          </View>

          <View style={panelStyle}>
            <Text style={styles.panelTitle}>Supervisor packet</Text>
            <View style={styles.packet}>
              <Text style={styles.packetTitle}>{stage === 'packet' ? 'Ready for review' : 'Draft packet'}</Text>
              <Text style={styles.packetLine}>worker_id: worker-07</Text>
              <Text style={styles.packetLine}>zone: {selected.zone}</Text>
              <Text style={styles.packetLine}>image: {stage === 'ready' ? '-' : observation.image_uri}</Text>
              <Text style={styles.packetLine}>source: {stage === 'ready' ? '-' : observation.capture_source}</Text>
              <Text style={styles.packetLine}>report: {stage === 'ready' ? '-' : operatorReport}</Text>
              <Text style={styles.packetLine}>channel: typed_report_voice_stand_in</Text>
              <Text style={styles.packetLine}>model: {observation.model_name ?? '-'}</Text>
              <Text style={styles.packetLine}>analysis: {observation.analysis_source}</Text>
              <Text style={styles.packetLine}>action: {stage === 'packet' ? observation.supervisor_action : 'pending'}</Text>
              <Text style={styles.packetLine}>send: disabled until confirmed</Text>
            </View>
            <Text style={styles.panelTitleSmall}>Zone memory</Text>
            <View style={styles.zoneGrid}>
              {Object.keys(statuses).map((zone) => (
                <View key={zone} style={styles.zoneCard}>
                  <Text style={styles.zoneName}>{zone}</Text>
                  <Text style={[styles.zoneStatus, statuses[zone] === 'supervisor_review' && styles.zoneReview, statuses[zone] === 'clear' && styles.zoneClear, statuses[zone] === 'recapture_needed' && styles.zoneRecapture]}>
                    {statusLabel(statuses[zone])}
                  </Text>
                </View>
              ))}
            </View>
          </View>

          <View style={panelStyle}>
            <Text style={styles.panelTitle}>Output verifier</Text>
            <View style={styles.scoreBox}>
              <Text style={styles.scoreValue}>{verificationPassed}/{verificationChecks.length}</Text>
              <Text style={styles.scoreLabel}>contract checks passing</Text>
            </View>
            {verificationChecks.map((check) => (
              <VerificationRow key={check.name} check={check} />
            ))}
          </View>

          <View style={[styles.panel, widePanelLayoutStyle, styles.jsonPanel]}>
            <Text style={styles.panelTitle}>DiseaseScoutObservation JSON</Text>
            <Text style={styles.codeText}>{JSON.stringify(observation, null, 2)}</Text>
          </View>

          <View style={panelStyle}>
            <Text style={styles.panelTitle}>Run log</Text>
            {history.length === 0 ? (
              <Text style={styles.panelHint}>No events yet. Start with the camera trigger.</Text>
            ) : (
              history.map((event, index) => (
                <Text key={`${event}-${index}`} style={styles.logLine}>{event}</Text>
              ))
            )}
          </View>
        </View>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  app: {
    flex: 1,
    backgroundColor: colors.paper,
  },
  page: {
    width: '100%',
    maxWidth: 1440,
    alignSelf: 'center',
    padding: 14,
    gap: 12,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    flexWrap: 'wrap',
    gap: 12,
    backgroundColor: colors.panel,
    borderColor: colors.rule,
    borderWidth: 1,
    borderRadius: 4,
    paddingHorizontal: 14,
    paddingVertical: 10,
    borderLeftColor: colors.burgundy,
    borderLeftWidth: 4,
  },
  kicker: {
    color: colors.ochre,
    fontSize: 11,
    fontWeight: '700',
    textTransform: 'uppercase',
    letterSpacing: 0,
  },
  title: {
    color: colors.ink,
    fontFamily: 'Arial',
    fontSize: 20,
    fontWeight: '800',
    lineHeight: 24,
    letterSpacing: 0,
  },
  subtitle: {
    color: colors.mutedInk,
    fontSize: 13,
    fontWeight: '700',
    lineHeight: 17,
  },
  headerBadge: {
    backgroundColor: colors.asphalt,
    borderColor: colors.asphalt,
    borderWidth: 1,
    paddingHorizontal: 10,
    paddingVertical: 7,
    borderRadius: 3,
  },
  headerBadgeText: {
    color: colors.paperWarm,
    fontSize: 11,
    fontWeight: '700',
    textTransform: 'uppercase',
    letterSpacing: 0,
  },
  flowRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  stepPill: {
    borderColor: colors.rule,
    borderWidth: 1,
    borderRadius: 3,
    paddingHorizontal: 12,
    paddingVertical: 8,
    backgroundColor: colors.panel,
  },
  stepActive: {
    borderColor: colors.burgundy,
    backgroundColor: '#f2d8d6',
  },
  stepDone: {
    borderColor: colors.fieldGreen,
    backgroundColor: colors.fieldGreenSoft,
  },
  stepText: {
    color: colors.mutedInk,
    fontWeight: '700',
    fontSize: 13,
    textTransform: 'uppercase',
    letterSpacing: 0,
  },
  stepTextActive: {
    color: colors.ink,
  },
  grid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 14,
    alignItems: 'flex-start',
  },
  panel: {
    backgroundColor: colors.panel,
    borderColor: colors.rule,
    borderWidth: 1,
    borderRadius: 4,
    padding: 15,
    minWidth: 0,
    flexGrow: 1,
    gap: 10,
  },
  jsonPanel: {
    backgroundColor: colors.panel,
  },
  panelTitle: {
    color: colors.ink,
    fontSize: 18,
    fontWeight: '800',
    letterSpacing: 0,
  },
  panelTitleSmall: {
    color: colors.ink,
    fontSize: 15,
    fontWeight: '800',
    marginTop: 4,
    letterSpacing: 0,
  },
  panelHint: {
    color: colors.mutedInk,
    fontSize: 13,
    lineHeight: 18,
  },
  fixtureButton: {
    borderColor: colors.rule,
    borderWidth: 1,
    borderRadius: 3,
    padding: 12,
    backgroundColor: '#f8f3e8',
  },
  fixtureButtonActive: {
    borderColor: colors.burgundy,
    backgroundColor: '#f3ded7',
  },
  fixtureZone: {
    color: colors.burgundy,
    fontSize: 13,
    fontWeight: '800',
    letterSpacing: 0,
  },
  fixtureName: {
    color: colors.ink,
    fontSize: 15,
    fontWeight: '800',
    marginTop: 2,
  },
  fixtureNote: {
    color: colors.mutedInk,
    fontSize: 13,
    marginTop: 4,
  },
  cameraMeta: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    gap: 8,
  },
  cameraMetaText: {
    color: colors.mutedInk,
    fontSize: 13,
    fontWeight: '700',
  },
  plantFrame: {
    height: 190,
    borderRadius: 3,
    borderWidth: 2,
    borderColor: colors.asphalt,
    backgroundColor: '#dad4c7',
    overflow: 'hidden',
    position: 'relative',
  },
  uploadFrame: {
    height: 190,
    borderRadius: 3,
    borderWidth: 2,
    borderColor: colors.asphalt,
    backgroundColor: '#dad4c7',
    overflow: 'hidden',
    position: 'relative',
  },
  uploadPreview: {
    width: '100%',
    height: '100%',
  },
  uploadBadge: {
    position: 'absolute',
    left: 8,
    right: 8,
    bottom: 8,
    backgroundColor: 'rgba(31,35,33,0.84)',
    borderRadius: 3,
    paddingHorizontal: 8,
    paddingVertical: 5,
  },
  uploadBadgeText: {
    color: colors.panel,
    fontSize: 12,
    fontWeight: '800',
  },
  stem: {
    position: 'absolute',
    top: 25,
    left: 116,
    width: 10,
    height: 150,
    borderRadius: 7,
    backgroundColor: '#557a46',
  },
  leaf: {
    position: 'absolute',
    borderTopLeftRadius: 40,
    borderBottomRightRadius: 40,
    borderTopRightRadius: 16,
    borderBottomLeftRadius: 16,
  },
  spot: {
    position: 'absolute',
    width: 12,
    height: 12,
    borderRadius: 6,
    backgroundColor: '#4a2f1b',
    borderWidth: 2,
    borderColor: '#d6b05f',
  },
  blurBand: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: 'rgba(255,255,255,0.28)',
  },
  commandBox: {
    backgroundColor: '#f4eadb',
    borderRadius: 3,
    padding: 10,
    borderColor: colors.rule,
    borderWidth: 1,
  },
  commandTitle: {
    color: colors.ink,
    fontWeight: '800',
    marginBottom: 4,
    textTransform: 'uppercase',
    letterSpacing: 0,
  },
  commandText: {
    color: colors.mutedInk,
    fontSize: 13,
    lineHeight: 18,
  },
  reportInput: {
    minHeight: 76,
    backgroundColor: colors.panel,
    borderColor: colors.rule,
    borderWidth: 1,
    borderRadius: 3,
    color: colors.ink,
    fontSize: 14,
    lineHeight: 19,
    padding: 10,
    textAlignVertical: 'top',
  },
  reportMeta: {
    color: colors.asphalt,
    fontSize: 12,
    fontWeight: '800',
    marginTop: 6,
    textTransform: 'uppercase',
  },
  commandCaution: {
    color: colors.burgundy,
    fontSize: 12,
    fontWeight: '800',
    lineHeight: 17,
    marginTop: 4,
  },
  buttonStack: {
    gap: 8,
  },
  button: {
    backgroundColor: colors.burgundy,
    borderRadius: 3,
    paddingVertical: 11,
    paddingHorizontal: 12,
    alignItems: 'center',
  },
  secondaryButton: {
    backgroundColor: colors.panel,
    borderColor: colors.ruleDark,
    borderWidth: 1,
  },
  dangerButton: {
    backgroundColor: colors.danger,
  },
  disabledButton: {
    backgroundColor: '#bdb5a7',
    borderColor: '#bdb5a7',
  },
  pressedButton: {
    opacity: 0.82,
  },
  buttonText: {
    color: '#ffffff',
    fontWeight: '800',
  },
  secondaryButtonText: {
    color: colors.asphalt,
  },
  assessmentRecord: {
    backgroundColor: '#f7f1e7',
    borderRadius: 3,
    padding: 12,
    gap: 10,
  },
  assessmentKicker: {
    color: colors.mutedInk,
    fontSize: 12,
    fontWeight: '800',
    textTransform: 'uppercase',
    letterSpacing: 0,
  },
  assessmentTitle: {
    color: colors.ink,
    fontSize: 21,
    lineHeight: 27,
    fontWeight: '800',
  },
  recordRows: {
    borderTopColor: colors.rule,
    borderTopWidth: 1,
  },
  recordRow: {
    flexDirection: 'row',
    gap: 12,
    borderBottomColor: colors.rule,
    borderBottomWidth: 1,
    paddingVertical: 9,
  },
  recordLabel: {
    color: colors.mutedInk,
    fontSize: 12,
    fontWeight: '800',
    lineHeight: 17,
    textTransform: 'uppercase',
    width: 112,
  },
  recordValue: {
    color: colors.asphalt,
    flex: 1,
    fontSize: 14,
    fontWeight: '700',
    lineHeight: 19,
  },
  recordValueMuted: {
    color: colors.mutedInk,
    fontWeight: '600',
  },
  assessmentInset: {
    backgroundColor: '#f4eadb',
    borderColor: colors.rule,
    borderRadius: 3,
    borderWidth: 1,
    padding: 10,
    gap: 4,
  },
  assessmentInsetLabel: {
    color: colors.burgundy,
    fontSize: 12,
    fontWeight: '800',
    textTransform: 'uppercase',
  },
  assessmentInsetText: {
    color: colors.asphalt,
    fontSize: 14,
    lineHeight: 20,
  },
  packet: {
    borderRadius: 3,
    borderWidth: 1,
    borderColor: colors.rule,
    backgroundColor: '#f7f1e7',
    padding: 12,
    gap: 5,
  },
  packetTitle: {
    color: colors.ink,
    fontSize: 16,
    fontWeight: '800',
    marginBottom: 4,
  },
  packetLine: {
    color: colors.asphalt,
    fontSize: 13,
    lineHeight: 18,
  },
  zoneGrid: {
    flexDirection: 'row',
    gap: 8,
  },
  zoneCard: {
    flex: 1,
    borderRadius: 3,
    borderWidth: 1,
    borderColor: colors.rule,
    padding: 10,
    backgroundColor: colors.panel,
  },
  zoneName: {
    color: colors.ink,
    fontWeight: '800',
  },
  zoneStatus: {
    color: colors.mutedInk,
    fontWeight: '800',
    marginTop: 4,
  },
  zoneReview: {
    color: colors.ochre,
  },
  zoneClear: {
    color: colors.fieldGreen,
  },
  zoneRecapture: {
    color: colors.danger,
  },
  scoreBox: {
    backgroundColor: colors.asphalt,
    borderRadius: 3,
    padding: 12,
    gap: 2,
  },
  scoreValue: {
    color: colors.paperWarm,
    fontSize: 26,
    fontWeight: '800',
  },
  scoreLabel: {
    color: '#d6d0c2',
    fontSize: 12,
    fontWeight: '800',
    textTransform: 'uppercase',
  },
  verifyRow: {
    flexDirection: 'row',
    gap: 8,
    borderBottomColor: colors.rule,
    borderBottomWidth: 1,
    paddingVertical: 8,
  },
  verifyMark: {
    width: 42,
    height: 22,
    borderRadius: 3,
    overflow: 'hidden',
    textAlign: 'center',
    textAlignVertical: 'center',
    color: colors.paperWarm,
    fontSize: 11,
    fontWeight: '800',
    textTransform: 'uppercase',
    paddingTop: 3,
  },
  verifyPass: {
    backgroundColor: colors.fieldGreen,
  },
  verifyWait: {
    backgroundColor: colors.ruleDark,
  },
  verifyTextBlock: {
    flex: 1,
    gap: 2,
  },
  verifyName: {
    color: colors.ink,
    fontSize: 13,
    fontWeight: '800',
  },
  verifyDetail: {
    color: colors.mutedInk,
    fontSize: 12,
    lineHeight: 16,
  },
  codeText: {
    color: colors.ink,
    backgroundColor: '#ece5d8',
    borderColor: colors.rule,
    borderWidth: 1,
    borderRadius: 3,
    padding: 10,
    fontFamily: 'monospace',
    fontSize: 12,
    lineHeight: 17,
  },
  logLine: {
    color: colors.asphalt,
    fontSize: 13,
    lineHeight: 18,
    paddingVertical: 6,
    borderBottomColor: colors.rule,
    borderBottomWidth: 1,
  },
});
