#!/bin/zsh
# SPDX-License-Identifier: Apache-2.0
set -eu

Scripts/check-media-privacy.sh
python3 Website/generate.py
bash Scripts/check-website.sh

printf '%s\n' "PASS: media references and website generation"
