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

"""
Upload generated RULER benchmark data to a Hugging Face dataset repo.

python hf_upload.py \
    --local-dir benchmark_root/data \
    --repo-id jacksonp-ai2/ruler \
    --path-in-repo data
"""
import argparse

from huggingface_hub import HfApi

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--local-dir", required=True, help="local folder containing the generated jsonl data")
parser.add_argument("--repo-id", default="jacksonp-ai2/ruler", help="destination HF dataset repo, e.g. jacksonp-ai2/ruler")
parser.add_argument("--path-in-repo", default="data", help="destination path within the repo")
parser.add_argument("--private", action="store_true", help="create the repo as private if it doesn't already exist")
parser.add_argument("--commit-message", default="Upload RULER benchmark data", help="commit message for the upload")
parser.add_argument("--token", default=None, help="HF auth token; defaults to $HF_TOKEN or the cached `hf auth login` token")
args = parser.parse_args()


def main():
    api = HfApi(token=args.token)
    api.create_repo(repo_id=args.repo_id, repo_type="dataset", private=args.private, exist_ok=True)

    print(f"Uploading {args.local_dir} -> {args.repo_id}:{args.path_in_repo}")
    api.upload_folder(
        folder_path=args.local_dir,
        path_in_repo=args.path_in_repo,
        repo_id=args.repo_id,
        repo_type="dataset",
        commit_message=args.commit_message,
        ignore_patterns=[".DS_Store", "*.pyc", "__pycache__/*"],
    )
    print("Done.")


if __name__ == "__main__":
    main()
