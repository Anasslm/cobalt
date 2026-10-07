#!/usr/bin/env python3

import argparse
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent

BOOT_DIR = ROOT / "firmware" / "boot"
SW_BUILD = ROOT / "scripts" / "sw" / "build.sh"
SIM_BUILD = ROOT / "scripts" / "compile.sh"


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

    result = subprocess.run(
        [str(sim)],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )

    # Show simulation output
    print(result.stdout, end="")
    print(result.stderr, end="")

    # Check simulation process
    if result.returncode != 0:
        print()
        print("========================================")
        print(" SIMULATION PROCESS FAILED")
        print(f" PROCESS EXIT CODE = {result.returncode}")
        print("========================================")
        sys.exit(result.returncode)

    # Check Cobalt test result
    if "RESULT = PASS" in result.stdout:
        print("Simulation PASSED")
        return

    if "RESULT = FAIL" in result.stdout:
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