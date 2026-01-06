// SPDX-License-Identifier: MIT
pragma  solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {DAOTreasury} from "../src/DAOTreasury.sol";

contract DAOTreasuryTest is Test {
    DAOTreasury public treasury;
    address user1;
    address user2;

    function setUp() public {
        treasury = new DAOTreasury();

        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);

    }

    function testDeposit() public {
        vm.prank(user1);
        treasury.deposit{value: 1 ether}();
        assertEq(treasury.balanceOf(user1), 1000 ether);
        assertEq(treasury.getTreasuryBalance(), 1 ether);
        assertEq(treasury.getTotalTokensMinted(), 1000 ether);
    }

function testWithdraw() public {
    vm.prank(user1);
    treasury.deposit{value: 1 ether}();


    uint256 balanceBefore = user1.balance;
    
    vm.prank(user1);
    treasury.withdraw(500 ether);
    

    uint256 balanceAfter = user1.balance;

    // Assertions
    assertEq(treasury.balanceOf(user1), 500 ether);
    assertEq(balanceAfter - balanceBefore, 0.5 ether);
}
}
