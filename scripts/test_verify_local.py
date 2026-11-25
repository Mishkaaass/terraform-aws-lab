#!/usr/bin/env python3
"""Offline tests for live Floci invariants. No Docker, AWS, or Terraform needed."""
from __future__ import annotations

import copy
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

FILE = Path(__file__).with_name("verify_local.py")
SPEC = importlib.util.spec_from_file_location("verify_local_invariants", FILE)
assert SPEC and SPEC.loader
verify = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(verify)


def fixture() -> tuple[dict, dict]:
    state = {
        "vpc_id": "vpc-test123",
        "security_group_id": "sg-test123",
        "public_subnet_ids": ["subnet-public1", "subnet-public2"],
        "private_subnet_ids": ["subnet-private1", "subnet-private2"],
        "iam_role_name": "terraform-aws-lab-ec2-test",
        "instance_count": 0,
    }
    info = [
        ("subnet-public1", "10.42.0.0/24", "us-east-1a"),
        ("subnet-public2", "10.42.1.0/24", "us-east-1b"),
        ("subnet-private1", "10.42.10.0/24", "us-east-1a"),
        ("subnet-private2", "10.42.11.0/24", "us-east-1b"),
    ]
    snapshot = {
        "Vpcs": {
            "Vpcs": [{"VpcId": state["vpc_id"],
                      "CidrBlock": "10.42.0.0/16", "State": "available"}],
        },
        "Subnets": {
            "Subnets": [
                {"SubnetId": sid, "VpcId": state["vpc_id"], "CidrBlock": cidr,
                 "AvailabilityZone": az, "MapPublicIpOnLaunch": False}
                for sid, cidr, az in info
            ],
        },
        "RouteTables": {"RouteTables": [
            {"RouteTableId": "rtb-public", "Associations": [
                {"SubnetId": "subnet-public1"}, {"SubnetId": "subnet-public2"}
            ], "Routes": [
                {"DestinationCidrBlock": "10.42.0.0/16", "GatewayId": "local"},
                {"DestinationCidrBlock": "0.0.0.0/0", "GatewayId": "igw-test"},
            ]},
            {"RouteTableId": "rtb-private", "Associations": [
                {"SubnetId": "subnet-private1"}, {"SubnetId": "subnet-private2"}
            ], "Routes": [
                {"DestinationCidrBlock": "10.42.0.0/16", "GatewayId": "local"}
            ]},
        ]},
        "InternetGateways": {"InternetGateways": [
            {"InternetGatewayId": "igw-test",
             "Attachments": [{"VpcId": state["vpc_id"], "State": "available"}]},
        ]},
        "SecurityGroups": {"SecurityGroups": [{
            "GroupId": state["security_group_id"],
            "VpcId": state["vpc_id"],
            "IpPermissions": [],
            "IpPermissionsEgress": [{
                "IpProtocol": "tcp", "FromPort": 443, "ToPort": 443,
                "IpRanges": [{"CidrIp": "10.42.0.0/16"}],
                "Ipv6Ranges": [], "PrefixListIds": [], "UserIdGroupPairs": [],
            }],
        }]},
        "RolePolicies": {"AttachedPolicies": [
            {"PolicyName": "AmazonSSMManagedInstanceCore",
             "PolicyArn": verify.SSM_POLICY},
        ]},
    }
    return state, snapshot


class VerifyLocalInvariantTests(unittest.TestCase):
    def test_valid_complete_topology_passes(self) -> None:
        state, snap = fixture()
        self.assertEqual(verify.validate(state, snap), [])

    def test_open_ssh_ingress_fails(self) -> None:
        state, snap = fixture()
        snap["SecurityGroups"]["SecurityGroups"][0]["IpPermissions"].append({
            "IpProtocol": "tcp", "FromPort": 22, "ToPort": 22,
            "IpRanges": [{"CidrIp": "0.0.0.0/0"}],
        })
        self.assertIn("inbound", " ".join(verify.validate(state, snap)).lower())

    def test_public_egress_fails(self) -> None:
        state, snap = fixture()
        snap["SecurityGroups"]["SecurityGroups"][0]["IpPermissionsEgress"][0]["IpRanges"] = [
            {"CidrIp": "0.0.0.0/0"}
        ]
        self.assertIn("egress", " ".join(verify.validate(state, snap)).lower())

    def test_private_default_route_fails(self) -> None:
        state, snap = fixture()
        snap["RouteTables"]["RouteTables"][1]["Routes"].append({
            "DestinationCidrBlock": "0.0.0.0/0", "NatGatewayId": "nat-test"
        })
        self.assertIn("private", " ".join(verify.validate(state, snap)).lower())

    def test_missing_public_igw_fails(self) -> None:
        state, snap = fixture()
        snap["RouteTables"]["RouteTables"][0]["Routes"].pop()
        self.assertIn("public", " ".join(verify.validate(state, snap)).lower())

    def test_wrong_az_fails(self) -> None:
        state, snap = fixture()
        snap["Subnets"]["Subnets"][0]["AvailabilityZone"] = "us-east-1c"
        self.assertIn("topology", " ".join(verify.validate(state, snap)).lower())

    def test_public_ip_auto_assignment_fails(self) -> None:
        state, snap = fixture()
        snap["Subnets"]["Subnets"][0]["MapPublicIpOnLaunch"] = True
        self.assertIn("public IPv4", " ".join(verify.validate(state, snap)))

    def test_missing_route_table_association_fails(self) -> None:
        state, snap = fixture()
        snap["RouteTables"]["RouteTables"][1]["Associations"] = []
        self.assertIn("association", " ".join(verify.validate(state, snap)).lower())

    def test_unexpected_iam_policy_fails(self) -> None:
        state, snap = fixture()
        snap["RolePolicies"]["AttachedPolicies"].append({
            "PolicyArn": "arn:aws:iam::aws:policy/AdministratorAccess"
        })
        self.assertIn("IAM", " ".join(verify.validate(state, snap)))

    def test_missing_terraform_outputs_fail_closed(self) -> None:
        with self.assertRaises(ValueError):
            verify.output_values({"vpc_id": {"value": "vpc-test123"}})

    def test_compute_enabled_fails_closed(self) -> None:
        state, _ = fixture()
        state["instance_count"] = 1
        with self.assertRaises(ValueError):
            verify.output_values({k: {"value": v} for k, v in state.items()})

    def test_non_whitelisted_aws_operations_rejected(self) -> None:
        with self.assertRaises(ValueError):
            verify.aws("ec2", "terminate-instances", "--instance-ids", "i-nope")

    def test_aws_endpoint_and_credentials_are_forced_local(self) -> None:
        result = type("Result", (), {"returncode": 0, "stdout": "{}",
                                     "stderr": ""})()
        with patch.object(verify.subprocess, "run", return_value=result) as run:
            with patch.dict("os.environ", {
                "AWS_PROFILE": "production",
                "AWS_ACCESS_KEY_ID": "not-a-test-key",
                "AWS_ENDPOINT_URL": "https://ec2.amazonaws.com",
            }):
                verify.aws("ec2", "describe-vpcs")
        cmd = run.call_args.args[0]
        env = run.call_args.kwargs["env"]
        self.assertEqual(cmd[cmd.index("--endpoint-url") + 1],
                         "http://127.0.0.1:4566")
        self.assertEqual(env["AWS_ACCESS_KEY_ID"], "test")
        self.assertNotIn("AWS_PROFILE", env)
        self.assertNotIn("AWS_ENDPOINT_URL", env)


if __name__ == "__main__":
    unittest.main()
