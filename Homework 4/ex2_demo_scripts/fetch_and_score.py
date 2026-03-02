# Small demo script for the assignment:
# Pull minimal state from on-chain
# Pull JSON metadata from IPFS (off-chain).
# Produce a simple model output: Documentation Completeness Score (0-100).


from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Optional

import requests
from web3 import Web3


@dataclass
class ScoreResult:
    score: int
    label: str
    details: Dict[str, Any]


def compute_doc_score(meta: Dict[str, Any]) -> ScoreResult:
    """Very simple scoring model for Challenge 2 (documentation scarcity)."""
    score = 0
    details = {}

    docs = meta.get("documents", {}) or {}
    standards = meta.get("standards", []) or []

    def has(key: str) -> bool:
        v = docs.get(key)
        return isinstance(v, str) and len(v) > 0

    # main evidence
    details["radiation_report"] = has("radiation_report")
    score += 40 if details["radiation_report"] else 0

    # basic docs
    details["datasheet"] = has("datasheet")
    score += 20 if details["datasheet"] else 0

    details["pcn"] = has("pcn")
    score += 20 if details["pcn"] else 0

    # basic standards indicator
    details["standards"] = standards
    score += 20 if len(standards) > 0 else 0

    if score >= 80:
        label = "good"
    elif score >= 50:
        label = "medium"
    else:
        label = "low"

    return ScoreResult(score=score, label=label, details=details)


def ipfs_json(cid: str, gateway: str = "https://ipfs.io/ipfs/") -> Dict[str, Any]:
    url = gateway.rstrip("/") + "/" + cid
    r = requests.get(url, timeout=15)
    r.raise_for_status()
    return r.json()


def run_onchain_demo(
    rpc_url: str,
    contract_address: str,
    abi_path: Path,
    token_id: int,
    ipfs_gateway: str = "https://ipfs.io/ipfs/",
) -> None:
    w3 = Web3(Web3.HTTPProvider(rpc_url))
    if not w3.is_connected():
        raise RuntimeError("Cannot connect to RPC")

    abi = json.loads(abi_path.read_text(encoding="utf-8"))
    contract = w3.eth.contract(address=Web3.to_checksum_address(contract_address), abi=abi)

    # tokenId returns a tuple, order must match the Solidity struct
    twin = contract.functions.registry(token_id).call()

    # struct: lotHash, partNumberHash, metaCID, reportCID, testHouse, fee, stake, ts, published
    meta_cid = twin[2]
    published = twin[8]

    print(f"token_id={token_id}, report_published={published}")
    print(f"metaCID={meta_cid}")

    meta = ipfs_json(meta_cid, gateway=ipfs_gateway)
    res = compute_doc_score(meta)

    print("\n--- Documentation Completeness ---")
    print(f"score={res.score} ({res.label})")
    for k, v in res.details.items():
        print(f"{k}: {v}")


def run_offline_demo(sample_path: Path) -> None:
    meta = json.loads(sample_path.read_text(encoding="utf-8"))
    res = compute_doc_score(meta)
    print("offline sample metadata")
    print(f"score={res.score} ({res.label})")
    print(res.details)


if __name__ == "__main__":
    # Quick offline run
    here = Path(__file__).resolve().parent
    sample = here / "sample_metadata.json"
    if sample.exists():
        run_offline_demo(sample)


