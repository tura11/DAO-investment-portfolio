// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;


interface IDAOGovernance {

    //enums
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
    //structs
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

    //errors
    error DAOGovernance__StringTooLong();
    error DAOGovernance__InvalidAddress();
    error DAOGovernance__NotEnoughTokens();
    error DAOGovernance__EmptyTitle();
    error DAOGovernance__EmptyDescription();
    error DAOGovernance__ProposalDoesNotExist();
    error DAOGovernance__VotingNotActive();
    error DAOGovernance__AlreadyVoted();
    error DAOGovernance__NoVotingPower();
    error DAOGovernance__ProposalNotSucceeded();
    error DAOGovernance__ProposalAlreadyExecuted();
    error DAOGovernance__InsufficientTreasuryBalance();
    error DAOGovernance__TimelockNotPassed();
    error DAOGovernance__CannotCancelProposal();
    error DAOGovernance__UnauthorizedCancel();


    //events

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string title,
        address targetContract,
        uint256 ethAmount,
        uint256 startTime,
        uint256 endTime
    );

    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        VoteType voteType,
        uint256 votingPower
    );

    event ProposalExecuted(
        uint256 indexed proposalId,
        address indexed executor,
        bytes returnData
    );

    event ProposalCanceled(
        uint256 indexed proposalId,
        address indexed canceler
    );

    event ProposalFinalized(
        uint256 indexed proposalId,
        address indexed finalizer
        );



    function createProposal(ProposalParams calldata params) external returns (uint256);
    function vote(uint256 proposalId,VoteType voteType) external;
    function finalizeProposal(uint256 proposalId) external;
    function executeProposal(uint256 proposalId) external;
    function cancelProposal(uint256 proposalId) external;


    function getProposal(uint256 proposalId) external view returns (ProposalView memory);
    function getProposalState(uint256 proposalId) external view returns (ProposalState);
    function getProposalCount() external view returns (uint256);
    function hasUserVoted(uint256 proposalId, address user) external view returns (bool);
    function getUserVote(uint256 proposalId, address user) external view returns (VoteType);
    function getVotingResults(uint256 proposalId) external view returns (uint256 votesFor, uint256 votesAgainst, uint256 votesAbstain, uint256 totalVotes, uint256 totalSupply, bool quorumReached);

}