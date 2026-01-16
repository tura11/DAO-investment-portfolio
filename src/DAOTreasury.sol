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
    error DAOTreasury__ExecutionFailed();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 public constant MIN_DEPOSIT = 0.001 ether;
    uint256 public totalDeposits;
    address public governance;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event Deposited(address indexed member, uint256 amount, uint256 tokensReceived);
    event Withdrawn(address indexed member, uint256 tokensBurned, uint256 ethReceived);
    event GovernanceSet(address indexed governance);
    event TransactionExecuted(address indexed target, uint256 value, bytes data);

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor() ERC20("DAO Governance Token", "DAOGOV") Ownable(msg.sender) {}

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT & WITHDRAW
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Deposit ETH and receive governance tokens (1:1 ratio)
    function deposit() external payable {
        if (msg.value < MIN_DEPOSIT) {
            revert DAOTreasury__DepositTooSmall();
        }

        // 1:1 ratio - 1 ETH = 1 governance token
        uint256 tokensToMint = msg.value;

        totalDeposits += msg.value;
        _mint(msg.sender, tokensToMint);

        emit Deposited(msg.sender, msg.value, tokensToMint);
    }

    /// @notice Withdraw ETH by burning governance tokens
    /// @param tokenAmount Amount of tokens to burn
    function withdraw(uint256 tokenAmount) external {
        if (balanceOf(msg.sender) < tokenAmount) {
            revert DAOTreasury__NotEnoughTokens();
        }

        // Calculate proportional ETH to return
        uint256 ethToReceive = (tokenAmount * address(this).balance) / totalSupply();

        if (ethToReceive == 0) {
            revert DAOTreasury__InsufficientFunds();
        }

        // CEI Pattern
        _burn(msg.sender, tokenAmount);

        if (totalDeposits >= ethToReceive) {
            totalDeposits -= ethToReceive;
        } else {
            totalDeposits = 0;
        }

        (bool success,) = payable(msg.sender).call{value: ethToReceive}("");
        if (!success) {
            revert DAOTreasury__TransferFailed();
        }

        emit Withdrawn(msg.sender, tokenAmount, ethToReceive);
    }

    /*//////////////////////////////////////////////////////////////
                        GOVERNANCE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Set governance contract (one time only)
    /// @param _governance Address of governance contract
    function setGovernance(address _governance) external onlyOwner {
        if (_governance == address(0)) {
            revert DAOTreasury__InvalidAddress();
        }
        if (governance != address(0)) {
            revert DAOTreasury__GovernanceAlreadySet();
        }

        governance = _governance;
        emit GovernanceSet(_governance);
    }

    /// @notice Execute a transaction (only governance)
    /// @param target Target contract address
    /// @param value Amount of ETH to send
    /// @param data Encoded function call
    /// @return returnData Return data from the call
    function executeTransaction(
        address target,
        uint256 value,
        bytes memory data
    ) external returns (bytes memory returnData) {
        if (msg.sender != governance) {
            revert DAOTreasury__Unauthorized();
        }
        if (address(this).balance < value) {
            revert DAOTreasury__InsufficientFunds();
        }

        (bool success, bytes memory result) = target.call{value: value}(data);

        if (!success) {
            revert DAOTreasury__ExecutionFailed();
        }

        emit TransactionExecuted(target, value, data);

        return result;
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Get treasury ETH balance
    function getTreasuryBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /// @notice Get total tokens minted
    function getTotalTokensMinted() external view returns (uint256) {
        return totalSupply();
    }
}