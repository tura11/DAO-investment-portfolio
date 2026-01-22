// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;


interface IDAOGovernance {
    enum VoteType {
        Against,
        For,
        Abstain
    }

    enum ProposalState {
        Pending,
        Active,
        Succeeded,
        Defeated,
        Executed,
        Canceled
    }

    struct ProposalView {
        uint256 id;
        string title;
        string description;
        address proposer;
        address targetContract;
        bytes callData;
        uint256 ethAmount;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 votesAbstain;
        uint256 startTime;
        uint256 endTime;
        uint256 executionTime;
        uint256 executedAt;
        ProposalState state;
    }

    struct ProposalParams {
        string title;
        string description;
        address targetContract;
        bytes callData;
        uint256 ethAmount;
    }

    

    function createProposal(ProposalParams calldata params) external returns (uint256);
    function vote(uint256 proposalId,VoteType voteType) external;
    function finalizeProposal(uint256 proposalId) external;
    function executeProposal(uint256 proposalId) external;
    function cancelProposal(uint256 proposalId) external;


    function getProposal(uint256 proposalId) external view returns (ProposalView);
    function getProposalState(uint256 proposalId) external view returns (ProposalState);
    function getProposalCount() external view returns (uint256);
    function hasUserVoted(uint256 proposalId, address user) external view returns (bool);
    function getUserVote(uint256 proposalId, address user) external view returns (VoteType);
    function getVotingResults(uint256 proposalId) external view returns (uint256 votesFor, uint256 votesAgainst, uint256 votesAbstain, uint256 totalVotes, uint256 totalSupply, bool quorumReached);

}