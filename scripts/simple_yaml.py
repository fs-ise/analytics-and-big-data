from __future__ import annotations
from pathlib import Path
import yaml

def load(path):
    return yaml.safe_load(Path(path).read_text(encoding='utf-8')) or {}

def dump(data) -> str:
    return yaml.safe_dump(data, sort_keys=False, allow_unicode=True)

def save(path, data):
    Path(path).write_text(dump(data), encoding='utf-8')
