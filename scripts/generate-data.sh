#!/bin/bash
# Copyright (c) 2026, The Allen Institute for AI. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Generate RULER benchmark data (no model serving / prediction / eval),
# across every length in SEQ_LENGTHS (config_models.sh) and every task in
# the chosen benchmark's task list (config_tasks.sh), using the (possibly
# per-length-overridden) sample counts from NUM_SAMPLES_OVERRIDE.
#
# Requires `uv` (https://docs.astral.sh/uv/); dependencies are resolved
# automatically into the project's `.venv` on first run.
#
# The essay/QA source corpora used by the niah/qa tasks are fetched
# automatically below on first run (and skipped on later runs once present).
#
# Usage: bash generate-data.sh [output_dir] [benchmark]
# Example: bash generate-data.sh benchmark_root/data synthetic

set -euo pipefail

OUTPUT_DIR=${1:-benchmark_root/data}
BENCHMARK=${2:-synthetic}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
JSON_DIR="${SCRIPT_DIR}/data/synthetic/json"

cd "${SCRIPT_DIR}"
source config_models.sh   # defines SEQ_LENGTHS
source config_tasks.sh    # defines NUM_SAMPLES, NUM_SAMPLES_OVERRIDE, and per-benchmark task arrays

if [ ! -f "${JSON_DIR}/PaulGrahamEssays.json" ] || [ ! -f "${JSON_DIR}/squad.json" ] || [ ! -f "${JSON_DIR}/hotpotqa.json" ]; then
    echo "=== fetching essay/QA source corpora (one-time) ==="
    (cd "${JSON_DIR}" && uv run --project "${PROJECT_ROOT}" python download_paulgraham_essay.py)
    (cd "${JSON_DIR}" && bash download_qa_dataset.sh)
fi

declare -n TASKS=$BENCHMARK
if [ -z "${TASKS}" ]; then
    echo "Benchmark: ${BENCHMARK} is not supported"
    exit 1
fi

for MAX_SEQ_LENGTH in "${SEQ_LENGTHS[@]}"; do
    CUR_NUM_SAMPLES=${NUM_SAMPLES_OVERRIDE[${MAX_SEQ_LENGTH}]:-${NUM_SAMPLES}}
    DATA_DIR="${OUTPUT_DIR}/${MAX_SEQ_LENGTH}"
    mkdir -p "${DATA_DIR}"

    for TASK in "${TASKS[@]}"; do
        echo "=== length=${MAX_SEQ_LENGTH} task=${TASK} num_samples=${CUR_NUM_SAMPLES} ==="
        uv run --project "${PROJECT_ROOT}" python data/prepare.py \
            --save_dir "${DATA_DIR}" \
            --benchmark "${BENCHMARK}" \
            --task "${TASK}" \
            --max_seq_length "${MAX_SEQ_LENGTH}" \
            --model_template_type base \
            --num_samples "${CUR_NUM_SAMPLES}"
    done
done
