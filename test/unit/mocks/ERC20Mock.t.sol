// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "./ERC20Mock.sol";

contract ERC20MockTest is Test {
    ERC20Mock token;
    address user = address(1);

    function setUp() public {
        token = new ERC20Mock("Mock", "MOCK");
    }

    function testMint() public {
        token.mint(user, 100 ether);
        assertEq(token.balanceOf(user), 100 ether);
    }
}
