"""Throttle every Lambda function in the account to zero.

Triggered by the kill-switch budget (through SNS). Invoke it with
{"dry_run": true} to list what it would throttle without changing anything.

Undo, per function:  aws lambda delete-function-concurrency --function-name NAME
"""

import json
import os

import boto3

lam = boto3.client("lambda")
SELF = os.environ["AWS_LAMBDA_FUNCTION_NAME"]


def handler(event, context):
    dry_run = bool(event.get("dry_run"))
    print(json.dumps({"event": event, "dry_run": dry_run}))
    names = [
        fn["FunctionName"]
        for page in lam.get_paginator("list_functions").paginate()
        for fn in page["Functions"]
        if fn["FunctionName"] != SELF
    ]
    for name in names:
        if not dry_run:
            lam.put_function_concurrency(FunctionName=name, ReservedConcurrentExecutions=0)
        print(f"{'would throttle' if dry_run else 'throttled'} {name}")
    return {"dry_run": dry_run, "functions": names}
