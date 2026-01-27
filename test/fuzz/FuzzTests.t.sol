
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {DAOTreasury} from "../../src/DAOTreasury.sol";
import {DAOGovernance} from "../../src/DAOGovernance.sol";
import {MockTarget} from "../unit/mocks/MockTarget.sol";


contract FuzzTests is Test {
    DAOTreasury public treasury;
    DAOGovernance public governance;
    MockTarget public target;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        treasury = new DAOTreasury();
        governance = new DAOGovernance(address(treasury));
        treasury.setGovernance(address(governance));
        target = new MockTarget();

        vm.deal(alice, 1000 ether);
        vm.deal(bob, 1000 ether);
    }

     /*//////////////////////////////////////////////////////////////
                        TREASURY FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    // @notice Fuzz: Deposit always mints correct tokens (1:1 ratio)
    function testFuzz_Deposit_MintsCorrectTokens(uint256 amount) public {
        
        amount = bound(amount, treasury.MIN_DEPOSIT(), 100 ether);

        vm.deal(alice, amount);

        uint256 balanceBefore = treasury.balanceOf(alice);

        vm.prank(alice);
        treasury.deposit{value: amount}();

        uint256 balanceAfter = treasury.balanceOf(alice);
        assertEq(balanceAfter - balanceBefore, amount);
        

    }


}