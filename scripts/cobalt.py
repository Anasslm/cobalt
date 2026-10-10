#!/usr/bin/env python3

import argparse
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent

TB_TEST_DIR = ROOT / "verif" / "tb" / "tests"
TB_SELECTOR = ROOT / "verif" / "tb" / "selected_test.svh"
DEFAULT_TB_TEST = "cobalt_smoke_test.svh"

BOOT_DIR = ROOT / "firmware" / "boot"
SW_BUILD = ROOT / "scripts" / "sw" / "build.sh"
SIM_BUILD = ROOT / "scripts" / "compile.sh"

def select_testbench(test):
    # Prefer a testbench scenario matching the firmware test name
    scenario = TB_TEST_DIR / f"{test}.svh"

    if scenario.is_file():
        selected = scenario
        print(f"Selected testbench scenario: {scenario.name}")
    else:
        selected = TB_TEST_DIR / DEFAULT_TB_TEST
        print(
            f"No testbench scenario found for '{test}'; "
            f"using default: {DEFAULT_TB_TEST}"
        )

    if not selected.is_file():
        raise SystemExit(
            f"ERROR: Default testbench scenario not found: {selected}"
        )

    content = f'`include "tests/{selected.name}"\n'

    if not TB_SELECTOR.exists() or TB_SELECTOR.read_text() != content:
        TB_SELECTOR.write_text(content, encoding="utf-8")
        print(f"Updated test selector: {TB_SELECTOR.name}")
    else:
        print(f"Test selector unchanged: {TB_SELECTOR.name}")


def run(cmd, cwd=None):
    print()
    print(">>>", " ".join(str(x) for x in cmd))
    print()

    subprocess.run(
        [str(x) for x in cmd],
        cwd=cwd,
        check=True,
    )


def build_bootrom():
    print("========================================")
    print(" Building boot ROM")
    print("========================================")

    run(
        ["make", "-C", str(BOOT_DIR)]
    )


def build_firmware(test):
    print("========================================")
    print(f" Building firmware: {test}")
    print("========================================")

    run(
        [str(SW_BUILD), test]
    )


def build_sim():
    print("========================================")
    print(" Building simulation")
    print("========================================")

    run(
        [str(SIM_BUILD)]
    )


def run_sim():
    sim = ROOT / "obj_dir" / "Vcobalt_tb"

    if not sim.exists():
        print("ERROR: simulation executable not found.")
        print("Run: ./scripts/cobalt.py sim")
        sys.exit(1)

    print("========================================")
    print(" Running simulation")
    print("========================================")

    # Stream output live while also capturing it for PASS/FAIL detection.
    result = subprocess.Popen(
        [str(sim)],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )

    output = []

    try:
        for line in result.stdout:
            print(line, end="", flush=True)
            output.append(line)
    finally:
        result.stdout.close()

    return_code = result.wait()
    simulation_output = "".join(output)

    if return_code != 0:
        print()
        print("========================================")
        print(" SIMULATION PROCESS FAILED")
        print(f" PROCESS EXIT CODE = {return_code}")
        print("========================================")
        sys.exit(return_code)

    if "RESULT = PASS" in simulation_output:
        print("Simulation PASSED")
        return

    if "RESULT = FAIL" in simulation_output:
        print("Simulation FAILED")
        sys.exit(1)

    print("ERROR: No simulation result detected.")
    sys.exit(1)

def clean():
    print("Cleaning generated files...")

    paths = [
        ROOT / "obj_dir",
        ROOT / "firmware" / "build",
        ROOT / "verif" / "tb" / "sram_program.mem",
    ]

    for path in paths:
        if path.is_dir():
            import shutil
            shutil.rmtree(path)
            print(f"Removed {path}")

        elif path.exists():
            path.unlink()
            print(f"Removed {path}")


def main():
    parser = argparse.ArgumentParser(
        description="Cobalt SoC build and simulation tool"
    )

    subparsers = parser.add_subparsers(
        dest="command",
        required=True,
    )

    subparsers.add_parser("bootrom")

    firmware_parser = subparsers.add_parser("firmware")
    firmware_parser.add_argument(
        "--test",
        default="hello",
        help="Firmware test to build",
    )

    subparsers.add_parser("sim")

    run_parser = subparsers.add_parser("run")
    run_parser.add_argument(
        "--test",
        default="hello",
        help="Firmware test to run",
    )

    subparsers.add_parser("all")
    subparsers.add_parser("clean")

    args = parser.parse_args()

    if args.command == "bootrom":
        build_bootrom()

    elif args.command == "firmware":
        build_firmware(args.test)

    elif args.command == "sim":
        build_sim()

    elif args.command == "run":
        build_bootrom()
        build_firmware(args.test)
        select_testbench(args.test)
        build_sim()
        run_sim()

    elif args.command == "all":
        build_bootrom()
        build_firmware("hello")
        build_sim()

    elif args.command == "clean":
        clean()


if __name__ == "__main__":
    main()