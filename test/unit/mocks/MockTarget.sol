// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


/// @notice Mock contract simulating DeFi protocols (Aave, Uniswap, Lido, etc.)
/// @dev Used to test DAO proposals that interact with external contracts
contract MockTarget {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    // Track what was called
    uint256 public callCount;
    address public lastCaller;
    uint256 public totalEthReceived;
    bytes public lastCallData;

    // Simulate protocol state
    uint256 public value;
    mapping(address => uint256) public deposits;             // Simulate Aave deposits
    mapping(address => uint256) public stakes;               // Simulate Lido stakes
    mapping(address => uint256) public liquidityProvided;    // Simulate Uniswap LP

    mapping(address => uint256) public tokenBalance;         // Simulate token balances

    
}