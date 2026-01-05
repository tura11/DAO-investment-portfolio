// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DAOTreasury is ERC20, Ownable {

    error DAOTreasury__DepositTooSmall();

    uint256 public constant MIN_DEPOSIT = 0.001 ether;

    uint256 totalDeposits;

    uint256 totalTokensMinted;

    event Deposited(address indexed member, uint256 amount, uint256 tokensReceived);
    event Withdrawn(address indexed member, uint256 tokensBurned, uint256 ethReceived);

    constructor() ERC20("DAO Governance Token", "DAOGOV") Ownable(msg.sender) {}


    function deposit() external  payable {
        if(msg.value < MIN_DEPOSIT) {
            revert DepositToDAOTreasury__DepositTooSmalloSmall();
        }
        uint256 tokensToMint = msg.value * 1000;
        totalDeposits += msg.value;
        totalTokensMinted += tokensToMint;
        _mint(msg.sender, tokensToMint);

        emit Deposited(msg.sender, msg.value, tokensToMint);
    }




}