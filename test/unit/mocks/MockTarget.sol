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

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    
    event FunctionCalled(address indexed caller, uint256 value, bytes data);
    event EthReceived(address indexed sender, uint256 amount);
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Swapped(address indexed user, uint256 amountIn, uint256 amountOut);
    event Staked(address indexed user, uint256 amount);//


    /*//////////////////////////////////////////////////////////////
                        AAVE-LIKE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Simulate Aave deposit (supply)
    /// @dev Real Aave: function supply(address asset, uint256 amount, address onBehalfOf)
    function supply(address asset, uint256 amount, address onBehalfOf) external payable {
        callCount++;
        lastCaller = msg.sender;
        lastCallData = msg.data;

        deposits[onBehalfOf] += amount;
        totalEthReceived += msg.value;

        tokenBalances[onBehalfOf] += amount;


        emit Deposited(onBehalfOf, amount);
        emit FunctionCalled(msg.sender, amount, msg.data);  
    }

}