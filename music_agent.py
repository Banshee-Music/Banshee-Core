"""
Banshee AI Agent skeleton.

Responsibilities:
1. Review artist submissions.
2. Approve or reject submissions on-chain.
3. Create ticket NFT listings for approved submissions.
4. Read SubQuery performance totals.
5. Trigger BANSHEE token reward minting for artists.

This is intentionally a skeleton because exact BNBAgent SDK setup depends on your local agent runtime.
"""

import os
import requests
from dotenv import load_dotenv
from web3 import Web3

load_dotenv()

BSC_RPC_URL = os.environ["BSC_TESTNET_RPC_URL"]
MARKETPLACE = os.environ["NEXT_PUBLIC_BANSHEE_MARKETPLACE"]
AGENT_PRIVATE_KEY = os.environ["AI_AGENT_PRIVATE_KEY"]
SUBQUERY_ENDPOINT = os.environ.get("SUBQUERY_ENDPOINT", "")

w3 = Web3(Web3.HTTPProvider(BSC_RPC_URL))
agent = w3.eth.account.from_key(AGENT_PRIVATE_KEY)

def fetch_subquery_performance(epoch: int):
    if not SUBQUERY_ENDPOINT:
        raise RuntimeError("Missing SUBQUERY_ENDPOINT")

    query = """
    query PerformanceByEpoch($epoch: Int!) {
      performanceRewards(where: { epoch: $epoch }) {
        id
        listingId
        artist
        playCount
      }
    }
    """

    response = requests.post(
        SUBQUERY_ENDPOINT,
        json={"query": query, "variables": {"epoch": epoch}},
        timeout=30,
    )
    response.raise_for_status()
    return response.json()

def review_submission(submission_id: int, approved: bool, review_uri: str):
    print(f"TODO: call reviewSubmission({submission_id}, {approved}, {review_uri})")

def create_listing(submission_id: int, price_wei: int, max_tickets: int, ticket_uri: str):
    print(f"TODO: call agentCreateListingFromSubmission({submission_id}, {price_wei}, {max_tickets}, {ticket_uri})")

def mint_rewards_from_subquery(epoch: int):
    totals = fetch_subquery_performance(epoch)
    print("TODO: calculate reward amounts and call mintArtistPerformanceReward", totals)

if __name__ == "__main__":
    print(f"Banshee AI Agent ready: {agent.address}")
