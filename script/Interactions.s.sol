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


contract WithdrawFromTreasury is Script {
    function withdrawFromTreasury(address treasuryAddress, uint256 tokenAmount) public {
        vm.startBroadcast();
        DAOTreasury treasury = DAOTreasury(payable(treasuryAddress));
        treasury.withdraw(tokenAmount);
        vm.stopBroadcast();
        console.log("Withdrew %s tokens from treasury at %s", tokenAmount, treasuryAddress);
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("DAOTreasury", block.chainid);
        withdrawFromTreasury(mostRecentlyDeployed, 1 ether);
    }
}


contract CreateProposal is Script {
    function createProposal(
        address governanceAddress,
        string memory title,
        string memory description,
        address targetContract,
        bytes memory callData,
        uint256 ethAmount
    ) public returns (uint256) {
        vm.startBroadcast();
        DAOGovernance governance = DAOGovernance(governanceAddress);
        
        DAOGovernance.ProposalParams memory params = DAOGovernance.ProposalParams({
            title: title,
            description: description,
            targetContract: targetContract,
            callData: callData,
            ethAmount: ethAmount
        });
        
        uint256 proposalId = governance.createProposal(params);
        vm.stopBroadcast();
        
        console.log("Created proposal #%s: %s", proposalId, title);
        return proposalId;
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("DAOGovernance", block.chainid);
        
        address recipient = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        bytes memory callData = "";

        createProposal(
            mostRecentlyDeployed,
            "Fund Community Initiative",
            "Proposal to allocate 1 ETH for community development",
            recipient,
            callData,
            1 ether
            );
    }
}   