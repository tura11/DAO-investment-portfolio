pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {DAOGovernance} from "../src/DAOGovernance.sol";
import {DAOTreasury} from "../src/DAOTreasury.sol";

contract DAOGovernanceTest is Test {
    DAOGovernance public governance;
    DAOTreasury public treasury;
    
    address user1;
    address user2;
    address user3;
    

    address mockTarget;

    function setUp() public {
        treasury = new DAOTreasury();
        
     
        governance = new DAOGovernance(address(treasury));
        
        treasury.setGovernance(address(governance));
        
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        
        mockTarget = makeAddr("mockTarget");
        
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);
    }

    function testCreateProposal() public {
        // User1 deposits to get tokens
        vm.prank(user1);
        treasury.deposit{value: 1 ether}();
        
        // User1 has 1000 tokens (1 ETH = 1000 tokens)
        assertEq(treasury.balanceOf(user1), 1000 ether);
        
        // Create proposal
        vm.prank(user1);
        uint256 proposalId = governance.createProposal(
            "Test Proposal",
            "This is a test proposal description",
            mockTarget,
            "", // empty calldata for now
            0   // no ETH amount
        );
        
        // Verify proposal was created
        assertEq(proposalId, 0); // First proposal
        assertEq(governance.getProposalCount(), 1);
        
        // Get proposal and verify details
        DAOGovernance.Proposal memory proposal = governance.getProposal(proposalId);
        assertEq(proposal.title, "Test Proposal");
        assertEq(proposal.proposer, user1);
        assertEq(proposal.targetContract, mockTarget);
        assertEq(uint(proposal.state), uint(DAOGovernance.ProposalState.Active));
    }
}