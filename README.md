🏛️ DAO Governance & Treasury System
A fully on-chain DAO governance system built in Solidity using Foundry.
The project demonstrates token-weighted voting, proposal execution, and secure treasury management.

✨ Features
🔐 Treasury (DAOTreasury)
ETH-based treasury
1:1 ETH → governance token minting
Token burning for proportional ETH withdrawals
DAO-only transaction execution
Immutable governance assignment
🗳️ Governance (DAOGovernance)
Token-weighted voting (For / Against / Abstain)
Proposal creation with calldata + ETH value
Quorum & approval thresholds
Timelock before execution
Proposal cancellation logic
Fully on-chain execution via treasury
🧠 Governance Rules
Parameter	Value
Voting period	7 days
Timelock	2 days
Quorum	30%
Approval threshold	51%
Min tokens to propose	0.01 ETH
Token	DAOGOV (ERC20)
🔄 Governance Flow
Users deposit ETH into DAOTreasury
Governance tokens are minted (1:1)
Token holders create proposals
DAO votes using token-weighted voting
Proposal is finalized
Successful proposals are executed via treasury
📁 Project Structure
src/ ├── DAOGovernance.sol ├── DAOTreasury.sol └── interfaces/ └── IDAOTreasury.sol

script/ ├── Deploy.s.sol ├── HelperConfig.s.sol └── Interactions.s.sol

test/ ├── DAOGovernance.t.sol ├── DAOTreasury.t.sol └── mocks/ ├── ERC20Mock.sol └── MockTargetContract.sol

🧪 Testing
Built with Foundry
100% test coverage
Includes mocks for:
ERC20 token interactions
External target execution
Covers:
Deposits & withdrawals
Voting logic
Quorum & thresholds
Timelock execution
Failure & revert scenarios
Run tests:

forge test -vvvv
forge coverage
