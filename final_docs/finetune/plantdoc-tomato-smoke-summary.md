# PlantDoc Tomato Finetune Smoke Receipt

- Status: pass
- Local run type: dataset manifest smoke
- Training target: Google Colab T4
- Local GPU training claimed: false
- Selected classes: 8
- Train images: 675
- Test images: 69
- Manifest: `final_docs/finetune/plantdoc-tomato-manifest.jsonl`
- Label map: `final_docs/finetune/plantdoc-tomato-label-map.json`

## Classes

- "Tomato Early blight leaf": train 79, test 9
- "Tomato leaf": train 55, test 8
- "Tomato leaf bacterial spot": train 101, test 9
- "Tomato leaf late blight": train 101, test 10
- "Tomato leaf mosaic virus": train 44, test 10
- "Tomato leaf yellow virus": train 70, test 6
- "Tomato mold leaf": train 85, test 6
- "Tomato Septoria leaf spot": train 140, test 11
