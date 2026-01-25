// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {DAOGovernance} from "../../src/DAOGovernance.sol";
import {DAOTreasury} from "../../src/DAOTreasury.sol";
import {MockTarget, MockFailingTarget} from "./mocks/MockTarget.sol";

contract DAOGovernanceTest is Test {
    DAOGovernance public governance;
    DAOTreasury public treasury;
    MockTarget public mockTarget;
    MockFailingTarget public failingTarget;

    address user1;
    address user2;
    address user3;

    function setUp() public {
        // Deploy
        treasury = new DAOTreasury();
        governance = new DAOGovernance(address(treasury));

        // Connect governance to treasury
        treasury.setGovernance(address(governance));

        // Deploy mocks
        mockTarget = new MockTarget();
        failingTarget = new MockFailingTarget();

        // Setup users
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

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
                targetContract: address(mockTarget),
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
        assertEq(proposal.targetContract, address(mockTarget));
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
                targetContract: address(mockTarget),
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
                targetContract: address(mockTarget),
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
                targetContract: address(mockTarget),
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
                targetContract: address(mockTarget),
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

    function testExecuteProposal_WithCallData() public {
        vm.prank(user1);
        treasury.deposit{value: 10 ether}();

        // Create proposal with callData
        bytes memory callData = abi.encodeWithSignature("setValue(uint256)", 42);

        vm.prank(user1);
        uint256 proposalId = governance.createProposal(
            DAOGovernance.ProposalParams({
                title: "Set Value to 42",
                description: "Test execution with callData",
                targetContract: address(mockTarget),
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
        assertEq(mockTarget.value(), 42); // ✅ Function was called!
        assertEq(mockTarget.callCount(), 1);
        assertEq(mockTarget.lastCaller(), address(treasury));

        DAOGovernance.ProposalView memory proposal = governance.getProposal(proposalId);
        assertEq(uint(proposal.state), uint(DAOGovernance.ProposalState.Executed));
        assertTrue(proposal.executedAt > 0);
    }

    function testExecuteProposal_SendsETH() public {
        vm.prank(user1);
        treasury.deposit{value: 10 ether}();

        bytes memory callData = abi.encodeWithSignature("receiveEth()");

        vm.prank(user1);
        uint256 proposalId = governance.createProposal(
            DAOGovernance.ProposalParams({
                title: "Send ETH",
                description: "Send 2 ETH to target",
                targetContract: address(mockTarget),
                callData: callData,
                ethAmount: 2 ether
            })
        );

        vm.prank(user1);
        governance.vote(proposalId, DAOGovernance.VoteType.For);

        vm.warp(block.timestamp + 9 days + 1);
        governance.finalizeProposal(proposalId);
        governance.executeProposal(proposalId);

        // Verify ETH was sent
        assertEq(mockTarget.totalEthReceived(), 2 ether);
        assertEq(mockTarget.callCount(), 1);
    }

    function testExecuteProposal_DepositToMockAave() public {
        vm.prank(user1);
        treasury.deposit{value: 20 ether}();

        bytes memory callData = abi.encodeWithSignature("deposit(uint256)", 5 ether);

        vm.prank(user1);
        uint256 proposalId = governance.createProposal(
            DAOGovernance.ProposalParams({
                title: "Invest in Aave",
                description: "Deposit 5 ETH to Aave",
                targetContract: address(mockTarget),
                callData: callData,
                ethAmount: 5 ether
            })
        );

        vm.prank(user1);
        governance.vote(proposalId, DAOGovernance.VoteType.For);

        vm.warp(block.timestamp + 9 days + 1);
        governance.finalizeProposal(proposalId);
        governance.executeProposal(proposalId);

        // Verify "Aave deposit" worked
        assertEq(mockTarget.balanceOf(address(treasury)), 5 ether);
        assertEq(mockTarget.totalEthReceived(), 5 ether);
        assertEq(mockTarget.callCount(), 1);
    }

    function testExecuteProposal_SwapOnMockUniswap() public {
        vm.prank(user1);
        treasury.deposit{value: 15 ether}();

        bytes memory callData = abi.encodeWithSignature("swap(uint256)", 3 ether);

        vm.prank(user1);
        uint256 proposalId = governance.createProposal(
            DAOGovernance.ProposalParams({
                title: "Swap on Uniswap",
                description: "Swap 3 ETH for tokens",
                targetContract: address(mockTarget),
                callData: callData,
                ethAmount: 3 ether
            })
        );

        vm.prank(user1);
        governance.vote(proposalId, DAOGovernance.VoteType.For);

        vm.warp(block.timestamp + 9 days + 1);
        governance.finalizeProposal(proposalId);
        governance.executeProposal(proposalId);

        // Verify swap worked (1:1 in mock)
        assertEq(mockTarget.balanceOf(address(treasury)), 3 ether);
        assertEq(mockTarget.totalEthReceived(), 3 ether);
    }

    function testExecuteProposal_PayDeveloper() public {
        address developer = makeAddr("developer");
        
        vm.prank(user1);
        treasury.deposit{value: 10 ether}();

        bytes memory callData = abi.encodeWithSignature("pay(address,uint256)", developer, 1 ether);

        vm.prank(user1);
        uint256 proposalId = governance.createProposal(
            DAOGovernance.ProposalParams({
                title: "Pay Developer",
                description: "Pay 1 ETH for completed work",
                targetContract: address(mockTarget),
                callData: callData,
                ethAmount: 1 ether
            })
        );

        vm.prank(user1);
        governance.vote(proposalId, DAOGovernance.VoteType.For);

        vm.warp(block.timestamp + 9 days + 1);
        governance.finalizeProposal(proposalId);
        
        uint256 devBalanceBefore = developer.balance;
        governance.executeProposal(proposalId);

        // Verify developer got paid
        assertEq(developer.balance - devBalanceBefore, 1 ether);
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
        vm.prank(user1);
        treasury.deposit{value: 10 ether}();

        bytes memory callData = abi.encodeWithSignature("setValue(uint256)", 123);

        vm.prank(user1);
        uint256 proposalId = governance.createProposal(
            DAOGovernance.ProposalParams({
                title: "Test",
                description: "Test",
                targetContract: address(mockTarget),
                callData: callData,
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
                targetContract: address(mockTarget),
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
        vm.prank(user1);
        treasury.deposit{value: 10 ether}();

        bytes memory callData = abi.encodeWithSignature("setValue(uint256)", 99);

        vm.prank(user1);
        uint256 proposalId = governance.createProposal(
            DAOGovernance.ProposalParams({
                title: "Test",
                description: "Test",
                targetContract: address(mockTarget),
                callData: callData,
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
        assertEq(proposal.title, "Test Proposal");
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
                    TEST: EDGE CASES & COVERAGE
    //////////////////////////////////////////////////////////////*/

    function testCannotDeployWithZeroAddress() public {
        vm.expectRevert(DAOGovernance.DAOGovernance__InvalidAddress.selector);
        new DAOGovernance(address(0));
    }

    function testGetProposalRevertsForInvalidId() public {
        vm.expectRevert(DAOGovernance.DAOGovernance__ProposalDoesNotExist.selector);
        governance.getProposal(999);
    }

    function testGetProposalStateRevertsForInvalidId() public {
        vm.expectRevert(DAOGovernance.DAOGovernance__ProposalDoesNotExist.selector);
        governance.getProposalState(999);
    }

    function testFinalizeProposalRevertsForInvalidId() public {
        vm.expectRevert(DAOGovernance.DAOGovernance__ProposalDoesNotExist.selector);
        governance.finalizeProposal(999);
    }

    function testExecuteProposalRevertsForInvalidId() public {
        vm.expectRevert(DAOGovernance.DAOGovernance__ProposalDoesNotExist.selector);
        governance.executeProposal(999);
    }

    function testCancelProposalRevertsForInvalidId() public {
        vm.expectRevert(DAOGovernance.DAOGovernance__ProposalDoesNotExist.selector);
        governance.cancelProposal(999);
    }

    function testHasUserVotedRevertsForInvalidId() public {
        vm.expectRevert(DAOGovernance.DAOGovernance__ProposalDoesNotExist.selector);
        governance.hasUserVoted(999, user1);
    }

    function testGetUserVoteRevertsForInvalidId() public {
        vm.expectRevert(DAOGovernance.DAOGovernance__ProposalDoesNotExist.selector);
        governance.getUserVote(999, user1);
    }

    function testGetVotingResultsRevertsForInvalidId() public {
        vm.expectRevert(DAOGovernance.DAOGovernance__ProposalDoesNotExist.selector);
        governance.getVotingResults(999);
    }



    function _createTestProposal() internal returns (uint256) {

    vm.prank(user1);
    treasury.deposit{value: 1 ether}();


    vm.prank(user1);
    return governance.createProposal(
        DAOGovernance.ProposalParams({
            title: "Test Proposal",
            description: "Test description",
            targetContract: address(mockTarget),
            callData: "",
            ethAmount: 0
        })
    );
}

}