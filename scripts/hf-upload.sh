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

# Upload generated RULER benchmark data to a Hugging Face dataset repo.
# Requires `uv` (https://docs.astral.sh/uv/); dependencies are resolved
# automatically into the project's `.venv` on first run.
#
# Auth: run `uv run hf auth login` once, or export HF_TOKEN.
#
# Usage: bash hf-upload.sh <local_dir> [repo_id] [path_in_repo]
# Example: bash hf-upload.sh benchmark_root/data jacksonp-ai2/ruler data

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <local_dir> [repo_id] [path_in_repo]"
    exit 1
fi

LOCAL_DIR=$1
REPO_ID=${2:-jacksonp-ai2/ruler}
PATH_IN_REPO=${3:-data}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

cd "${PROJECT_ROOT}"
uv run python scripts/hf_upload.py \
    --local-dir "${LOCAL_DIR}" \
    --repo-id "${REPO_ID}" \
    --path-in-repo "${PATH_IN_REPO}"
