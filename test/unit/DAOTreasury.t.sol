// SPDX-License-Identifier: MIT
pragma  solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IDAOTreasury} from "../../src/interfaces/IDAOTreasury.sol";
import {DAOTreasury} from "../../src/DAOTreasury.sol";

contract IDAOTreasuryTest is Test {
    IDAOTreasury public treasury;
    DAOTreasury public dao;
    address user1;
    address user2;

    function setUp() public {
        treasury = IDAOTreasury(address(new DAOTreasury()));

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
        assertEq(treasury.balanceOf(user1), 1 ether);
        assertEq(treasury.getTreasuryBalance(), 1 ether);
        assertEq(treasury.getTotalTokensMinted(), 1 ether);
    }

    function testDepositRevertIfDepositTooSmall() public {
        vm.prank(user1);
        vm.expectRevert(IDAOTreasury.DAOTreasury__DepositTooSmall.selector);
        treasury.deposit{value: 0.0001 ether}();
    }

    function testDepositEmitsEvent() public {
        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit IDAOTreasury.Deposited(user1, 1 ether, 1 ether);
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
        treasury.withdraw(0.5 ether);
        

        uint256 balanceAfter = user1.balance;

        // Assertions
        assertEq(treasury.balanceOf(user1), 0.5 ether);
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
        assertEq(treasury.balanceOf(user1), 1 ether);
        assertEq(treasury.balanceOf(user2), 2 ether);
        

        vm.prank(user1);
        treasury.withdraw(1 ether);
        

        assertEq(treasury.getTreasuryBalance(), 2 ether);
    }
    
    function testProportionalWithdrawal() public {
        vm.prank(user1);
        treasury.deposit{value: 1 ether}();
        
        vm.prank(user2);
        treasury.deposit{value: 1 ether}();
        
   
        assertEq(treasury.balanceOf(user1), 1 ether);
        assertEq(treasury.balanceOf(user2), 1 ether);
        
   
        vm.prank(user1);
        treasury.withdraw(1 ether);
        

        assertEq(treasury.getTreasuryBalance(), 1 ether);
        assertEq(treasury.balanceOf(user1), 0);
    }
    function testWithdrawRevertIfNotEnoughTokens() public {
        vm.prank(user1);
        vm.expectRevert(IDAOTreasury.DAOTreasury__NotEnoughTokens.selector);
        treasury.withdraw(1 ether);
    }
    function testWithdrawRevertIfInsufficientFunds() public {
        vm.prank(user1);
        treasury.deposit{value: 1 ether}();

        vm.deal(address(treasury), 0);

        vm.prank(user1);
        vm.expectRevert(IDAOTreasury.DAOTreasury__InsufficientFunds.selector);
        treasury.withdraw(1 ether);
    }

    function testWithdrawEmitsEvent() public {
        vm.prank(user1);
        treasury.deposit{value: 1 ether}();

        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit IDAOTreasury.Withdrawn(user1, 1 ether, 1 ether);
        treasury.withdraw(1 ether);
    }

    function testWithdrawRevertIfTransferFails() public {
    RevertingReceiver receiver = new RevertingReceiver(treasury);
    vm.deal(address(receiver), 1 ether);

    vm.expectRevert(IDAOTreasury.DAOTreasury__TransferFailed.selector);
    receiver.depositAndWithdraw();
    }

   function testWithdrawWhenProfitExceedsTotalDeposits() public {

        vm.prank(user1);
        treasury.deposit{value: 1 ether}();
        
  
        assertEq(treasury.totalDeposits(), 1 ether);
        assertEq(address(treasury).balance, 1 ether);
        
       
        vm.deal(address(treasury), 11 ether); 
        
   
        assertEq(treasury.totalDeposits(), 1 ether);
        assertEq(address(treasury).balance, 11 ether);
        
    
        uint256 user1BalanceBefore = user1.balance;
        
        vm.prank(user1);
        treasury.withdraw(1 ether); 
        
 
        uint256 ethReceived = user1.balance - user1BalanceBefore;
        assertEq(ethReceived, 11 ether);
       
        assertEq(treasury.totalDeposits(), 0);
        
     
        assertEq(address(treasury).balance, 0);
    }


     //////////////////////////////
    //   SET GOVERNANCE TESTS    //
    //////////////////////////////


    function testSetGovernanceRevertIfInvalidAddress() public {
        vm.prank(address(this));
        vm.expectRevert(IDAOTreasury.DAOTreasury__InvalidAddress.selector);
        treasury.setGovernance(address(0));
    }

    function testSetGovernanceRevertIfAlreadySet() public {
        address target = 0x0000000000000000000000000000000000000001;
        address target2 = 0x0000000000000000000000000000000000000002;
        vm.prank(address(this));
        treasury.setGovernance(target);
        vm.expectRevert(IDAOTreasury.DAOTreasury__GovernanceAlreadySet.selector);
        treasury.setGovernance(target2);
    }


    function testSetGovernanceSuccesful() public {
        vm.prank(address(this));
        address target = 0x0000000000000000000000000000000000000001;
        treasury.setGovernance(target);
        assertEq(treasury.governance(), target);
    }


     //////////////////////////////
    //  EXECUTE PROPOSAL TESTS   //
    //////////////////////////////


    function testExecuteProposalRevertIfUnauthorized() public {
        address target = 0x0000000000000000000000000000000000000001;
        vm.prank(user1);
        vm.expectRevert(IDAOTreasury.DAOTreasury__Unauthorized.selector);
        treasury.executeTransaction(target, 1 ether,"");
    }

    function testExecuteProposalRevertIfInsufficientFunds() public {
        address target = 0x0000000000000000000000000000000000000001;
        vm.prank(address(this));
        treasury.setGovernance(address(this));
        vm.expectRevert(IDAOTreasury.DAOTreasury__InsufficientFunds.selector);
        treasury.executeTransaction(target, 1 ether,"");
    }

    function testExecuteProposalRevertIfTransactionFailed() public {
    RevertingTarget target = new RevertingTarget();

    treasury.setGovernance(address(this));
    vm.deal(address(treasury), 1 ether);

    vm.expectRevert(IDAOTreasury.DAOTreasury__ExecutionFailed.selector);

    treasury.executeTransaction(
        address(target),
        0,
        abi.encodeWithSelector(RevertingTarget.boom.selector)
    );

    }
}

contract RevertingTarget {
    function boom() external payable {
        revert("boom");
    }
}

contract RevertingReceiver {
    IDAOTreasury treasury;

    constructor(IDAOTreasury _treasury) {
        treasury = _treasury;
    }

    receive() external payable {
        revert("no ETH accepted");
    }

    function depositAndWithdraw() external {
        treasury.deposit{value: 1 ether}();
        treasury.withdraw(1 ether);
    }
}