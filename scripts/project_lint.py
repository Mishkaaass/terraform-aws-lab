#!/usr/bin/env python3
"""Fast structural checks for offline artifact QA (not a replacement for Terraform)."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
required = [
    'modules/network/main.tf','modules/security/main.tf','modules/identity/main.tf',
    'modules/compute/main.tf','environments/floci/main.tf','environments/aws/main.tf',
    'environments/floci/tests/architecture.tftest.hcl',
    'environments/floci/tests/security.tftest.hcl','.github/workflows/ci.yml',
]
for path in required:
    assert (ROOT/path).is_file(), path
for file in ROOT.rglob('*.tf'):
    contents = file.read_text()
    assert contents.count('{') == contents.count('}'), file
    assert contents.count('"') % 2 == 0, file
assert 'allowed_account_ids' in (ROOT/'environments/aws/provider.tf').read_text()
assert 'http_tokens                 = "required"' in (ROOT/'modules/compute/main.tf').read_text()
assert 'associate_public_ip_address = false' in (ROOT/'modules/compute/main.tf').read_text()
assert '/var/run/docker.sock:' not in (ROOT/'compose.yaml').read_text()
assert 'cidr_ipv4         = var.vpc_cidr' in (ROOT/'modules/security/main.tf').read_text()
assert 'key_name' not in (ROOT/'modules/compute/main.tf').read_text()
assert 'aws_vpc_security_group_ingress_rule' not in (ROOT/'modules/security/main.tf').read_text()
print(f'PASS: {len(required)} required files, brace/quote balance, safety markers')
