#!/usr/bin/env python3
"""Inspect a Woodpecker pipeline and print failed step logs."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from dataclasses import dataclass
from typing import Any
from urllib.parse import quote, urlencode
from urllib.request import Request, urlopen


TERMINAL_STATUSES = {"success", "failure", "skipped", "blocked", "canceled", "killed", "error", "declined"}
FAILURE_STATES = {"failure", "error", "killed", "canceled"}


@dataclass
class ApiConfig:
    server: str
    token: str


def normalize_server(server: str) -> str:
    server = server.rstrip("/")
    if server.endswith("/api"):
        return server
    return server + "/api"


def run_git(args: list[str]) -> str | None:
    try:
        return subprocess.check_output(["git", *args], text=True).strip()
    except Exception:
        return None


def api_get(cfg: ApiConfig, path: str, params: dict[str, str] | None = None) -> Any:
    url = normalize_server(cfg.server) + path
    if params:
        url += "?" + urlencode(params)
    req = Request(
        url,
        headers={
            "Authorization": f"Bearer {cfg.token}",
            "Accept": "application/json",
        },
    )
    with urlopen(req, timeout=30) as response:
        raw = response.read()
        content_type = response.headers.get_content_type()
    if content_type == "application/json":
        return json.loads(raw.decode("utf-8"))
    return raw.decode("utf-8", errors="replace")


def lookup_repo_id(cfg: ApiConfig, repo_full_name: str) -> int:
    data = api_get(cfg, f"/repos/lookup/{quote(repo_full_name, safe='')}")
    if isinstance(data, int):
        repo_id = data
    elif isinstance(data, dict):
        repo_id = data.get("id")
    else:
        raise RuntimeError(f"Unexpected repo lookup payload type: {type(data).__name__}")
    if not isinstance(repo_id, int):
        raise RuntimeError(f"Unable to resolve repo id for {repo_full_name}")
    return repo_id


def list_pipelines(cfg: ApiConfig, repo_id: int, branch: str | None, event: str, per_page: int) -> list[dict[str, Any]]:
    params = {"page": "1", "perPage": str(per_page)}
    if branch:
        params["branch"] = branch
    if event:
        params["event"] = event
    data = api_get(cfg, f"/repos/{repo_id}/pipelines", params=params)
    if isinstance(data, dict):
        return data.get("pipelines", data.get("results", [])) or []
    return data


def pipeline_commit(pipeline: dict[str, Any]) -> str | None:
    commit = pipeline.get("commit")
    if isinstance(commit, str):
        return commit
    ref = pipeline.get("ref")
    if isinstance(ref, str) and ref:
        return ref
    return None


def select_pipeline(pipelines: list[dict[str, Any]], commit: str | None) -> dict[str, Any] | None:
    if commit:
        for pipeline in pipelines:
            if pipeline_commit(pipeline) == commit:
                return pipeline
    return pipelines[0] if pipelines else None


def is_terminal_pipeline(pipeline: dict[str, Any]) -> bool:
    status = str(pipeline.get("status", "")).lower()
    finished = pipeline.get("finished")
    return status in TERMINAL_STATUSES or bool(finished)


def iter_steps(pipeline: dict[str, Any]) -> list[dict[str, Any]]:
    steps: list[dict[str, Any]] = []
    for workflow in pipeline.get("workflows", []) or []:
        for child in workflow.get("children", []) or []:
            if isinstance(child, dict):
                steps.append(child)
    return steps


def failed_steps(pipeline: dict[str, Any]) -> list[dict[str, Any]]:
    steps = iter_steps(pipeline)
    failed: list[dict[str, Any]] = []
    for step in steps:
        state = str(step.get("state", "")).lower()
        exit_code = step.get("exit_code")
        if state in FAILURE_STATES or (isinstance(exit_code, int) and exit_code != 0):
            failed.append(step)
    return failed


def decode_log_payload(payload: Any) -> str:
    if isinstance(payload, str):
        return payload
    if isinstance(payload, list):
        chunks: list[bytes] = []
        for item in payload:
            if isinstance(item, dict) and "data" in item:
                data = item["data"]
                if isinstance(data, list):
                    chunks.append(bytes(int(b) & 0xFF for b in data))
                elif isinstance(data, str):
                    chunks.append(data.encode("utf-8", errors="replace"))
        return b"".join(chunks).decode("utf-8", errors="replace")
    return json.dumps(payload, ensure_ascii=False, indent=2)


def fetch_step_log(cfg: ApiConfig, repo_id: int, pipeline_number: int, step_id: int) -> str:
    payload = api_get(cfg, f"/repos/{repo_id}/logs/{pipeline_number}/{step_id}")
    return decode_log_payload(payload)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--server", default=os.environ.get("WOODPECKER_SERVER"))
    parser.add_argument("--token", default=os.environ.get("WOODPECKER_TOKEN"))
    parser.add_argument("--repo", default=os.environ.get("WOODPECKER_REPO"))
    parser.add_argument("--branch", default=os.environ.get("WOODPECKER_BRANCH") or run_git(["branch", "--show-current"]))
    parser.add_argument("--commit", default=os.environ.get("WOODPECKER_COMMIT") or run_git(["rev-parse", "HEAD"]))
    parser.add_argument("--event", default=os.environ.get("WOODPECKER_EVENT", "push"))
    parser.add_argument("--wait-seconds", type=int, default=int(os.environ.get("WOODPECKER_WAIT_SECONDS", "90")))
    parser.add_argument("--max-wait-seconds", type=int, default=int(os.environ.get("WOODPECKER_MAX_WAIT_SECONDS", "300")))
    parser.add_argument("--per-page", type=int, default=int(os.environ.get("WOODPECKER_PIPELINE_PAGE_SIZE", "20")))
    args = parser.parse_args()

    if not args.server or not args.token or not args.repo:
        print("WOODPECKER_SERVER, WOODPECKER_TOKEN, and WOODPECKER_REPO are required.", file=sys.stderr)
        return 2

    if args.wait_seconds > 0:
        time.sleep(args.wait_seconds)

    cfg = ApiConfig(server=args.server, token=args.token)
    repo_id = lookup_repo_id(cfg, args.repo)
    elapsed = args.wait_seconds

    pipeline = None
    while elapsed <= args.max_wait_seconds:
        pipelines = list_pipelines(cfg, repo_id, args.branch, args.event, args.per_page)
        pipeline = select_pipeline(pipelines, args.commit)
        if pipeline and is_terminal_pipeline(pipeline):
            break
        time.sleep(15)
        elapsed += 15

    if not pipeline:
        print(f"No Woodpecker pipeline found for {args.repo} {args.branch}@{args.commit}", file=sys.stderr)
        return 1

    status = pipeline.get("status")
    number = pipeline.get("number")
    print(f"pipeline={number} status={status} commit={pipeline_commit(pipeline)}")

    if str(status).lower() in {"success", "passed"}:
        return 0

    if not isinstance(number, int):
        print("Pipeline number is missing.", file=sys.stderr)
        return 1

    steps = failed_steps(pipeline)
    if not steps:
        print("No failed steps found in pipeline payload. Printing pipeline summary only.")
        print(json.dumps(pipeline, ensure_ascii=False, indent=2))
        return 1

    for step in steps:
        step_id = step.get("id")
        step_name = step.get("name", "unknown")
        state = step.get("state")
        exit_code = step.get("exit_code")
        print(f"\n--- failed step: {step_name} (id={step_id}, state={state}, exit_code={exit_code}) ---")
        if isinstance(step_id, int):
            print(fetch_step_log(cfg, repo_id, number, step_id))
        else:
            print("Step id is missing; cannot fetch logs.", file=sys.stderr)

    return 1


if __name__ == "__main__":
    raise SystemExit(main())

