// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "./MockTarget.sol";

contract MockTargetTest is Test {
    MockTarget target;
    address user = address(1);

    function setUp() public {
        target = new MockTarget();
        vm.deal(user, 10 ether);
    }

    function testDeposit() public {
        vm.prank(user);
        target.deposit{value: 1 ether}(1 ether);
    }


    function testSwap() public {
        vm.prank(user);
        target.swap{value: 1 ether}(1 ether);
    }

    function testStake() public {
        vm.prank(user);
        target.stake{value: 1 ether}();
    }

    function testPay() public {
        vm.prank(user);
        target.pay{value: 1 ether}(address(2), 0.5 ether);
    }

    function testSetValue() public {
        target.setValue(99);
        assertEq(target.value(), 99);
    }

    function testReceiveEthFunction() public {
        vm.prank(user);
        target.receiveEth{value: 1 ether}();
    }

    function testReceiveFallback() public {
        vm.prank(user);
        (bool ok,) = address(target).call{value: 1 ether}("");
        assertTrue(ok);
    }

    function testWithdrawRevert() public {
        vm.expectRevert();
        target.withdraw(1 ether);
    }

    function testGetCallInfo() public {
        target.setValue(1);
        target.getCallInfo();
    }
}
