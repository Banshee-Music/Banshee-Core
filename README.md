# Banshee Proof-of-Performance

Banshee is a Proof-of-Performance music marketplace for AI-agent managed music access.

## Flow

```text
Artist registers
→ BNB AI Agent verifies artist
→ Artist submits Greenfield-hosted song/album/event
→ BNB AI Agent reviews submission
→ Agent posts ticket NFT listing
→ Fan buys or receives ticket in MetaMask
→ Fan requests Greenfield access
→ Banshee/agent/relayer grants Greenfield access
→ SubQuery indexes play/access events
→ Agent mints BANSHEE rewards to artist
```

## Contracts

- `BansheeToken.sol` — ERC-20 artist reward token.
- `BansheeTicketNFT.sol` — ERC-721 access tickets.
- `BansheeProofOfPerformance.sol` — registry, marketplace, ticket airdrops, play tracking, rewards.

## Install

```bash
forge install foundry-rs/forge-std
forge install OpenZeppelin/openzeppelin-contracts@v5.4.0
```

## Build and test

```bash
forge build
forge test -vvv
```

## Deploy

```bash
cp .env.example .env
# edit .env

forge script script/DeployProofOfPerformance.s.sol \
  --rpc-url $BSC_TESTNET_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast
```

## Greenfield

Greenfield is the source of truth for protected music files.

Each submission must include:

- `greenfieldBucket`
- `greenfieldObject`
- `greenfieldGroup`

The contract emits `GreenfieldAccessRequested`. Your backend/agent should listen for that event and update Greenfield group membership or object policy for the ticket holder.

## Proof-of-Performance

The MVP proof loop uses:

- ticket ownership
- Banshee player events
- Greenfield access/session evidence
- agent-submitted `PerformanceRecorded` events
- SubQuery indexed totals
- agent-triggered `PerformanceRewardMinted`
