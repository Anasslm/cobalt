# COBALT

 ASIC design, verification, formal verification, and synthesis project.

## Structure

- `rtl/` — RTL design
- `verif/` — Verification environment and testbenches
- `tests/` — Test cases and test data
- `formal/` — Formal verification
- `synthesis/` — Synthesis scripts and constraints
- `docs/` — Architecture and design documentation
- `scripts/` — Build and utility scripts

## Register Generator

The register editor and its `regtool.py` implementation are in `scripts/`.
Install their Python dependencies and launch the editor with:

```sh
python3.12 -m pip install -r scripts/requirements.txt
python3.12 scripts/registrator.py
```


 

  
