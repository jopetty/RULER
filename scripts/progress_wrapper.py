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
Consume newline-delimited `start`/`done`/`FAILED` status lines on stdin (as
emitted by generate-data.sh's parallel workers) and render a tqdm progress
bar over `--total` completions (done + FAILED). Every line is echoed above
the bar via `tqdm.write` so nothing is lost; exits 1 if any FAILED line
was seen, so the calling script's exit code reflects whether every cell
actually succeeded.

python progress_wrapper.py --total 130
"""
import argparse
import sys

from tqdm import tqdm

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--total", type=int, required=True, help="total number of cells to reach 100%%")
args = parser.parse_args()


def main():
    failed = 0
    with tqdm(total=args.total, unit="cell") as pbar:
        for line in sys.stdin:
            line = line.rstrip("\n")
            if not line:
                continue
            tqdm.write(line)
            if line.startswith("done") or line.startswith("FAILED"):
                pbar.update(1)
                if line.startswith("FAILED"):
                    failed += 1
    if failed:
        print(f"{failed} cell(s) failed", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
