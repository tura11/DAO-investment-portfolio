// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

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
        // Deploy
        treasury = new DAOTreasury();
        governance = new DAOGovernance(address(treasury));

        // Connect governance to treasury
        treasury.setGovernance(address(governance));

        // Setup users
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        mockTarget = makeAddr("mockTarget");

        // Give ETH
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);
    }

    /*//////////////////////////////////////////////////////////////
                        TEST: CREATE PROPOSAL
    //////////////////////////////////////////////////////////////*/

    function testCreateProposal() public {
        // User1 deposits to get tokens
        vm.prank(user1);
        treasury.deposit{value: 1 ether}();

        assertEq(treasury.balanceOf(user1), 1 ether); // 1:1 ratio

        // Create proposal
        vm.prank(user1);
        uint256 proposalId = governance.createProposal(
            DAOGovernance.ProposalParams({
                title: "Test Proposal",
                description: "This is a test description",
                targetContract: mockTarget,
                callData: "",
                ethAmount: 0
            })
        );

        // Verify proposal was created
        assertEq(proposalId, 0);
        assertEq(governance.getProposalCount(), 1);

        // Get proposal details
        DAOGovernance.ProposalView memory proposal = governance.getProposal(proposalId);
        assertEq(proposal.title, "Test Proposal");
        assertEq(proposal.proposer, user1);
        assertEq(proposal.targetContract, mockTarget);
        assertEq(uint(proposal.state), uint(DAOGovernance.ProposalState.Active));
    }

    function testCannotCreateProposalWithoutTokens() public {
        // User1 has no tokens
        vm.prank(user1);
        vm.expectRevert(DAOGovernance.DAOGovernance__NotEnoughTokens.selector);
        governance.createProposal(
            DAOGovernance.ProposalParams({
                title: "Test",
                description: "Test",
                targetContract: mockTarget,
                callData: "",
                ethAmount: 0
            })
        );
    }

    function testCannotCreateProposalWithEmptyTitle() public {
        vm.prank(user1);
        treasury.deposit{value: 1 ether}();

        vm.prank(user1);
        vm.expectRevert(DAOGovernance.DAOGovernance__EmptyTitle.selector);
        governance.createProposal(
            DAOGovernance.ProposalParams({
                title: "",
                description: "Test",
                targetContract: mockTarget,
                callData: "",
                ethAmount: 0
            })
        );
    }

    function testCannotCreateProposalWithEmptyDescription() public {
        vm.prank(user1);
        treasury.deposit{value: 1 ether}();

        vm.prank(user1);
        vm.expectRevert(DAOGovernance.DAOGovernance__EmptyDescription.selector);
        governance.createProposal(
            DAOGovernance.ProposalParams({
                title: "Test",
                description: "",
                targetContract: mockTarget,
                callData: "",
                ethAmount: 0
            })
        );
    }

    function testCannotCreateProposalWithInvalidAddress() public {
        vm.prank(user1);
        treasury.deposit{value: 1 ether}();

        vm.prank(user1);
        vm.expectRevert(DAOGovernance.DAOGovernance__InvalidAddress.selector);
        governance.createProposal(
            DAOGovernance.ProposalParams({
                title: "Test",
                description: "Test",
                targetContract: address(0),
                callData: "",
                ethAmount: 0
            })
        );
    }

    function testCreateProposalRevertStringTooLong() public {
        vm.prank(user1);
        treasury.deposit{value: 3 ether}();

        vm.prank(user1);
        vm.expectRevert(DAOGovernance.DAOGovernance__StringTooLong.selector);
        governance.createProposal(
            DAOGovernance.ProposalParams({
                title: "SDAFDASJFSAJFASJFSAJFSAJFISAJFSAJFSAJFSAJFASJFJSAJFSAJFSAJFASJIFSAFOSAOFISAIFJOSAJIFOSAIOJFASOIF:ASOFSAOIFASFSAIFJASFIAS",
                description: "Test",
                targetContract: mockTarget,
                callData: "",
                ethAmount: 0
            })
        );

    }

    /*//////////////////////////////////////////////////////////////
                        TEST: VOTING
    //////////////////////////////////////////////////////////////*/

    function testVote() public {
        uint256 proposalId = _createTestProposal();

        // User2 deposits and votes
        vm.prank(user2);
        treasury.deposit{value: 2 ether}();

        vm.prank(user2);
        governance.vote(proposalId, DAOGovernance.VoteType.For);

        // Check vote was recorded
        (uint256 votesFor,,,,, ) = governance.getVotingResults(proposalId);
        assertEq(votesFor, 2 ether);
        assertTrue(governance.hasUserVoted(proposalId, user2));
    }

    function testVoteAgainst() public {
        uint256 proposalId = _createTestProposal();

        vm.prank(user2);
        treasury.deposit{value: 3 ether}();

        vm.prank(user2);
        governance.vote(proposalId, DAOGovernance.VoteType.Against);

        (, uint256 votesAgainst,,,, ) = governance.getVotingResults(proposalId);
        assertEq(votesAgainst, 3 ether);
    }

    function testVoteAbstain() public {
        uint256 proposalId = _createTestProposal();

        vm.prank(user2);
        treasury.deposit{value: 1 ether}();

        vm.prank(user2);
        governance.vote(proposalId, DAOGovernance.VoteType.Abstain);

        (,, uint256 votesAbstain,,, ) = governance.getVotingResults(proposalId);
        assertEq(votesAbstain, 1 ether);
    }

    function testCannotVoteTwice() public {
        uint256 proposalId = _createTestProposal();

        vm.prank(user2);
        treasury.deposit{value: 1 ether}();

        // First vote
        vm.prank(user2);
        governance.vote(proposalId, DAOGovernance.VoteType.For);

        // Second vote - should fail
        vm.prank(user2);
        vm.expectRevert(DAOGovernance.DAOGovernance__AlreadyVoted.selector);
        governance.vote(proposalId, DAOGovernance.VoteType.Against);
    }

    function testCannotVoteWithoutTokens() public {
        uint256 proposalId = _createTestProposal();

        // User2 has no tokens
        vm.prank(user2);
        vm.expectRevert(DAOGovernance.DAOGovernance__NoVotingPower.selector);
        governance.vote(proposalId, DAOGovernance.VoteType.For);
    }

    function testCannotVoteOnNonexistentProposal() public {
    vm.prank(user1);
    treasury.deposit{value: 1 ether}();

    // Try to vote on proposal that doesn't exist
    vm.prank(user1);
    vm.expectRevert(DAOGovernance.DAOGovernance__ProposalDoesNotExist.selector);
    governance.vote(999, DAOGovernance.VoteType.For);
}

    function testCannotVoteAfterVotingEnds() public {
        uint256 proposalId = _createTestProposal();

        vm.prank(user2);
        treasury.deposit{value: 1 ether}();

        // Warp past voting period
        vm.warp(block.timestamp + 8 days);

        vm.prank(user2);
        vm.expectRevert(DAOGovernance.DAOGovernance__VotingNotActive.selector);
        governance.vote(proposalId, DAOGovernance.VoteType.For);
    }

    function testWeightedVoting() public {
        uint256 proposalId = _createTestProposal();

        // User2 has more tokens
        vm.prank(user2);
        treasury.deposit{value: 5 ether}();

        // User3 has fewer tokens
        vm.prank(user3);
        treasury.deposit{value: 1 ether}();

        // Both vote FOR
        vm.prank(user2);
        governance.vote(proposalId, DAOGovernance.VoteType.For);

        vm.prank(user3);
        governance.vote(proposalId, DAOGovernance.VoteType.For);

        // User2's vote should count 5x more
        (uint256 votesFor,,,,, ) = governance.getVotingResults(proposalId);
        assertEq(votesFor, 6 ether); // 5 + 1
    }

    /*//////////////////////////////////////////////////////////////
                        TEST: FINALIZATION
    //////////////////////////////////////////////////////////////*/

    function testFinalizeProposalSucceeded() public {
        uint256 proposalId = _createTestProposal();

        // 60% vote FOR, 40% AGAINST
        vm.prank(user2);
        treasury.deposit{value: 3 ether}();

        vm.prank(user3);
        treasury.deposit{value: 2 ether}();

        vm.prank(user2);
        governance.vote(proposalId, DAOGovernance.VoteType.For);

        vm.prank(user3);
        governance.vote(proposalId, DAOGovernance.VoteType.Against);

        // Warp past voting period
        vm.warp(block.timestamp + 7 days + 1);

        // Finalize
        governance.finalizeProposal(proposalId);

        // Check state
        assertEq(
            uint(governance.getProposalState(proposalId)),
            uint(DAOGovernance.ProposalState.Succeeded)
        );
    }

    function testFinalizeProposalDefeated() public {
        uint256 proposalId = _createTestProposal();

        // 40% FOR, 60% AGAINST
        vm.prank(user2);
        treasury.deposit{value: 2 ether}();

        vm.prank(user3);
        treasury.deposit{value: 3 ether}();

        vm.prank(user2);
        governance.vote(proposalId, DAOGovernance.VoteType.For);

        vm.prank(user3);
        governance.vote(proposalId, DAOGovernance.VoteType.Against);

        vm.warp(block.timestamp + 7 days + 1);

        governance.finalizeProposal(proposalId);

        assertEq(
            uint(governance.getProposalState(proposalId)),
            uint(DAOGovernance.ProposalState.Defeated)
        );
    }

    function testFinalizeProposalNoQuorum() public {
        uint256 proposalId = _createTestProposal();

        // Only 10% of tokens vote (< 30% quorum)
        vm.prank(user2);
        treasury.deposit{value: 0.1 ether}();

        vm.prank(user2);
        governance.vote(proposalId, DAOGovernance.VoteType.For);

        vm.warp(block.timestamp + 7 days + 1);

        governance.finalizeProposal(proposalId);

        // Should be defeated due to no quorum
        assertEq(
            uint(governance.getProposalState(proposalId)),
            uint(DAOGovernance.ProposalState.Defeated)
        );
    }

    function testCannotFinalizeBeforeVotingEnds() public {
        uint256 proposalId = _createTestProposal();

        vm.prank(user2);
        treasury.deposit{value: 1 ether}();

        vm.prank(user2);
        governance.vote(proposalId, DAOGovernance.VoteType.For);

        // Try to finalize before voting period ends
        vm.expectRevert(DAOGovernance.DAOGovernance__VotingNotActive.selector);
        governance.finalizeProposal(proposalId);
    }

    /*//////////////////////////////////////////////////////////////
                        TEST: EXECUTION
    //////////////////////////////////////////////////////////////*/

    function testExecuteProposal() public {
        MockTarget target = new MockTarget();

        bytes memory callData = abi.encodeWithSignature("doSomething()");

        vm.prank(user1);
        treasury.deposit{value: 10 ether}();

        vm.prank(user1);
        uint256 proposalId = governance.createProposal(
            DAOGovernance.ProposalParams({
                title: "Call MockTarget",
                description: "Test execution",
                targetContract: address(target),
                callData: callData,
                ethAmount: 0
            })
        );

        // Vote (user1 has 100% of tokens)
        vm.prank(user1);
        governance.vote(proposalId, DAOGovernance.VoteType.For);

        // Warp: 7 days voting + 2 days timelock + 1 second
        vm.warp(block.timestamp + 9 days + 1);

        // Finalize
        governance.finalizeProposal(proposalId);

        // Execute
        governance.executeProposal(proposalId);

        // Verify execution
        assertTrue(target.wasCalled());

        DAOGovernance.ProposalView memory proposal = governance.getProposal(proposalId);
        assertEq(uint(proposal.state), uint(DAOGovernance.ProposalState.Executed));
        assertTrue(proposal.executedAt > 0);
    }

    function testCannotExecuteBeforeTimelock() public {
        uint256 proposalId = _createAndPassProposal();

        // Warp only 7 days (voting period), not timelock
        vm.warp(block.timestamp + 7 days + 1);

        governance.finalizeProposal(proposalId);

        // Try to execute - should fail
        vm.expectRevert(DAOGovernance.DAOGovernance__TimelockNotPassed.selector);
        governance.executeProposal(proposalId);
    }

    function testCannotExecuteDefeatedProposal() public {
        uint256 proposalId = _createTestProposal();

        // Vote against
        vm.prank(user2);
        treasury.deposit{value: 5 ether}();

        vm.prank(user2);
        governance.vote(proposalId, DAOGovernance.VoteType.Against);

        // Finalize (defeated)
        vm.warp(block.timestamp + 7 days + 1);
        governance.finalizeProposal(proposalId);

        // Try to execute
        vm.warp(block.timestamp + 2 days);
        vm.expectRevert(DAOGovernance.DAOGovernance__ProposalNotSucceeded.selector);
        governance.executeProposal(proposalId);
    }

    function testCannotExecuteTwice() public {
        MockTarget target = new MockTarget();

        vm.prank(user1);
        treasury.deposit{value: 10 ether}();

        vm.prank(user1);
        uint256 proposalId = governance.createProposal(
            DAOGovernance.ProposalParams({
                title: "Test",
                description: "Test",
                targetContract: address(target),
                callData: abi.encodeWithSignature("doSomething()"),
                ethAmount: 0
            })
        );

        vm.prank(user1);
        governance.vote(proposalId, DAOGovernance.VoteType.For);

        vm.warp(block.timestamp + 9 days + 1);
        governance.finalizeProposal(proposalId);

        // First execution
        governance.executeProposal(proposalId);

        // Second execution - should fail
        vm.expectRevert(DAOGovernance.DAOGovernance__ProposalAlreadyExecuted.selector);
        governance.executeProposal(proposalId);
    }

    function testCannotExecuteWithInsufficientTreasuryBalance() public {
        vm.prank(user1);
        treasury.deposit{value: 1 ether}();

        // Create proposal that requires 10 ETH but treasury only has 1 ETH
        vm.prank(user1);
        uint256 proposalId = governance.createProposal(
            DAOGovernance.ProposalParams({
                title: "Test",
                description: "Test",
                targetContract: mockTarget,
                callData: "",
                ethAmount: 10 ether
            })
        );

        vm.prank(user1);
        governance.vote(proposalId, DAOGovernance.VoteType.For);

        vm.warp(block.timestamp + 9 days + 1);
        governance.finalizeProposal(proposalId);

        vm.expectRevert(DAOGovernance.DAOGovernance__InsufficientTreasuryBalance.selector);
        governance.executeProposal(proposalId);
    }

    /*//////////////////////////////////////////////////////////////
                        TEST: CANCELLATION
    //////////////////////////////////////////////////////////////*/

    function testCancelProposal() public {
        uint256 proposalId = _createTestProposal();

        // Proposer cancels
        vm.prank(user1);
        governance.cancelProposal(proposalId);

        // Verify canceled
        assertEq(
            uint(governance.getProposalState(proposalId)),
            uint(DAOGovernance.ProposalState.Canceled)
        );
    }

    function testCannotCancelOthersProposal() public {
        uint256 proposalId = _createTestProposal();

        // User2 tries to cancel user1's proposal
        vm.prank(user2);
        vm.expectRevert(DAOGovernance.DAOGovernance__UnauthorizedCancel.selector);
        governance.cancelProposal(proposalId);
    }

    function testCanCancelIfProposerLostPower() public {
        uint256 proposalId = _createTestProposal();

        // User1 withdraws tokens (loses power)
        vm.prank(user1);
        treasury.withdraw(1 ether);

        // Now anyone can cancel
        vm.prank(user2);
        governance.cancelProposal(proposalId);

        assertEq(
            uint(governance.getProposalState(proposalId)),
            uint(DAOGovernance.ProposalState.Canceled)
        );
    }

    function testCannotCancelExecutedProposal() public {
        MockTarget target = new MockTarget();

        vm.prank(user1);
        treasury.deposit{value: 10 ether}();

        vm.prank(user1);
        uint256 proposalId = governance.createProposal(
            DAOGovernance.ProposalParams({
                title: "Test",
                description: "Test",
                targetContract: address(target),
                callData: abi.encodeWithSignature("doSomething()"),
                ethAmount: 0
            })
        );

        vm.prank(user1);
        governance.vote(proposalId, DAOGovernance.VoteType.For);

        vm.warp(block.timestamp + 9 days + 1);
        governance.finalizeProposal(proposalId);
        governance.executeProposal(proposalId);

        // Try to cancel executed proposal
        vm.prank(user1);
        vm.expectRevert(DAOGovernance.DAOGovernance__CannotCancelProposal.selector);
        governance.cancelProposal(proposalId);
    }

    /*//////////////////////////////////////////////////////////////
                        TEST: VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function testGetProposal() public {
        uint256 proposalId = _createTestProposal();

        DAOGovernance.ProposalView memory proposal = governance.getProposal(proposalId);

        assertEq(proposal.id, 0);
        assertEq(proposal.title, "Test");
        assertEq(proposal.proposer, user1);
    }

    function testGetVotingResults() public {
        uint256 proposalId = _createTestProposal();

        vm.prank(user2);
        treasury.deposit{value: 3 ether}();

        vm.prank(user2);
        governance.vote(proposalId, DAOGovernance.VoteType.For);

        (
            uint256 votesFor,
            uint256 votesAgainst,
            uint256 votesAbstain,
            uint256 totalVotes,
            uint256 totalSupply,
            bool quorumReached
        ) = governance.getVotingResults(proposalId);

        assertEq(votesFor, 3 ether);
        assertEq(votesAgainst, 0);
        assertEq(votesAbstain, 0);
        assertEq(totalVotes, 3 ether);
        assertEq(totalSupply, 4 ether); // user1 + user2
        assertTrue(quorumReached);
    }

    function testGetProposalCount() public {
        assertEq(governance.getProposalCount(), 0);

        _createTestProposal();
        assertEq(governance.getProposalCount(), 1);

        _createTestProposal();
        assertEq(governance.getProposalCount(), 2);
    }

    function testGetUserVote() public {
       uint256 proposalId = _createTestProposal();

       vm.prank(user2);
       treasury.deposit{value: 3 ether}();

       vm.prank(user2);
       governance.vote(proposalId, DAOGovernance.VoteType.For);

       assertEq(
        uint(governance.getUserVote(proposalId, user2)), 
        uint(DAOGovernance.VoteType.For)
    );

    }
    /*//////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _createTestProposal() internal returns (uint256) {
        vm.prank(user1);
        treasury.deposit{value: 1 ether}();

        vm.prank(user1);
        return governance.createProposal(
            DAOGovernance.ProposalParams({
                title: "Test",
                description: "Test description",
                targetContract: mockTarget,
                callData: "",
                ethAmount: 0
            })
        );
    }

    function _createAndPassProposal() internal returns (uint256) {
        uint256 proposalId = _createTestProposal();

        vm.prank(user1);
        governance.vote(proposalId, DAOGovernance.VoteType.For);

        return proposalId;
    }
}

/*//////////////////////////////////////////////////////////////
                        MOCK CONTRACTS
//////////////////////////////////////////////////////////////*/

contract MockTarget {
    bool public wasCalled;

    function doSomething() external {
        wasCalled = true;
    }

    receive() external payable {}
}