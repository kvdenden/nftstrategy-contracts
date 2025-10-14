-include .env

.PHONY: clean test anvil deploy-punks deploy send-eth send-token approve

RPC_URL ?= http://localhost:8545
FORK_URL ?=
FORK_BLOCK_NUMBER ?=

clean :; forge clean

test :; forge test

anvil :; anvil --chain-id 31337 --block-time 12 --auto-impersonate
anvil-fork :; anvil --fork-url $(FORK_URL) --fork-block-number $(FORK_BLOCK_NUMBER) --chain-id 31337 --block-time 12 --auto-impersonate

# Local development deploys
deploy-nft :; forge script script/DeployNFT.s.sol:DeployNFT --rpc-url $(RPC_URL) --private-key $(PRIVATE_KEY) --broadcast

# Main deploy/setup scripts
deploy :; forge script script/Deploy.s.sol:Deploy --rpc-url $(RPC_URL) --private-key $(PRIVATE_KEY) --broadcast
deploy-sepolia :; @forge script script/Deploy.s.sol:Deploy --rpc-url sepolia --private-key $(PRIVATE_KEY) --broadcast --verify --slow
deploy-mainnet :; @forge script script/Deploy.s.sol:Deploy --rpc-url mainnet --private-key $(PRIVATE_KEY) --broadcast --verify --slow

# Export contract ABIs
export-abis :; jq '.abi' out/Strategy.sol/Strategy.json > Strategy.json && jq '.abi' out/StrategyToken.sol/StrategyToken.json > StrategyToken.json

# Convenience casting
from ?= 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
to ?=
amount ?= 1
TOKEN ?=
spender ?=

send-eth :; @cast send $(to) --from $(from) --value $(shell cast to-wei $(amount)) --unlocked --rpc-url $(RPC_URL)

send-token :; @cast send $(TOKEN) --from $(from) "transfer(address,uint256)(bool)" $(to) $(amount) --unlocked --rpc-url $(RPC_URL)

approve :; @cast send $(TOKEN) --from $(from) "approve(address,uint256)(bool)" $(spender) $(amount) --unlocked --rpc-url $(RPC_URL)


