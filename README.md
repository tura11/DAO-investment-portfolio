# DAO Governance & Treasury System

A fully on-chain DAO governance system built in Solidity using **Foundry**.

This project demonstrates token-weighted voting, proposal creation & execution, and secure ETH treasury management.

## ✨ Features

### 🔐 Treasury (DAOTreasury)
- ETH-backed treasury
- 1:1 minting of governance tokens for deposited ETH
- Burn tokens to withdraw proportional ETH
- Only DAO can execute transactions from the treasury
- Immutable governance contract address

### 🗳️ Governance (DAOGovernance)
- Token-weighted voting (For / Against / Abstain)
- Proposals with arbitrary calldata + ETH value
- Configurable quorum and approval thresholds
- 2-day timelock before execution
- Proposal cancellation (before voting ends)
- On-chain execution through the treasury

## 🧠 Default Governance Parameters

| Parameter                        | Value      |
|----------------------------------|------------|
| Voting period                    | 7 days     |
| Timelock duration                | 2 days     |
| Quorum                           | 30%        |
| Approval threshold               | 51%        |
| Minimum tokens to create proposal| 0.01 ETH   |

## Token
- **DAOGOV** – ERC20 token

## 🔄 Governance Flow
1. Users deposit ETH into **DAOTreasury**
2. Governance tokens are minted 1:1
3. Token holders create proposals (with calldata + optional ETH)
4. Token holders vote (weighted by balance)
5. After 7 days → proposal is finalized if quorum and threshold met
6. After additional 2-day timelock → proposal can be executed
7. Execution calls are forwarded to the treasury contract

## 📁 Project Structure
src/
├── DAOGovernance.sol
├── DAOTreasury.sol
└── interfaces/
└── IDAOTreasury.sol
script/
├── Deploy.s.sol
├── HelperConfig.s.sol
└── Interactions.s.sol
test/
├── DAOGovernance.t.sol
├── DAOTreasury.t.sol
└── mocks/
├── ERC20Mock.sol
└── MockTargetContract.sol
text## 🧪 Testing
- Written with **Foundry**
- 100% test coverage
- Tests cover:
  - Deposits & withdrawals
  - Voting logic (For/Against/Abstain)
  - Quorum & threshold enforcement
  - Timelock & execution
  - Reverts & edge cases