# Disease Scout PlantDoc Tomato Finetune

This package is the smallest proper fine-tune path for the current Disease Scout work.

It uses the PlantDoc dataset already present locally at:

```text
data/raw/PlantDoc-Dataset-master/
```

The actual training target is Google Colab with a T4 GPU. The local machine can still run the smoke script to prove the dataset, label map, and artifact paths are valid.

## What This Trains

Transfer-learning classifier:

```text
PlantDoc tomato image -> MobileNetV2 ImageNet backbone -> tomato disease class + confidence
```

Default included classes exclude `Tomato two spotted spider mites leaf` because the local PlantDoc copy only has 2 train images in that class.

## Local Smoke

From the repo root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\training\disease-finetune\smoke-plantdoc-finetune.ps1
```

Expected outputs:

- `final_docs/finetune/plantdoc-tomato-manifest.jsonl`
- `final_docs/finetune/plantdoc-tomato-label-map.json`
- `final_docs/finetune/plantdoc-tomato-smoke-receipt.json`
- `final_docs/finetune/plantdoc-tomato-smoke-summary.md`

## Colab T4 Run

1. Open the public Colab launch URL:

   ```text
   https://colab.research.google.com/github/ShashwatM3/t0mat0z/blob/colab-t4-finetune/training/disease-finetune/colab_t4_plantdoc_tomato_finetune.ipynb
   ```

2. Set Runtime -> Change runtime type -> T4 GPU.
3. Run the notebook cells.

The notebook clones the public `colab-t4-finetune` branch and downloads PlantDoc directly from the public dataset repository, so no local file upload or Drive mount is required.

The notebook delegates to:

```text
train_colab_t4_plantdoc_tomato.py
```

Expected Colab outputs:

- `disease_scout_tomato_mobilenetv2.keras`
- `label_map.json`
- `metrics.json`
- optional `disease_scout_tomato_mobilenetv2.tflite`

## Demo Integration

This classifier should not replace the Disease Scout safety layer. Use it as one provider behind the existing classifier bridge:

```text
image -> custom model label/confidence -> DiseaseScoutObservation with evidence quality and next check
```

Keep the app language as "possible disease" and "supervisor review"; do not turn classifier confidence into final diagnosis.
