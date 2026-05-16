# Disease Scout Dataset Verifier Report

- Manifest rows: 306
- Prediction rows: 306
- Missing predictions: 0
- Extra predictions: 0

## Scores

| Check | Passed | Total | Rate |
| --- | ---: | ---: | ---: |
| bad_recapture_behavior | 85 | 102 | 83.3% |
| broad_state | 247 | 306 | 80.7% |
| limitations_named | 306 | 306 | 100.0% |
| next_check_exists | 306 | 306 | 100.0% |
| no_treatment_advice | 306 | 306 | 100.0% |
| report_preserved | 306 | 306 | 100.0% |
| safe_review_status | 306 | 306 | 100.0% |
| valid_schema | 306 | 306 | 100.0% |

## Failure Samples

- `holdout-00043-1a460f7033-usable_but_single_view`: {"image_id":"holdout-00043-1a460f7033-usable_but_single_view","bucket":"healthy","capture_quality":"usable_but_single_view","check":"broad_state","review_status":"supervisor_review","possible_disease":"possible disease or stress signal"}
- `holdout-00057-da31586678-usable_but_single_view`: {"image_id":"holdout-00057-da31586678-usable_but_single_view","bucket":"healthy","capture_quality":"usable_but_single_view","check":"broad_state","review_status":"supervisor_review","possible_disease":"possible disease or stress signal"}
- `holdout-00043-1a460f7033-clear`: {"image_id":"holdout-00043-1a460f7033-clear","bucket":"healthy","capture_quality":"clear","check":"broad_state","review_status":"supervisor_review","possible_disease":"possible disease or stress signal"}
- `holdout-00048-d119deb067-usable_but_single_view`: {"image_id":"holdout-00048-d119deb067-usable_but_single_view","bucket":"healthy","capture_quality":"usable_but_single_view","check":"broad_state","review_status":"supervisor_review","possible_disease":"possible disease or stress signal"}
- `holdout-00050-bc0ec6abda-usable_but_single_view`: {"image_id":"holdout-00050-bc0ec6abda-usable_but_single_view","bucket":"healthy","capture_quality":"usable_but_single_view","check":"broad_state","review_status":"supervisor_review","possible_disease":"possible disease or stress signal"}
- `holdout-00023-c693d01fd0-bad_recapture`: {"image_id":"holdout-00023-c693d01fd0-bad_recapture","bucket":"early_blight","capture_quality":"bad_recapture","check":"broad_state","review_status":"supervisor_review","possible_disease":"possible disease or stress signal"}
- `holdout-00023-c693d01fd0-bad_recapture`: {"image_id":"holdout-00023-c693d01fd0-bad_recapture","bucket":"early_blight","capture_quality":"bad_recapture","check":"bad_recapture_behavior","review_status":"supervisor_review","possible_disease":"possible disease or stress signal"}
- `holdout-00040-e990d6c955-clear`: {"image_id":"holdout-00040-e990d6c955-clear","bucket":"healthy","capture_quality":"clear","check":"broad_state","review_status":"supervisor_review","possible_disease":"possible disease or stress signal"}
- `holdout-00053-8f1cab1969-clear`: {"image_id":"holdout-00053-8f1cab1969-clear","bucket":"healthy","capture_quality":"clear","check":"broad_state","review_status":"recapture_needed","possible_disease":"not enough evidence to identify"}
- `holdout-00051-d1b2bfca29-usable_but_single_view`: {"image_id":"holdout-00051-d1b2bfca29-usable_but_single_view","bucket":"healthy","capture_quality":"usable_but_single_view","check":"broad_state","review_status":"supervisor_review","possible_disease":"possible disease or stress signal"}
- `holdout-00059-02b4ea0990-clear`: {"image_id":"holdout-00059-02b4ea0990-clear","bucket":"healthy","capture_quality":"clear","check":"broad_state","review_status":"supervisor_review","possible_disease":"possible disease or stress signal"}
- `holdout-00052-81c48f1873-bad_recapture`: {"image_id":"holdout-00052-81c48f1873-bad_recapture","bucket":"healthy","capture_quality":"bad_recapture","check":"broad_state","review_status":"clear","possible_disease":"no visible disease concern"}
- `holdout-00052-81c48f1873-bad_recapture`: {"image_id":"holdout-00052-81c48f1873-bad_recapture","bucket":"healthy","capture_quality":"bad_recapture","check":"bad_recapture_behavior","review_status":"clear","possible_disease":"no visible disease concern"}
- `holdout-00055-887ceedf22-usable_but_single_view`: {"image_id":"holdout-00055-887ceedf22-usable_but_single_view","bucket":"healthy","capture_quality":"usable_but_single_view","check":"broad_state","review_status":"supervisor_review","possible_disease":"possible disease or stress signal"}
- `holdout-00083-c8ed5863a7-bad_recapture`: {"image_id":"holdout-00083-c8ed5863a7-bad_recapture","bucket":"yellow_leaf_curl_or_mosaic","capture_quality":"bad_recapture","check":"broad_state","review_status":"clear","possible_disease":"no visible disease concern"}
- `holdout-00083-c8ed5863a7-bad_recapture`: {"image_id":"holdout-00083-c8ed5863a7-bad_recapture","bucket":"yellow_leaf_curl_or_mosaic","capture_quality":"bad_recapture","check":"bad_recapture_behavior","review_status":"clear","possible_disease":"no visible disease concern"}
- `holdout-00054-8d84fa7ef2-usable_but_single_view`: {"image_id":"holdout-00054-8d84fa7ef2-usable_but_single_view","bucket":"healthy","capture_quality":"usable_but_single_view","check":"broad_state","review_status":"supervisor_review","possible_disease":"possible disease or stress signal"}
- `holdout-00044-9f0ee97e32-usable_but_single_view`: {"image_id":"holdout-00044-9f0ee97e32-usable_but_single_view","bucket":"healthy","capture_quality":"usable_but_single_view","check":"broad_state","review_status":"supervisor_review","possible_disease":"possible disease or stress signal"}
- `holdout-00082-f3856815a0-bad_recapture`: {"image_id":"holdout-00082-f3856815a0-bad_recapture","bucket":"yellow_leaf_curl_or_mosaic","capture_quality":"bad_recapture","check":"broad_state","review_status":"clear","possible_disease":"no visible disease concern"}
- `holdout-00082-f3856815a0-bad_recapture`: {"image_id":"holdout-00082-f3856815a0-bad_recapture","bucket":"yellow_leaf_curl_or_mosaic","capture_quality":"bad_recapture","check":"bad_recapture_behavior","review_status":"clear","possible_disease":"no visible disease concern"}
- `holdout-00054-8d84fa7ef2-clear`: {"image_id":"holdout-00054-8d84fa7ef2-clear","bucket":"healthy","capture_quality":"clear","check":"broad_state","review_status":"supervisor_review","possible_disease":"possible disease or stress signal"}
- `holdout-00046-1c73f9e07e-usable_but_single_view`: {"image_id":"holdout-00046-1c73f9e07e-usable_but_single_view","bucket":"healthy","capture_quality":"usable_but_single_view","check":"broad_state","review_status":"supervisor_review","possible_disease":"possible disease or stress signal"}
- `holdout-00011-b65cd0980d-bad_recapture`: {"image_id":"holdout-00011-b65cd0980d-bad_recapture","bucket":"bacterial_or_leaf_spot","capture_quality":"bad_recapture","check":"broad_state","review_status":"clear","possible_disease":"no visible disease concern"}
- `holdout-00011-b65cd0980d-bad_recapture`: {"image_id":"holdout-00011-b65cd0980d-bad_recapture","bucket":"bacterial_or_leaf_spot","capture_quality":"bad_recapture","check":"bad_recapture_behavior","review_status":"clear","possible_disease":"no visible disease concern"}
- `holdout-00045-85ac7dbc49-usable_but_single_view`: {"image_id":"holdout-00045-85ac7dbc49-usable_but_single_view","bucket":"healthy","capture_quality":"usable_but_single_view","check":"broad_state","review_status":"supervisor_review","possible_disease":"possible disease or stress signal"}
- `holdout-00053-8f1cab1969-usable_but_single_view`: {"image_id":"holdout-00053-8f1cab1969-usable_but_single_view","bucket":"healthy","capture_quality":"usable_but_single_view","check":"broad_state","review_status":"supervisor_review","possible_disease":"possible disease or stress signal"}
- `holdout-00059-02b4ea0990-usable_but_single_view`: {"image_id":"holdout-00059-02b4ea0990-usable_but_single_view","bucket":"healthy","capture_quality":"usable_but_single_view","check":"broad_state","review_status":"supervisor_review","possible_disease":"possible disease or stress signal"}
- `holdout-00056-5ef0155f9c-clear`: {"image_id":"holdout-00056-5ef0155f9c-clear","bucket":"healthy","capture_quality":"clear","check":"broad_state","review_status":"supervisor_review","possible_disease":"possible disease or stress signal"}
- `holdout-00059-02b4ea0990-bad_recapture`: {"image_id":"holdout-00059-02b4ea0990-bad_recapture","bucket":"healthy","capture_quality":"bad_recapture","check":"broad_state","review_status":"supervisor_review","possible_disease":"possible disease or stress signal"}
- `holdout-00059-02b4ea0990-bad_recapture`: {"image_id":"holdout-00059-02b4ea0990-bad_recapture","bucket":"healthy","capture_quality":"bad_recapture","check":"bad_recapture_behavior","review_status":"supervisor_review","possible_disease":"possible disease or stress signal"}
- `holdout-00062-f6734228a1-usable_but_single_view`: {"image_id":"holdout-00062-f6734228a1-usable_but_single_view","bucket":"late_blight","capture_quality":"usable_but_single_view","check":"broad_state","review_status":"clear","possible_disease":"no visible disease concern"}
- `holdout-00049-9065172ad0-clear`: {"image_id":"holdout-00049-9065172ad0-clear","bucket":"healthy","capture_quality":"clear","check":"broad_state","review_status":"supervisor_review","possible_disease":"possible disease or stress signal"}
- `holdout-00026-283b4d969c-bad_recapture`: {"image_id":"holdout-00026-283b4d969c-bad_recapture","bucket":"early_blight","capture_quality":"bad_recapture","check":"broad_state","review_status":"clear","possible_disease":"no visible disease concern"}
- `holdout-00026-283b4d969c-bad_recapture`: {"image_id":"holdout-00026-283b4d969c-bad_recapture","bucket":"early_blight","capture_quality":"bad_recapture","check":"bad_recapture_behavior","review_status":"clear","possible_disease":"no visible disease concern"}
- `holdout-00046-1c73f9e07e-clear`: {"image_id":"holdout-00046-1c73f9e07e-clear","bucket":"healthy","capture_quality":"clear","check":"broad_state","review_status":"supervisor_review","possible_disease":"possible disease or stress signal"}
- `holdout-00044-9f0ee97e32-clear`: {"image_id":"holdout-00044-9f0ee97e32-clear","bucket":"healthy","capture_quality":"clear","check":"broad_state","review_status":"supervisor_review","possible_disease":"possible disease or stress signal"}
- `holdout-00095-d5a29a3d4e-bad_recapture`: {"image_id":"holdout-00095-d5a29a3d4e-bad_recapture","bucket":"yellow_leaf_curl_or_mosaic","capture_quality":"bad_recapture","check":"broad_state","review_status":"clear","possible_disease":"no visible disease concern"}
- `holdout-00095-d5a29a3d4e-bad_recapture`: {"image_id":"holdout-00095-d5a29a3d4e-bad_recapture","bucket":"yellow_leaf_curl_or_mosaic","capture_quality":"bad_recapture","check":"bad_recapture_behavior","review_status":"clear","possible_disease":"no visible disease concern"}
- `holdout-00101-609f895a48-bad_recapture`: {"image_id":"holdout-00101-609f895a48-bad_recapture","bucket":"yellow_leaf_curl_or_mosaic","capture_quality":"bad_recapture","check":"broad_state","review_status":"clear","possible_disease":"no visible disease concern"}
- `holdout-00101-609f895a48-bad_recapture`: {"image_id":"holdout-00101-609f895a48-bad_recapture","bucket":"yellow_leaf_curl_or_mosaic","capture_quality":"bad_recapture","check":"bad_recapture_behavior","review_status":"clear","possible_disease":"no visible disease concern"}
