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
    //////////////////////////////
    //      TESTING DEPOSIT     //
    //////////////////////////////

    function testDeposit() public {
        vm.prank(user1);
        treasury.deposit{value: 1 ether}();
        assertEq(treasury.balanceOf(user1), 1000 ether);
        assertEq(treasury.getTreasuryBalance(), 1 ether);
        assertEq(treasury.getTotalTokensMinted(), 1000 ether);
    }

    function testDepositRevertIfDepositTooSmall() public {
        vm.prank(user1);
        vm.expectRevert(DAOTreasury.DAOTreasury__DepositTooSmall.selector);
        treasury.deposit{value: 0.0001 ether}();
    }

    function testDepositEmitsEvent() public {
        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit DAOTreasury.Deposited(user1, 1 ether, 1000 ether);
        treasury.deposit{value: 1 ether}();
    }

     //////////////////////////////
    //      TESTING WITHDRAW    //
    //////////////////////////////
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


     function testMultipleDepositsAndWithdrawals() public {
   
        vm.prank(user1);
        treasury.deposit{value: 1 ether}();
        
     
        vm.prank(user2);
        treasury.deposit{value: 2 ether}();
        
        // Total: 3 ETH in treasury
        // user1 has: 1000 tokens (33.33%)
        // user2 has: 2000 tokens (66.67%)
        
        assertEq(treasury.getTreasuryBalance(), 3 ether);
        assertEq(treasury.balanceOf(user1), 1000 ether);
        assertEq(treasury.balanceOf(user2), 2000 ether);
        

        vm.prank(user1);
        treasury.withdraw(1000 ether);
        

        assertEq(treasury.getTreasuryBalance(), 2 ether);
    }
    
    function testProportionalWithdrawal() public {
        vm.prank(user1);
        treasury.deposit{value: 1 ether}();
        
        vm.prank(user2);
        treasury.deposit{value: 1 ether}();
        
   
        assertEq(treasury.balanceOf(user1), 1000 ether);
        assertEq(treasury.balanceOf(user2), 1000 ether);
        
   
        vm.prank(user1);
        treasury.withdraw(1000 ether);
        

        assertEq(treasury.getTreasuryBalance(), 1 ether);
        assertEq(treasury.balanceOf(user1), 0);
    }
    function testWithdrawRevertIfNotEnoughTokens() public {
        vm.prank(user1);
        vm.expectRevert(DAOTreasury.DAOTreasury__NotEnoughTokens.selector);
        treasury.withdraw(1 ether);
    }
    function testWithdrawRevertIfInsufficientFunds() public {
        vm.prank(user1);
        treasury.deposit{value: 1 ether}();

        vm.deal(address(treasury), 0);

        vm.prank(user1);
        vm.expectRevert(DAOTreasury.DAOTreasury__InsufficientFunds.selector);
        treasury.withdraw(1000 ether);
    }

    function testWithdrawEmitsEvent() public {
        vm.prank(user1);
        treasury.deposit{value: 1 ether}();

        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit DAOTreasury.Withdrawn(user1, 1000 ether, 1 ether);
        treasury.withdraw(1000 ether);
    }

    function testWithdrawRevertIfTransferFails() public {
    RevertingReceiver receiver = new RevertingReceiver(treasury);
    vm.deal(address(receiver), 1 ether);

    vm.expectRevert(DAOTreasury.DAOTreasury__TransferFailed.selector);
    receiver.depositAndWithdraw();
}

}

contract RevertingReceiver {
    DAOTreasury treasury;

    constructor(DAOTreasury _treasury) {
        treasury = _treasury;
    }

    receive() external payable {
        revert("no ETH accepted");
    }

    function depositAndWithdraw() external {
        treasury.deposit{value: 1 ether}();
        treasury.withdraw(1000 ether);
    }
}