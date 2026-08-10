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
# Every (length, task) cell is independent, so they run in a parallel worker
# pool (default: one worker per CPU) instead of one at a time. Each worker's
# `prepare.py` output goes to its own log file under the cell's data dir,
# since interleaving dozens of workers' stdout would be unreadable; a
# one-line start/done/FAILED status per cell is streamed through a tqdm
# progress bar (progress_wrapper.py) tracking overall completion.
#
# prepare.py silently swallows failures in the underlying generator script
# (it catches the subprocess error, prints it, and still exits 0), so a
# "done" log line alone doesn't prove success -- this script additionally
# checks that the output file has the expected number of lines before
# reporting a cell as done.
#
# Requires `uv` (https://docs.astral.sh/uv/); dependencies are resolved
# automatically into the project's `.venv` on first run.
#
# The essay/QA source corpora used by the niah/qa tasks are fetched
# automatically below on first run (and skipped on later runs once present).
#
# Usage: bash generate-data.sh [output_dir] [benchmark] [jobs]
# Example: bash generate-data.sh benchmark_root/data synthetic 32

set -euo pipefail

OUTPUT_DIR=${1:-benchmark_root/data}
BENCHMARK=${2:-synthetic}
JOBS=${3:-$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)}

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

run_one() {
    local MAX_SEQ_LENGTH=$1
    local TASK=$2
    local NUM_SAMPLES_FOR_LENGTH=$3
    local DATA_DIR="${OUTPUT_DIR}/${MAX_SEQ_LENGTH}"
    local OUT_FILE="${DATA_DIR}/${TASK}/validation.jsonl"
    local LOG_FILE="${DATA_DIR}/${TASK}.generate.log"
    mkdir -p "${DATA_DIR}"

    echo "start  length=${MAX_SEQ_LENGTH} task=${TASK} num_samples=${NUM_SAMPLES_FOR_LENGTH}"
    uv run --project "${PROJECT_ROOT}" python data/prepare.py \
        --save_dir "${DATA_DIR}" \
        --benchmark "${BENCHMARK}" \
        --task "${TASK}" \
        --max_seq_length "${MAX_SEQ_LENGTH}" \
        --model_template_type base \
        --num_samples "${NUM_SAMPLES_FOR_LENGTH}" \
        > "${LOG_FILE}" 2>&1

    local N
    N=$(wc -l < "${OUT_FILE}" 2>/dev/null || echo 0)
    if [ "${N}" -eq "${NUM_SAMPLES_FOR_LENGTH}" ]; then
        echo "done   length=${MAX_SEQ_LENGTH} task=${TASK} (${N} lines)"
    else
        echo "FAILED length=${MAX_SEQ_LENGTH} task=${TASK} -- expected ${NUM_SAMPLES_FOR_LENGTH} lines, got ${N} -- see ${LOG_FILE}" >&2
        return 1
    fi
}
export -f run_one
export OUTPUT_DIR BENCHMARK PROJECT_ROOT

JOB_LIST="$(mktemp)"
trap 'rm -f "${JOB_LIST}"' EXIT
for MAX_SEQ_LENGTH in "${SEQ_LENGTHS[@]}"; do
    CUR_NUM_SAMPLES=${NUM_SAMPLES_OVERRIDE[${MAX_SEQ_LENGTH}]:-${NUM_SAMPLES}}
    for TASK in "${TASKS[@]}"; do
        echo "${MAX_SEQ_LENGTH} ${TASK} ${CUR_NUM_SAMPLES}" >> "${JOB_LIST}"
    done
done

TOTAL_JOBS=$(wc -l < "${JOB_LIST}")
echo "=== running ${TOTAL_JOBS} (length, task) cells across ${JOBS} parallel workers ==="
cat "${JOB_LIST}" | xargs -P "${JOBS}" -n 3 bash -c 'run_one "$@"' _ 2>&1 \
    | uv run --project "${PROJECT_ROOT}" python "${SCRIPT_DIR}/progress_wrapper.py" --total "${TOTAL_JOBS}"
