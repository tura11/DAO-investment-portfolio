// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "forge-std/Script.sol";
import {DAOTreasury} from "../src/DAOTreasury.sol";
import {DAOGovernance} from "../src/DAOGovernance.sol";


contract Deploy is Script{
    function deploy() public {
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

        vm.startBroadcast(deployerPrivateKey);

        DAOTreasury terasury = new DAOTreasury();
        DAOGovernance governance = new DAOGovernance(address(terasury));

        vm.stopBroadcast();

        console.log("===========================================");
        console.log("LOCAL DEPLOY (Anvil) - SUCCESS!");
        console.log("===========================================");
        console.log("DAOTreasury Address:     ", address(treasury));
        console.log("DAOGovernance Address:  ", address(governance));
        console.log("===========================================");


    }
}