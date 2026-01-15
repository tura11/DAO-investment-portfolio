// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DAOTreasury is ERC20, Ownable {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error DAOTreasury__DepositTooSmall();
    error DAOTreasury__NotEnoughTokens();
    error DAOTreasury__TransferFailed();
    error DAOTreasury__InsufficientFunds();
    error DAOTreasury__InvalidAddress();
    error DAOTreasury__GovernanceAlreadySet();
    error DAOTreasury__Unauthorized();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event Deposited(address indexed member, uint256 amount, uint256 tokensReceived);
    event Withdrawn(address indexed member, uint256 tokensBurned, uint256 ethReceived);
    event TransactionExecuted(address indexed target, uint256 value, bytes data);

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 public constant MIN_DEPOSIT = 0.001 ether;

    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/
    uint256 public totalDeposits;
    address public governance;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor() ERC20("DAO Governance Token", "DAOGOV") Ownable(msg.sender) {}

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT 
    //////////////////////////////////////////////////////////////*/
    function deposit() external payable {
        if (msg.value < MIN_DEPOSIT) revert DAOTreasury__DepositTooSmall();

        
        uint256 tokensToMint = msg.value;
        totalDeposits += msg.value;

        _mint(msg.sender, tokensToMint);
        emit Deposited(msg.sender, msg.value, tokensToMint);
    }

    /*//////////////////////////////////////////////////////////////
                        WITHDRAW 
    //////////////////////////////////////////////////////////////*/
    function withdraw(uint256 tokenAmount) external {
        if (balanceOf(msg.sender) < tokenAmount) revert DAOTreasury__NotEnoughTokens();

        // Obliczenia w jednym miejscu
        uint256 contractBalance = address(this).balance;
        uint256 tokenSupply = totalSupply();
        
        if (tokenSupply == 0) revert DAOTreasury__InsufficientFunds();
        
        uint256 ethToReceive = (tokenAmount * contractBalance) / tokenSupply;
        if (ethToReceive == 0) revert DAOTreasury__InsufficientFunds();

    
        _burn(msg.sender, tokenAmount);
        totalDeposits -= ethToReceive;

    
        (bool success, ) = payable(msg.sender).call{value: ethToReceive}("");
        if (!success) revert DAOTreasury__TransferFailed();

        emit Withdrawn(msg.sender, tokenAmount, ethToReceive);
    }

    /*//////////////////////////////////////////////////////////////
                        GOVERNANCE SETUP
    //////////////////////////////////////////////////////////////*/
    function setGovernance(address _governance) external onlyOwner {
        if (_governance == address(0)) revert DAOTreasury__InvalidAddress();
        if (governance != address(0)) revert DAOTreasury__GovernanceAlreadySet();
        governance = _governance;
    }

    /*//////////////////////////////////////////////////////////////
                        TRANSACTION EXECUTION
    //////////////////////////////////////////////////////////////*/
    function executeTransaction(
        address target,
        uint256 value,
        bytes memory data
    ) external returns (bytes memory) {
        if (msg.sender != governance) revert DAOTreasury__Unauthorized();
        if (address(this).balance < value) revert DAOTreasury__InsufficientFunds();

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        if (!success) revert DAOTreasury__TransferFailed();

        emit TransactionExecuted(target, value, data);
        return returndata;
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function getTreasuryBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getTotalTokensMinted() external view returns (uint256) {
        return totalSupply();
    }
}