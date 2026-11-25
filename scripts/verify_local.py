#!/usr/bin/env python3
"""Strict, read-only local Floci verification against Terraform state.

Every AWS CLI request uses fake credentials and an explicit 127.0.0.1 endpoint.
Never reads AWS profiles for remote accounts, never applies or deletes resources.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
ENDPOINT = "http://127.0.0.1:4566"
REGION = "us-east-1"
EXPECTED_CIDR = "10.42.0.0/16"
EXPECTED_SUBNETS = {
    ("public", "10.42.0.0/24", "us-east-1a"),
    ("public", "10.42.1.0/24", "us-east-1b"),
    ("private", "10.42.10.0/24", "us-east-1a"),
    ("private", "10.42.11.0/24", "us-east-1b"),
}
SSM_POLICY = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
VALID_ID = re.compile(r"^(vpc|sg|subnet)-[a-zA-Z0-9]+$")


def run_json(args: list[str], *, local_aws: bool = False) -> Any:
    env = os.environ.copy()
    if local_aws:
        # Do not inherit credential/profile/endpoint selectors. Explicit localhost
        # endpoint + disposable credentials are mandatory for every AWS call.
        for name in tuple(env):
            if name.startswith("AWS_"):
                env.pop(name, None)
        env.update({
            "AWS_ACCESS_KEY_ID": "test",
            "AWS_SECRET_ACCESS_KEY": "test",
            "AWS_DEFAULT_REGION": REGION,
            "AWS_EC2_METADATA_DISABLED": "true",
            "AWS_PAGER": "",
        })
    proc = subprocess.run(
        args, cwd=ROOT, env=env, capture_output=True, text=True,
        stdin=subprocess.DEVNULL, timeout=40, check=False,
    )
    if proc.returncode:
        raise RuntimeError(
            f"{'AWS localhost query' if local_aws else 'Terraform output'} failed "
            f"(exit {proc.returncode}): {proc.stderr.strip()[:500]}"
        )
    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        raise RuntimeError("Command returned invalid JSON") from exc


def aws(service: str, operation: str, *args: str) -> Any:
    # The caller may select only these fixed, read-only API operations.
    permitted = {
        ("ec2", "describe-vpcs"),
        ("ec2", "describe-subnets"),
        ("ec2", "describe-route-tables"),
        ("ec2", "describe-internet-gateways"),
        ("ec2", "describe-security-groups"),
        ("iam", "list-attached-role-policies"),
    }
    if (service, operation) not in permitted:
        raise ValueError("Only documented read-only Floci operations are allowed")
    return run_json(
        ["aws", "--no-cli-pager", "--endpoint-url", ENDPOINT,
         "--region", REGION, service, operation, *args, "--output", "json"],
        local_aws=True,
    )


def output_values(result: dict[str, Any]) -> dict[str, Any]:
    required = (
        "vpc_id", "public_subnet_ids", "private_subnet_ids",
        "security_group_id", "iam_role_name", "instance_count",
    )
    if not isinstance(result, dict):
        raise ValueError("Terraform output was not an object")
    missing = [k for k in required if k not in result or "value" not in result[k]]
    if missing:
        raise ValueError("Missing Terraform outputs: " + ", ".join(missing))
    values = {k: result[k]["value"] for k in required}
    for k in ("vpc_id", "security_group_id"):
        if not isinstance(values[k], str) or not VALID_ID.fullmatch(values[k]):
            raise ValueError(f"Unexpected {k}. Stop and inspect Terraform state.")
    for kind in ("public_subnet_ids", "private_subnet_ids"):
        ids = values[kind]
        if not isinstance(ids, list) or len(ids) != 2 or any(
            not isinstance(v, str) or not VALID_ID.fullmatch(v) for v in ids
        ):
            raise ValueError(f"Unexpected {kind}; expected two valid IDs.")
    if len(set(values["public_subnet_ids"] + values["private_subnet_ids"])) != 4:
        raise ValueError("Terraform subnet IDs are not distinct.")
    if values["instance_count"] != 0:
        raise ValueError("Compute was enabled; default no-EC2 verification refuses.")
    if not isinstance(values["iam_role_name"], str) or not values["iam_role_name"]:
        raise ValueError("IAM role name missing from Terraform outputs.")
    return values


def validate(state: dict[str, Any], snapshot: dict[str, Any]) -> list[str]:
    """Return clear invariant violations. Empty list means all observed checks pass."""
    errors: list[str] = []
    def require(ok: bool, why: str) -> None:
        if not ok:
            errors.append(why)

    vpcs = snapshot["Vpcs"].get("Vpcs") or []
    require(
        len(vpcs) == 1
        and vpcs[0].get("VpcId") == state["vpc_id"]
        and vpcs[0].get("CidrBlock") == EXPECTED_CIDR
        and vpcs[0].get("State") == "available",
        "VPC ID/CIDR/state mismatch (expect 10.42.0.0/16, available).",
    )

    public_ids = set(state["public_subnet_ids"])
    private_ids = set(state["private_subnet_ids"])
    all_ids = public_ids | private_ids
    subnets = snapshot["Subnets"].get("Subnets") or []
    by_id = {s.get("SubnetId"): s for s in subnets}
    require(
        len(subnets) == 4 and set(by_id) == all_ids,
        "Expected exactly the four Terraform-managed subnets, no extras.",
    )
    observed = set()
    for sid in all_ids:
        subnet = by_id.get(sid)
        if not subnet:
            continue
        tier = "public" if sid in public_ids else "private"
        observed.add((tier, subnet.get("CidrBlock"), subnet.get("AvailabilityZone")))
        require(subnet.get("VpcId") == state["vpc_id"],
                f"Subnet {sid} belongs to a different VPC.")
        require(subnet.get("MapPublicIpOnLaunch") is False,
                f"Subnet {sid} must not auto-assign public IPv4.")
    require(observed == EXPECTED_SUBNETS,
            "Subnet CIDR/tier/AZ topology differs from the two-AZ design.")

    gateways = snapshot["InternetGateways"].get("InternetGateways") or []
    attached = [
        g for g in gateways if any(
            a.get("VpcId") == state["vpc_id"] for a in (g.get("Attachments") or [])
        )
    ]
    require(len(attached) == 1, "Expected exactly one VPC-attached Internet Gateway.")
    igw_id = attached[0].get("InternetGatewayId") if len(attached) == 1 else None

    tables = snapshot["RouteTables"].get("RouteTables") or []
    associations: dict[str, list[str]] = {i: [] for i in all_ids}
    for table in tables:
        for association in (table.get("Associations") or []):
            sid = association.get("SubnetId")
            if sid in associations:
                associations[sid].append(table.get("RouteTableId"))
    for sid, candidates in associations.items():
        require(len(candidates) == 1,
                f"Subnet {sid} needs exactly one explicit route-table association.")

    def table_for(ids: set[str]) -> dict[str, Any] | None:
        linked = {x for sid in ids for x in associations[sid]}
        if len(linked) != 1:
            return None
        return next((t for t in tables if t.get("RouteTableId") == next(iter(linked))), None)

    public_table = table_for(public_ids)
    private_table = table_for(private_ids)
    require(public_table is not None, "Public subnets must share one route table.")
    require(private_table is not None, "Private subnets must share one route table.")
    if public_table and private_table:
        require(public_table["RouteTableId"] != private_table["RouteTableId"],
                "Public and private subnets must not share a route table.")

    def defaults(table: dict[str, Any] | None) -> list[dict[str, Any]]:
        return [
            route for route in ((table or {}).get("Routes") or [])
            if route.get("DestinationCidrBlock") == "0.0.0.0/0"
            or route.get("DestinationIpv6CidrBlock") == "::/0"
        ]

    pub_default = defaults(public_table)
    require(
        igw_id is not None
        and len(pub_default) == 1
        and pub_default[0].get("DestinationCidrBlock") == "0.0.0.0/0"
        and pub_default[0].get("GatewayId") == igw_id,
        "Public route table must have one IPv4 default route to the attached IGW.",
    )
    require(private_table is not None and not defaults(private_table),
            "Isolated private route table must have no default route (v4 or v6).")

    groups = snapshot["SecurityGroups"].get("SecurityGroups") or []
    require(len(groups) == 1, "Expected exactly one named instance security group.")
    if len(groups) == 1:
        sg = groups[0]
        require(sg.get("GroupId") == state["security_group_id"]
                and sg.get("VpcId") == state["vpc_id"],
                "Security group ID or VPC mismatch.")
        require(not (sg.get("IpPermissions") or []),
                "Unexpected inbound security-group permission (zero ingress required).")
        egress = sg.get("IpPermissionsEgress") or []
        require(
            len(egress) == 1
            and egress[0].get("IpProtocol") == "tcp"
            and egress[0].get("FromPort") == 443
            and egress[0].get("ToPort") == 443
            and sorted(r.get("CidrIp") for r in (egress[0].get("IpRanges") or []))
                == [EXPECTED_CIDR]
            and not egress[0].get("Ipv6Ranges")
            and not egress[0].get("PrefixListIds")
            and not egress[0].get("UserIdGroupPairs"),
            "Security-group egress must be exclusively TCP/443 to 10.42.0.0/16.",
        )

    policies = snapshot["RolePolicies"].get("AttachedPolicies") or []
    arns = {p.get("PolicyArn") for p in policies}
    require(arns == {SSM_POLICY},
            "IAM EC2 role must have only AmazonSSMManagedInstanceCore attached.")
    return errors


def main() -> int:
    try:
        state = output_values(
            run_json(["bash", "scripts/terraform.sh",
                      "-chdir=environments/floci", "output", "-json"])
        )
        data = {
            "Vpcs": aws("ec2", "describe-vpcs", "--vpc-ids", state["vpc_id"]),
            "Subnets": aws("ec2", "describe-subnets", "--filters",
                           f"Name=vpc-id,Values={state['vpc_id']}"),
            "RouteTables": aws("ec2", "describe-route-tables", "--filters",
                               f"Name=vpc-id,Values={state['vpc_id']}"),
            "InternetGateways": aws(
                "ec2", "describe-internet-gateways", "--filters",
                f"Name=attachment.vpc-id,Values={state['vpc_id']}"
            ),
            "SecurityGroups": aws(
                "ec2", "describe-security-groups", "--group-ids",
                state["security_group_id"]
            ),
            "RolePolicies": aws(
                "iam", "list-attached-role-policies", "--role-name",
                state["iam_role_name"]
            ),
        }
        errors = validate(state, data)
    except (RuntimeError, ValueError, KeyError, TypeError, OSError, subprocess.TimeoutExpired) as exc:
        print(f"[BLOCK] Cannot independently verify local emulator: {exc}", file=sys.stderr)
        return 2

    if errors:
        for err in errors:
            print(f"[FAIL] {err}", file=sys.stderr)
        print(f"[BLOCK] {len(errors)} architecture/security invariant(s) failed.", file=sys.stderr)
        return 2
    for label in (
        "VPC 10.42.0.0/16 and four distinct subnets across two AZs",
        "Public IGW route; isolated private route; explicit associations",
        "Security group: zero inbound; VPC-only TCP/443 egress",
        "IAM role: only AmazonSSMManagedInstanceCore; compute disabled",
    ):
        print("[PASS] " + label)
    print(f"[PASS] Live Floci control-plane checks passed for {state['vpc_id']}.")
    print("[NOTE] AWS API emulation is not proof of real AWS dataplane/IAM enforcement.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
