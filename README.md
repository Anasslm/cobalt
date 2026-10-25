# COBALT

Cobalt is an ASIC design, verification, formal verification, and synthesis
project. This guide explains how to clone the repository, install the tools
needed for simulation, and run the first firmware test.

## Clone the repository

Clone Cobalt with its RTL dependencies (Git submodules):

```sh
git clone --recurse-submodules https://github.com/Anasslm/cobalt.git
cd cobalt
```

If you already cloned without submodules, initialize them with:

```sh
git submodule update --init --recursive
```

The CLINT submodule is pinned to Cobalt's one-core CLINT fork/branch.

## Install prerequisites (Ubuntu)

The `hello` run builds RISC-V firmware and a Verilator simulation. Install the
required compiler, build tools, and Verilator dependencies:

```sh
sudo apt-get update
sudo apt-get install -y \
  git make autoconf flex bison gcc g++ libfl-dev help2man \
  python3 python3-pip \
  gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf
```

Cobalt CI uses Verilator 5.032. Build and install that version from source:

```sh
git clone --depth 1 --branch v5.032 \
  https://github.com/verilator/verilator.git
cd verilator
autoconf
./configure
make -j"$(nproc)"
sudo make install
cd ..
```

Check that the tools are available:

```sh
python3 --version
verilator --version
riscv64-unknown-elf-gcc --version
```

## Build and run the first test

From the Cobalt repository root:

```sh
python3 scripts/cobalt.py run --test hello
```

The command builds the boot ROM, compiles the `hello` firmware into SRAM
initialization data, builds the Verilator testbench, and runs the simulation.
The test runner selects a testbench scenario named after the firmware test if
one exists; otherwise it uses the generic smoke-test scenario. A successful
simulation reports `RESULT = PASS` and `Simulation PASSED`.

The runner also accepts other C firmware test names from `firmware/tests/`,
for example:

```sh
python3 scripts/cobalt.py run --test clint_hello
```

Other useful commands are:

```sh
python3 scripts/cobalt.py firmware --test hello  # Build firmware only
python3 scripts/cobalt.py sim                    # Build simulation only
python3 scripts/cobalt.py clean                  # Remove generated build outputs
```

## Repository structure

- `rtl/` — SoC, CPU subsystem, peripherals, and third-party RTL
- `firmware/` — Boot ROM sources, linker scripts, libraries, and firmware tests
- `verif/` — Testbench, VIP, and testbench scenarios
- `filelists/` — RTL and testbench source file lists
- `formal/` — Formal verification sources
- `synthesis/` — Synthesis scripts and constraints
- `docs/` — Architecture and design documentation
- `scripts/` — Build, simulation, and utility scripts

## Register Generator

Registrator is a desktop GUI for creating and editing Cobalt peripheral
register maps. A register block is stored as an HJSON file. The GUI uses the
bundled `scripts/reggen/regtool.py` to validate a block and generate register
RTL or documentation. The register editor is optional and is not needed to run
the standard `hello` simulation.

### Install and launch

Registrator uses Python 3.12 and the packages listed in
[`scripts/requirements.txt`](scripts/requirements.txt). On Ubuntu, install
Python and virtual-environment support if needed, then create an isolated
environment and launch the GUI from the repository root:

```sh
sudo apt-get install -y python3.12 python3.12-venv
python3.12 -m venv .venv-reggen
source .venv-reggen/bin/activate
python -m pip install -r scripts/requirements.txt
python scripts/registrator.py
```

Registrator opens a desktop window, so run it from a graphical desktop
session. The register model and generated output are independent of the SoC
simulation.

### Basic workflow

1. Choose **New Block** to create a register block, or **Open HJSON** to edit an
   existing one. For a new block, provide its name, save directory, register
   width (32 or 64 bits), primary clock, and reset.
2. Use **+ Register** to add a register, then select it and choose **+ Field**
   to add fields. Double-click a register or field, or select it and click
   **Edit**, to change its properties. A field includes a name, bit range, and
   description; register properties include software/hardware access and reset
   value. **Remove** deletes the selected register or field.
3. Review the register tree and map preview, then choose **Save** to write the
   HJSON source.
4. Click **CHECK** to validate the saved HJSON with the bundled `regtool.py`.
   Successful validation enables the export menu.
5. Choose **EXPORT** to generate documentation (HTML or Markdown) or RTL. RTL
   export offers the RegBus and APB interfaces and asks for an output
   directory.

The RAL option is visible in the export menu but is not implemented yet.

Example of Registrator with the Cobalt SYSCTRL register map loaded:

![Registrator GUI showing the SYSCTRL register map](docs/images/registrator.png)
