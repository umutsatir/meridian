#!/usr/bin/env python3
"""Rebuilds App/Meridian/Resources/MRSettings.xcstrings and MRStates.xcstrings from the L("...") calls in
App/Meridian/Features and Scripts/strings_tr.py. Turkish is marked needs_review; missing Turkish is reported.
Usage: python3 Scripts/gen-strings.py"""
import glob
import json
import os
import re
import sys

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
from strings_tr import TR, STATES_EN, STATES_TR, EXTRA_KEYS  # noqa: E402

root = os.path.join(here, '..')
keys = list(EXTRA_KEYS)
for f in sorted(glob.glob(os.path.join(root, 'App/Meridian/Features/**/*.swift'), recursive=True)):
    for m in re.finditer(r'\bL\("((?:[^"\\]|\\.)*)"', open(f, encoding='utf-8').read()):
        k = m.group(1).replace('\\n', '\n').replace('\\"', '"')
        if k != '…' and k not in keys:
            keys.append(k)


def entry(en, tr):
    loc = {"en": {"stringUnit": {"state": "translated", "value": en}}}
    if tr:
        loc["tr"] = {"stringUnit": {"state": "needs_review", "value": tr}}
    return {"extractionState": "manual", "localizations": loc}


def write(name, d):
    out = os.path.join(root, 'App/Meridian/Resources')
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, name), 'w', encoding='utf-8') as fh:
        json.dump({"sourceLanguage": "en", "strings": d, "version": "1.0"}, fh, ensure_ascii=False, indent=2, sort_keys=True)


missing = [k for k in keys if k not in TR]
write('MRSettings.xcstrings', {k: entry(k, TR.get(k)) for k in keys})
write('MRStates.xcstrings', {k: entry(v, STATES_TR.get(k)) for k, v in STATES_EN.items()})
print(len(keys), 'strings;', len(missing), 'without Turkish:', missing)
