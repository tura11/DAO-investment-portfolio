// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DAOTreasury is ERC20, Ownable {

    error DAOTreasury__DepositTooSmall();
    error DAOTreasury__NotEnoughTokens();
    error DAOTreasury__TransferFailed();
    error DAOTreasury__InsufficientFunds();
    error DAOTreasury__InvalidAddress();
    error DAOTreasury__GovernanceAlreadySet();
    error DAOTreasury__Unauthorized();

    event TransactionExecuted(
        address indexed target,
        uint256 value,
        bytes data
    );

    uint256 public constant MIN_DEPOSIT = 0.001 ether;

    uint256 public totalDeposits;
    address public governance;

    event Deposited(address indexed member, uint256 amount, uint256 tokensReceived);
    event Withdrawn(address indexed member, uint256 tokensBurned, uint256 ethReceived);

    constructor() ERC20("DAO Governance Token", "DAOGOV") Ownable(msg.sender) {}


    function deposit() external  payable {
        if(msg.value < MIN_DEPOSIT) {
            revert DAOTreasury__DepositTooSmall();
        }

        uint256 tokensToMint = msg.value * 1000; // 1eth = 1000 tokens

        totalDeposits += msg.value;


        _mint(msg.sender, tokensToMint);

        emit Deposited(msg.sender, msg.value, tokensToMint);
    }


    function withdraw(uint256 tokenAmount) external {
        if(balanceOf(msg.sender) < tokenAmount) {
            revert DAOTreasury__NotEnoughTokens();
        }


        uint256 ethToReceive = (tokenAmount * address(this).balance) / totalSupply(); // calcualte based on defi strategy if defi earn 0.5eth and user1 has 1000 tokens, he should receive 1.5 eth

        if(ethToReceive == 0) {
            revert DAOTreasury__InsufficientFunds();
        }

        _burn(msg.sender, tokenAmount);


        totalDeposits -= ethToReceive;

        (bool success, ) = payable(msg.sender).call{value: ethToReceive}("");
        if(!success) {
            revert DAOTreasury__TransferFailed();
        }

         emit Withdrawn(msg.sender, tokenAmount, ethToReceive);
    }


    function setGovernance(address _governance) external onlyOwner {
        if(_governance == address(0)) {
            revert DAOTreasury__InvalidAddress();
        }

        if(_governance == address(this)) {
            revert DAOTreasury__GovernanceAlreadySet();
            
        }

        governance = _governance;
    }

    function executeTransaction(address target, uint256 value, bytes memory data) external returns (bytes memory) {
        if(msg.sender != governance) {
            revert DAOTreasury__Unauthorized();
        }
        if(address(this).balance < value) {
            revert DAOTreasury__InsufficientFunds();
        }

        (bool success, bytes memory returndata) = target.call{value: value}(data);

        if(!success) {
            revert DAOTreasury__TransferFailed();
        }

        emit TransactionExecuted(target, value, data);

        return returndata;
    }


    function getTreasuryBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getTotalTokensMinted() external view returns (uint256) {
        return totalSupply();
    }

}