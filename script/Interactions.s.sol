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



contract VoteOnProposal is Script{
    function voteOnProposal(
        address governanceAddress,
        uint256 proposalId,
        DAOGovernance.VoteType voteType
    ) public {
        vm.startBroadcast();
        DAOGovernance governance = DAOGovernance(governanceAddress);
        governance.vote(proposalId, voteType);
        vm.stopBroadcast();

        string memory voteTypeStr = voteType == DAOGovernance.VoteType.For ? "FOR" :
                                                voteType == DAOGovernance.VoteType.Against ? "AGAINST" : "ABSTAIN";
        console.log("Voted %s on proposal #%s", voteTypeStr, proposalId);
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("DAOGovernance", block.chainid);
        voteOnProposal(mostRecentlyDeployed, 0, DAOGovernance.VoteType.For);
    }
}


contract FinalizeProposal is Script {
    function finalizeProposal(address governanceAddress, uint256 proposalId) public {
        vm.startBroadcast();
        DAOGovernance governance = DAOGovernance(governanceAddress);
        governance.finalizeProposal(proposalId);
        vm.stopBroadcast();
        console.log("Finalized proposal #%s", proposalId);
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("DAOGovernance", block.chainid);
        finalizeProposal(mostRecentlyDeployed, 0);
    }
}


contract ExecuteProposal is Script {
    function executeProposal(address governanceAddress, uint256 proposalId) public {
        vm.startBroadcast();
        DAOGovernance governance = DAOGovernance(governanceAddress);
        governance.executeProposal(proposalId);
        vm.stopBroadcast();
        console.log("Executed proposal #%s", proposalId);
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("DAOGovernance", block.chainid);
        executeProposal(mostRecentlyDeployed, 0);
    }
}

contract CancelProposal is Script {
    function cancelProposal(address governanceAddress, uint256 proposalId) public {
        vm.startBroadcast();
        DAOGovernance governance = DAOGovernance(governanceAddress);
        governance.cancelProposal(proposalId);
        vm.stopBroadcast();
        console.log("Canceled proposal #%s", proposalId);
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("DAOGovernance", block.chainid);
        cancelProposal(mostRecentlyDeployed, 0);
    }
}


contract GetProposalInfo is Script {
    function getProposalInfo(address governanceAddress, uint256 proposalId) public view {
        DAOGovernance governance = DAOGovernance(governanceAddress);
        DAOGovernance.ProposalView memory proposal = governance.getProposal(proposalId);
        
        console.log("===========================================");
        console.log("PROPOSAL #%s", proposalId);
        console.log("===========================================");
        console.log("Title:        %s", proposal.title);
        console.log("Description:  %s", proposal.description);
        console.log("Proposer:     %s", proposal.proposer);
        console.log("Target:       %s", proposal.targetContract);
        console.log("ETH Amount:   %s", proposal.ethAmount);
        console.log("-------------------------------------------");
        console.log("Votes For:     %s", proposal.votesFor);
        console.log("Votes Against: %s", proposal.votesAgainst);
        console.log("Votes Abstain: %s", proposal.votesAbstain);
        console.log("-------------------------------------------");
        console.log("Start Time:    %s", proposal.startTime);
        console.log("End Time:      %s", proposal.endTime);
        console.log("Execution:     %s", proposal.executionTime);
        console.log("State:         %s", uint256(proposal.state));
        console.log("===========================================");
    }

    function run() external view {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("DAOGovernance", block.chainid);
        getProposalInfo(mostRecentlyDeployed, 0);
    }
}

contract GetTreasuryInfo is Script {
    function getTreasuryInfo(address treasuryAddress) public view {
        DAOTreasury treasury = DAOTreasury(payable(treasuryAddress));
        
        console.log("===========================================");
        console.log("TREASURY INFO");
        console.log("===========================================");
        console.log("Treasury Address: %s", treasuryAddress);
        console.log("ETH Balance:      %s", treasury.getTreasuryBalance());
        console.log("Total Supply:     %s", treasury.getTotalTokensMinted());
        console.log("Total Deposits:   %s", treasury.totalDeposits());
        console.log("Governance:       %s", treasury.governance());
        console.log("===========================================");
    }

    function run() external view {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("DAOTreasury", block.chainid);
        getTreasuryInfo(mostRecentlyDeployed);
    }

 
}