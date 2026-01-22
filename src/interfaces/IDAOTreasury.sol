// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IDAOTreasury {
    // Events
    event Deposited(address indexed member, uint256 amount, uint256 tokensReceived);
    event Withdrawn(address indexed member, uint256 tokensBurned, uint256 ethReceived);
    event GovernanceSet(address indexed governance);
    event TransactionExecuted(address indexed target, uint256 value, bytes data);

    // Errors
    error DAOTreasury__DepositTooSmall();
    error DAOTreasury__NotEnoughTokens();
    error DAOTreasury__TransferFailed();
    error DAOTreasury__InsufficientFunds();
    error DAOTreasury__InvalidAddress();
    error DAOTreasury__GovernanceAlreadySet();
    error DAOTreasury__Unauthorized();
    error DAOTreasury__ExecutionFailed();

    // Functions
    function deposit() external payable;
    function withdraw(uint256 tokenAmount) external;
    function setGovernance(address _governance) external;
    function executeTransaction(
        address target,
        uint256 value,
        bytes memory data
    ) external returns (bytes memory returnData);
    
    // View functions
    function getTreasuryBalance() external view returns (uint256);
    function getTotalTokensMinted() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}