#!/usr/bin/env python3

import argparse
import logging
import subprocess
import sys

logging.basicConfig(
    filename="/home/atguigu/args_demo.log",
    level=logging.INFO,
    format="%(asctime)s %(levelname)s: %(message)s"
)

parser = argparse.ArgumentParser(
    description="执行多个系统命令并汇总结果"
)

parser.add_argument(
    "commands",
    nargs="+",
    help="要执行的命令名称"
)

parser.add_argument(
    "--verbose",
    action="store_true",
    help="显示详细执行信息"
)

args = parser.parse_args()

print("program:", sys.argv[0])

has_failure = False

for argument in args.commands:
    logging.info("command started: %s", argument)

    if args.verbose:
        print("executing:", argument)
    try:
        result = subprocess.run(
            [argument],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True,
            timeout=3,
        )
    except subprocess.TimeoutExpired:
        logging.error("command timeout: %s", argument)
        print("{} timeout after 3 seconds".format(argument))
        has_failure = True
        continue

    print("{} output: {}".format(argument, result.stdout.strip()))
    print("{} returncode: {}".format(argument, result.returncode))

    if result.returncode == 0:
        logging.info("command succeeded: %s", argument)
    else:
        logging.error(
            "command failed: %s returncode=%s",
            argument,
            result.returncode
        )
    if result.stderr:
        print("{} stderr: {}".format(argument, result.stderr.strip()))
    if result.returncode != 0:
        has_failure = True
if has_failure:
    sys.exit(1)

sys.exit(0)
