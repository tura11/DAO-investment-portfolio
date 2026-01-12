// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { DAOTreasury } from "./DAOTreasury.sol";

contract DAOGovernance is ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
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
    error DAOGovernance__ExecutionFailed();
    error DAOGovernance__TimelockNotPassed();

    /*//////////////////////////////////////////////////////////////
                                ENUMS
    //////////////////////////////////////////////////////////////*/
    enum ProposalState {
        Pending,
        Active,
        Succeeded,
        Defeated,
        Executed,
        Canceled
    }

    enum VoteType {
        Against,
        For,
        Abstain
    }

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/
    struct Proposal {
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
    }

    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/
    Proposal[] public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => mapping(address => VoteType)) public userVote;

    uint256 public proposalCount;
    DAOTreasury public immutable treasury;

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant TIMELOCK_PERIOD = 2 days;
    uint256 public constant QUORUM_PERCENTAGE = 30; // %
    uint256 public constant APPROVAL_THRESHOLD = 51; // %
    uint256 public constant MIN_TOKENS_TO_PROPOSE = 10 ether;
    uint256 public constant MAX_TITLE_LENGTH = 100;
    uint256 public constant MAX_DESCRIPTION_LENGTH = 500;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
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

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _treasury) {
        if (_treasury == address(0)) {
            revert DAOGovernance__InvalidAddress();
        }
        treasury = DAOTreasury(_treasury);
    }

    /*//////////////////////////////////////////////////////////////
                        PROPOSAL CREATION
    //////////////////////////////////////////////////////////////*/
    function createProposal(
        string memory _title,
        string memory _description,
        address _targetContract,
        bytes memory _callData,
        uint256 _ethAmount
    ) external nonReentrant returns (uint256) {
        if (bytes(_title).length == 0) revert DAOGovernance__EmptyTitle();
        if (bytes(_description).length == 0) revert DAOGovernance__EmptyDescription();
        if (
            bytes(_title).length > MAX_TITLE_LENGTH ||
            bytes(_description).length > MAX_DESCRIPTION_LENGTH
        ) revert DAOGovernance__StringTooLong();
        if (_targetContract == address(0)) revert DAOGovernance__InvalidAddress();
        if (treasury.balanceOf(msg.sender) < MIN_TOKENS_TO_PROPOSE)
            revert DAOGovernance__NotEnoughTokens();

        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + VOTING_PERIOD;

        proposals.push(
            Proposal({
                id: proposalCount,
                title: _title,
                description: _description,
                proposer: msg.sender,
                targetContract: _targetContract,
                callData: _callData,
                ethAmount: _ethAmount,
                votesFor: 0,
                votesAgainst: 0,
                votesAbstain: 0,
                startTime: startTime,
                endTime: endTime,
                executionTime: endTime + TIMELOCK_PERIOD,
                executedAt: 0
            })
        );

        emit ProposalCreated(
            proposalCount,
            msg.sender,
            _title,
            _targetContract,
            _ethAmount,
            startTime,
            endTime
        );

        proposalCount++;
        return proposalCount - 1;
    }

    /*//////////////////////////////////////////////////////////////
                                VOTING
    //////////////////////////////////////////////////////////////*/
    function vote(uint256 proposalId, VoteType voteType) external nonReentrant {
        if (proposalId >= proposalCount)
            revert DAOGovernance__ProposalDoesNotExist();

        Proposal storage proposal = proposals[proposalId];

        if (
            block.timestamp < proposal.startTime ||
            block.timestamp > proposal.endTime
        ) revert DAOGovernance__VotingNotActive();

        if (hasVoted[proposalId][msg.sender])
            revert DAOGovernance__AlreadyVoted();

        uint256 votingPower = treasury.balanceOf(msg.sender);
        if (votingPower == 0) revert DAOGovernance__NoVotingPower();

        hasVoted[proposalId][msg.sender] = true;
        userVote[proposalId][msg.sender] = voteType;

        if (voteType == VoteType.For) {
            proposal.votesFor += votingPower;
        } else if (voteType == VoteType.Against) {
            proposal.votesAgainst += votingPower;
        } else {
            proposal.votesAbstain += votingPower;
        }

        emit VoteCast(proposalId, msg.sender, voteType, votingPower);
    }

    /*//////////////////////////////////////////////////////////////
                        PROPOSAL EXECUTION
    //////////////////////////////////////////////////////////////*/
    function executeProposal(uint256 proposalId) external nonReentrant {
        if (proposalId >= proposalCount)
            revert DAOGovernance__ProposalDoesNotExist();

        Proposal storage proposal = proposals[proposalId];

        if (getProposalState(proposalId) != ProposalState.Succeeded)
            revert DAOGovernance__ProposalNotSucceeded();

        if (block.timestamp < proposal.executionTime)
            revert DAOGovernance__TimelockNotPassed();

        if (proposal.executedAt != 0)
            revert DAOGovernance__ProposalAlreadyExecuted();

        if (proposal.ethAmount > address(treasury).balance)
            revert DAOGovernance__InsufficientTreasuryBalance();

        
        proposal.executedAt = block.timestamp;

        
        bytes memory returnData = treasury.executeTransaction(
            proposal.targetContract,
            proposal.ethAmount,
            proposal.callData
        );

        emit ProposalExecuted(proposalId, msg.sender, returnData);
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function getProposalState(uint256 proposalId)
        public
        view
        returns (ProposalState)
    {
        if (proposalId >= proposalCount)
            revert DAOGovernance__ProposalDoesNotExist();

        Proposal storage proposal = proposals[proposalId];

        if (proposal.executedAt != 0) {
            return ProposalState.Executed;
        }

        if (block.timestamp <= proposal.endTime) {
            return ProposalState.Active;
        }

        uint256 totalVotes =
            proposal.votesFor +
            proposal.votesAgainst +
            proposal.votesAbstain;

        uint256 totalSupply = treasury.totalSupply();
        if (totalSupply == 0) return ProposalState.Defeated;

        bool quorumReached =
            (totalVotes * 100) / totalSupply >= QUORUM_PERCENTAGE;

        if (!quorumReached) return ProposalState.Defeated;

        uint256 forPercentage =
            (proposal.votesFor * 100) / totalVotes;

        return
            forPercentage >= APPROVAL_THRESHOLD
                ? ProposalState.Succeeded
                : ProposalState.Defeated;
    }

    function getProposal(uint256 proposalId)
        external
        view
        returns (Proposal memory)
    {
        if (proposalId >= proposalCount)
            revert DAOGovernance__ProposalDoesNotExist();
        return proposals[proposalId];
    }

    function getProposalCount() external view returns (uint256) {
        return proposalCount;
    }
}
