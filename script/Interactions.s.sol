// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {DAOTreasury} from "../src/DAOTreasury.sol";
import {DAOGovernance} from "../src/DAOGovernance.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";


contract DepositToTreasury is Script {
    function depositToTreasury(address treasuryAddress, uint256 amount) public {
        vm.startBroadcast();
        DAOTreasury treasury = DAOTreasury(payable(treasuryAddress));
        treasury.deposit{value: amount}();
        vm.stopBroadcast();
        console.log("Deposited %s ETH to treasury at %s", amount, treasuryAddress);
    } 

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("DAOTreasury", block.chainid);
        depositToTreasury(mostRecentlyDeployed, 1 ether);
    }  


}