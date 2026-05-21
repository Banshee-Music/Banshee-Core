include .env

install:
	forge install foundry-rs/forge-std
	forge install OpenZeppelin/openzeppelin-contracts@v5.4.0

build:
	forge build

test:
	forge test -vvv

deploy-testnet:
	forge script script/DeployProofOfPerformance.s.sol \
		--rpc-url $(BSC_TESTNET_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast

deploy-testnet-verify:
	forge script script/DeployProofOfPerformance.s.sol \
		--rpc-url $(BSC_TESTNET_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--verify
