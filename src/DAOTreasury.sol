// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DAOTreasury is ERC20, Ownable {

    error DAOTreasury__DepositTooSmall();
    error DAOTreasury__NotEnoughTokens();
    error DAOTreasury__TransferFailed();
    error DAOTreasury__InsufficientFunds();

    uint256 public constant MIN_DEPOSIT = 0.001 ether;

    uint256 totalDeposits;

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


    function getTreasuryBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getTotalTokensMinted() external view returns (uint256) {
        return totalSupply();
    }

}