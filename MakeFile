-include .env

.PHONY: all test clean deploy help install format anvil snapshot coverage

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

help:
	@echo "Usage:"
	@echo "  make deploy-anvil          - Deploy to local Anvil chain"
	@echo "  make deploy-sepolia        - Deploy to Sepolia testnet"
	@echo "  make test                  - Run all tests"
	@echo "  make test-unit             - Run unit tests only"
	@echo "  make test-integration      - Run integration tests only"
	@echo "  make coverage              - Generate coverage report"
	@echo "  make deposit               - Deposit ETH to treasury"
	@echo "  make create-proposal       - Create a new proposal"
	@echo "  make vote-for              - Vote FOR on proposal 0"
	@echo "  make info-proposal         - Get proposal info"
	@echo "  make info-treasury         - Get treasury info"

# ================================================================
# │                    BUILD & SETUP                             │
# ================================================================

all: clean remove install update build

clean:
	@forge clean

remove:
	@rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install:
	@forge install Cyfrin/foundry-devops --no-commit
	@forge install OpenZeppelin/openzeppelin-contracts --no-commit

update:
	@forge update

build:
	@forge build

snapshot:
	@forge snapshot

format:
	@forge fmt

anvil:
	@anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

# ================================================================
# │                    TESTING                                   │
# ================================================================

test:
	@forge test -vv

test-unit:
	@forge test --match-path test/unit/* -vvv

test-integration:
	@forge test --match-path test/integration/* -vvv

test-mocks:
	@forge test --match-path test/unit/mocks/* -vvv

test-gas:
	@forge test --gas-report

coverage:
	@forge coverage

coverage-report:
	@forge coverage --report summary

coverage-lcov:
	@forge coverage --report lcov

# ================================================================
# │                    DEPLOYMENT                                │
# ================================================================

deploy-anvil:
	@echo "Deploying to Anvil..."
	@forge script script/Deploy.s.sol:Deploy --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast -vvvv

deploy-sepolia:
	@echo "Deploying to Sepolia..."
	@forge script script/Deploy.s.sol:Deploy --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv

deploy-mainnet:
	@echo "Deploying to Mainnet..."
	@forge script script/Deploy.s.sol:Deploy --rpc-url $(MAINNET_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv

# ================================================================
# │                    INTERACTIONS (ANVIL)                      │
# ================================================================

deposit:
	@forge script script/Interactions.s.sol:DepositToTreasury --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

withdraw:
	@forge script script/Interactions.s.sol:WithdrawFromTreasury --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

create-proposal:
	@forge script script/Interactions.s.sol:CreateProposal --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

vote-for:
	@forge script script/Interactions.s.sol:VoteOnProposal --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

finalize:
	@forge script script/Interactions.s.sol:FinalizeProposal --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

execute:
	@forge script script/Interactions.s.sol:ExecuteProposal --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

cancel:
	@forge script script/Interactions.s.sol:CancelProposal --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

info-proposal:
	@forge script script/Interactions.s.sol:GetProposalInfo --rpc-url http://localhost:8545

info-treasury:
	@forge script script/Interactions.s.sol:GetTreasuryInfo --rpc-url http://localhost:8545

# ================================================================
# │                    INTERACTIONS (SEPOLIA)                    │
# ================================================================

deposit-sepolia:
	@forge script script/Interactions.s.sol:DepositToTreasury --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast

create-proposal-sepolia:
	@forge script script/Interactions.s.sol:CreateProposal --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast

vote-for-sepolia:
	@forge script script/Interactions.s.sol:VoteOnProposal --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast

info-proposal-sepolia:
	@forge script script/Interactions.s.sol:GetProposalInfo --rpc-url $(SEPOLIA_RPC_URL)

info-treasury-sepolia:
	@forge script script/Interactions.s.sol:GetTreasuryInfo --rpc-url $(SEPOLIA_RPC_URL)