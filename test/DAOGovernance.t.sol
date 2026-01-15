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
        vm.deal(user3, 1 ether); //for testing reverts with tokens
    }

    /*//////////////////////////////////////////////////////////////
                       CREATE PROPOSAL TESTS
    //////////////////////////////////////////////////////////////*/

    function testCreateProposalSuccesful() public {
        // User1 deposits to get token
        vm.prank(user1);
        treasury.deposit{value: 3 ether}();
        
        // User1 has 1 token (1 ETH = 1 token)
        assertEq(treasury.balanceOf(user1), 3 ether);
        
        // Create proposal
        vm.prank(user1);
        uint256 proposalId = governance.createProposal(
            "Test Proposal",
            "This is a test proposal description",
            mockTarget,
            "", // empty calldata for now
            0   // no ETH amount
        );
        

        assertEq(proposalId, 0);
        assertEq(governance.getProposalCount(), 1);
        
    
        DAOGovernance.Proposal memory proposal = governance.getProposal(proposalId);
        assertEq(proposal.title, "Test Proposal");
        assertEq(proposal.proposer, user1);
        assertEq(proposal.targetContract, mockTarget);
        assertEq(uint(proposal.state), uint(DAOGovernance.ProposalState.Active));
    }

    function testCreateProposalRevertEmptyTitle() public {
        vm.prank(user1);
        vm.expectRevert(DAOGovernance.DAOGovernance__EmptyTitle.selector);
        governance.createProposal(
            "",
            "This is a test proposal description",
            mockTarget,
            "", // empty calldata for now
            0   // no ETH amount
        );
    }

    function testCreateProposalRevertEmptyDescription() public {
        vm.prank(user1);
        vm.expectRevert(DAOGovernance.DAOGovernance__EmptyDescription.selector);
        governance.createProposal(
            "Test Proposal",
            "",
            mockTarget,
            "", // empty calldata for now
            0   // no ETH amount
        );
    }

    function testCreateProposalRevertStringTooLong() public {
        vm.prank(user1);
        vm.expectRevert(DAOGovernance.DAOGovernance__StringTooLong.selector);
        governance.createProposal(
            "Test Proposal dasdsadsadasdasdasdadasrderwqfajfsfsajklfjksafksalfkasfjai0wqejiwajipfsaifsalkfsaflkjsafjsafjasfiofweqjifqwfjipwpiafipwaijfwqapijfwaijfsipafsajpkfksafkasfkasjfiqwipjfwqjipfqwpijfwqipjfwqjip",
            "Test",
            mockTarget,
            "", // empty calldata for now
            0   // no ETH amount
        );
    }


    function testCreateProposalRevertInvalidTargetAddress() public {
        vm.prank(user1);
        vm.expectRevert(DAOGovernance.DAOGovernance__InvalidAddress.selector);
        governance.createProposal(
            "Test Proposal",
            "This is a test proposal description",
            address(0),
            "", // empty calldata for now
            0   // no ETH amount
        );
    }

    function testCreateProposalRevertNotEnoughTokens() public {
        vm.prank(user3); // user3 has 1 token min value is 10.
        vm.expectRevert(DAOGovernance.DAOGovernance__NotEnoughTokens.selector);
        governance.createProposal(
            "Test Proposal",
            "This is a test proposal description",
            mockTarget,
            "", // empty calldata for now
            0   // no ETH amount
        );
    }

    /*//////////////////////////////////////////////////////////////
                        VOTE TESTS
    //////////////////////////////////////////////////////////////*/


    function testVoteSuccessful() public {
        vm.startPrank(user1);
        treasury.deposit{value: 3 ether}();
        governance.createProposal(
            "Test Proposal",
            "This is a test proposal description",
            mockTarget,
            "", // empty calldata for now
            0   // no ETH amount
        );
        vm.stopPrank();
        vm.startPrank(user2);
        treasury.deposit{value: 1 ether}();
        governance.vote(0, DAOGovernance.VoteType.For);
        DAOGovernance.Proposal memory proposal = governance.getProposal(0);
        assertEq(proposal.votesFor, 1 ether);
        assertEq(proposal.votesAgainst, 0);
        assertEq(proposal.votesAbstain, 0);
    }

    function testVoteRevertIfProposalDoesNotExist() public {
        vm.expectRevert(DAOGovernance.DAOGovernance__ProposalDoesNotExist.selector);
        governance.vote(1, DAOGovernance.VoteType.For);
    }


    function testVoteRevertIfVotingNotActive() public {
        vm.startPrank(user1);
        treasury.deposit{value: 3 ether}();
        governance.createProposal(
            "Test Proposal",
            "This is a test proposal description",
            mockTarget,
            "", // empty calldata for now
            0   // no ETH amount
        );
        vm.stopPrank();
        
        vm.startPrank(user2);
        treasury.deposit{value: 1 ether}();
        vm.warp(block.timestamp + 8 days); // 7 days voting period
        vm.expectRevert(DAOGovernance.DAOGovernance__VotingNotActive.selector);
        governance.vote(0, DAOGovernance.VoteType.For);
    }


}