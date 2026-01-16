// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

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

        // Connect
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
        // User1 deposits
        vm.prank(user1);
        treasury.deposit{value: 1 ether}();

        assertEq(treasury.balanceOf(user1), 1 ether); // 1:1 ratio

        // Create proposal
        vm.prank(user1);
        uint256 proposalId = governance.createProposal(
            DAOGovernance.ProposalParams({
                title: "Test Proposal",
                description: "This is a test",
                targetContract: mockTarget,
                callData: "",
                ethAmount: 0
            })
        );

        assertEq(proposalId, 0);
        assertEq(governance.getProposalCount(), 1);

        DAOGovernance.Proposal memory proposal = governance.getProposal(proposalId);
        assertEq(proposal.title, "Test Proposal");
        assertEq(proposal.proposer, user1);
    }

    function testCannotCreateProposalWithoutTokens() public {
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

    /*//////////////////////////////////////////////////////////////
                        TEST: VOTING
    //////////////////////////////////////////////////////////////*/

    function testVote() public {
        uint256 proposalId = _createTestProposal();

        vm.prank(user2);
        treasury.deposit{value: 2 ether}();

        vm.prank(user2);
        governance.vote(proposalId, DAOGovernance.VoteType.For);

        DAOGovernance.Proposal memory proposal = governance.getProposal(proposalId);
        assertEq(proposal.votesFor, 2 ether);
    }

    function testCannotVoteTwice() public {
        uint256 proposalId = _createTestProposal();

        vm.prank(user2);
        treasury.deposit{value: 1 ether}();

        vm.prank(user2);
        governance.vote(proposalId, DAOGovernance.VoteType.For);

        vm.prank(user2);
        vm.expectRevert(DAOGovernance.DAOGovernance__AlreadyVoted.selector);
        governance.vote(proposalId, DAOGovernance.VoteType.Against);
    }

    /*//////////////////////////////////////////////////////////////
                        TEST: FINALIZATION
    //////////////////////////////////////////////////////////////*/

    function testFinalizeProposalSucceeded() public {
        uint256 proposalId = _createTestProposal();

        vm.prank(user2);
        treasury.deposit{value: 3 ether}();

        vm.prank(user3);
        treasury.deposit{value: 2 ether}();

        vm.prank(user2);
        governance.vote(proposalId, DAOGovernance.VoteType.For);

        vm.prank(user3);
        governance.vote(proposalId, DAOGovernance.VoteType.Against);

        vm.warp(block.timestamp + 7 days + 1);

        governance.finalizeProposal(proposalId);

        assertEq(
            uint256(governance.getProposalState(proposalId)),
            uint256(DAOGovernance.ProposalState.Succeeded)
        );
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
                description: "Test",
                targetContract: address(target),
                callData: callData,
                ethAmount: 0
            })
        );

        vm.prank(user1);
        governance.vote(proposalId, DAOGovernance.VoteType.For);

        vm.warp(block.timestamp + 9 days + 1);

        governance.finalizeProposal(proposalId);
        governance.executeProposal(proposalId);

        assertTrue(target.wasCalled());
    }

    /*//////////////////////////////////////////////////////////////
                        HELPERS
    //////////////////////////////////////////////////////////////*/

    function _createTestProposal() internal returns (uint256) {
        vm.prank(user1);
        treasury.deposit{value: 1 ether}();

        vm.prank(user1);
        return governance.createProposal(
            DAOGovernance.ProposalParams({
                title: "Test",
                description: "Test",
                targetContract: mockTarget,
                callData: "",
                ethAmount: 0
            })
        );
    }
}

contract MockTarget {
    bool public wasCalled;

    function doSomething() external {
        wasCalled = true;
    }

    receive() external payable {}
}