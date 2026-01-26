// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IDAOTreasury } from "./interfaces/IDAOTreasury.sol";


/**
 * @title DAOGovernance
 * @author Tura11
 * @notice Core governance contract for an on-chain DAO treasury system.
 *
 * @dev This contract enables token-weighted governance over a shared ETH treasury.
 *      DAO members deposit ETH into the DAOTreasury contract and receive governance
 *      tokens (1:1). These tokens represent both economic ownership and voting power.
 *
 *      Key features:
 *      - Token-weighted proposal creation and voting
 *      - On-chain execution via DAO-controlled treasury
 *      - Quorum + approval thresholds
 *      - Timelock before execution
 *      - Proposal cancellation logic
 *
 *      Governance flow:
 *      1. Members deposit ETH → receive DAOGOV tokens
 *      2. Token holders create proposals (calls + ETH transfers)
 *      3. DAO votes using token-weighted voting
 *      4. Successful proposals are executed via the treasury
 *
 *      The governance contract NEVER holds funds directly.
 *      All ETH is stored and executed through DAOTreasury.
 */
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
    error DAOGovernance__TimelockNotPassed();
    error DAOGovernance__CannotCancelProposal();
    error DAOGovernance__UnauthorizedCancel();

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
    
    /// @notice Parameters for creating a proposal
    struct ProposalParams {
        string title;
        string description;
        address targetContract;
        bytes callData;
        uint256 ethAmount;
    }

    /// @notice Core proposal data (smaller struct)
    struct ProposalCore {
        address proposer;
        address targetContract;
        uint256 ethAmount;
        uint256 startTime;
        uint256 endTime;
        uint256 executionTime;
    }

    /// @notice Voting data
    struct VotingData {
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 votesAbstain;
    }

    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/
    

    mapping(uint256 => ProposalCore) public proposalCore;
    mapping(uint256 => VotingData) public votingData;
    mapping(uint256 => string) public proposalTitle;
    mapping(uint256 => string) public proposalDescription;
    mapping(uint256 => bytes) public proposalCallData;
    mapping(uint256 => uint256) public proposalExecutedAt;
    mapping(uint256 => ProposalState) public proposalState;
    
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => mapping(address => VoteType)) public userVote;
    
    uint256 public proposalCount;
    IDAOTreasury public immutable treasury;

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant TIMELOCK_PERIOD = 2 days;
    uint256 public constant QUORUM_PERCENTAGE = 30;
    uint256 public constant APPROVAL_THRESHOLD = 51;
    uint256 public constant MIN_TOKENS_TO_PROPOSE = 0.01 ether;
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

    event ProposalCanceled(
        uint256 indexed proposalId,
        address indexed canceler
    );

    event ProposalFinalized(
        uint256 indexed proposalId,
        address indexed finalizer
        );


    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _treasury) {
        if (_treasury == address(0)) revert DAOGovernance__InvalidAddress();
        treasury = IDAOTreasury(_treasury);
    }

    /*//////////////////////////////////////////////////////////////
                        PROPOSAL CREATION
    //////////////////////////////////////////////////////////////*/
    
    function createProposal(
        ProposalParams calldata params
    ) external returns (uint256 proposalId) {
        _validateProposalParams(params);

        unchecked {
            proposalId = proposalCount++;
        }

        uint256 start = block.timestamp;
        uint256 end = start + VOTING_PERIOD;

        proposalCore[proposalId] = ProposalCore({
            proposer: msg.sender,
            targetContract: params.targetContract,
            ethAmount: params.ethAmount,
            startTime: start,
            endTime: end,
            executionTime: end + TIMELOCK_PERIOD
        });

        proposalTitle[proposalId] = params.title;
        proposalDescription[proposalId] = params.description;
        proposalCallData[proposalId] = params.callData;
        proposalState[proposalId] = ProposalState.Active;

        emit ProposalCreated(
            proposalId,
            msg.sender,
            params.title,
            params.targetContract,
            params.ethAmount,
            start,
            end
        );
    }

    /*//////////////////////////////////////////////////////////////
                                VOTING
    //////////////////////////////////////////////////////////////*/
    
    function vote(uint256 proposalId, VoteType voteType) external {
        if (proposalId >= proposalCount) revert DAOGovernance__ProposalDoesNotExist();

        ProposalCore memory core = proposalCore[proposalId];
        
        uint256 currentTime = block.timestamp;
        if (currentTime < core.startTime || currentTime > core.endTime) {
            revert DAOGovernance__VotingNotActive();
        }

        if (hasVoted[proposalId][msg.sender]) revert DAOGovernance__AlreadyVoted();

        uint256 votingPower = treasury.balanceOf(msg.sender);
        if (votingPower == 0) revert DAOGovernance__NoVotingPower();

        hasVoted[proposalId][msg.sender] = true;
        userVote[proposalId][msg.sender] = voteType;

        VotingData storage votes = votingData[proposalId];
        
        if (voteType == VoteType.For) {
            votes.votesFor += votingPower;
        } else if (voteType == VoteType.Against) {
            votes.votesAgainst += votingPower;
        } else {
            votes.votesAbstain += votingPower;
        }

        emit VoteCast(proposalId, msg.sender, voteType, votingPower);
    }

    /*//////////////////////////////////////////////////////////////
                        FINALIZATION
    //////////////////////////////////////////////////////////////*/
    
    function finalizeProposal(uint256 proposalId) external {
        if (proposalId >= proposalCount) revert DAOGovernance__ProposalDoesNotExist();

        ProposalCore memory core = proposalCore[proposalId];

        if (block.timestamp <= core.endTime) revert DAOGovernance__VotingNotActive();
        if (proposalState[proposalId] != ProposalState.Active) return;

        proposalState[proposalId] = _calculateFinalState(proposalId);

        emit ProposalFinalized(proposalId, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                        EXECUTION
    //////////////////////////////////////////////////////////////*/
    
   function executeProposal(uint256 proposalId) external nonReentrant {
        if (proposalId >= proposalCount) revert DAOGovernance__ProposalDoesNotExist();

        ProposalCore memory core = proposalCore[proposalId];


        if (proposalExecutedAt[proposalId] != 0) {
            revert DAOGovernance__ProposalAlreadyExecuted();
        }

        if (proposalState[proposalId] != ProposalState.Succeeded) {
            revert DAOGovernance__ProposalNotSucceeded();
        }
        
        if (block.timestamp < core.executionTime) {
            revert DAOGovernance__TimelockNotPassed();
        }

        if (core.ethAmount > address(treasury).balance) {
            revert DAOGovernance__InsufficientTreasuryBalance();
        }

        proposalExecutedAt[proposalId] = block.timestamp;
        proposalState[proposalId] = ProposalState.Executed;

        bytes memory returnData = treasury.executeTransaction(
            core.targetContract,
            core.ethAmount,
            proposalCallData[proposalId]
        );

        emit ProposalExecuted(proposalId, msg.sender, returnData);
    }

    /*//////////////////////////////////////////////////////////////
                        CANCELLATION
    //////////////////////////////////////////////////////////////*/
    
    function cancelProposal(uint256 proposalId) external nonReentrant {
        if (proposalId >= proposalCount) revert DAOGovernance__ProposalDoesNotExist();

        ProposalState currentState = proposalState[proposalId];
        
        if (currentState == ProposalState.Executed || currentState == ProposalState.Succeeded) {
            revert DAOGovernance__CannotCancelProposal();
        }

        ProposalCore memory core = proposalCore[proposalId];
        
        bool isProposer = msg.sender == core.proposer;
        bool proposerLostPower = treasury.balanceOf(core.proposer) < MIN_TOKENS_TO_PROPOSE;

        if (!isProposer && !proposerLostPower) {
            revert DAOGovernance__UnauthorizedCancel();
        }

        proposalState[proposalId] = ProposalState.Canceled;
        
        emit ProposalCanceled(proposalId, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    function _validateProposalParams(ProposalParams calldata params) internal view {
        uint256 titleLen = bytes(params.title).length;
        uint256 descLen = bytes(params.description).length;

        if (titleLen == 0) revert DAOGovernance__EmptyTitle();
        if (descLen == 0) revert DAOGovernance__EmptyDescription();
        if (titleLen > MAX_TITLE_LENGTH || descLen > MAX_DESCRIPTION_LENGTH) {
            revert DAOGovernance__StringTooLong();
        }

        if (params.targetContract == address(0)) revert DAOGovernance__InvalidAddress();
        if (treasury.balanceOf(msg.sender) < MIN_TOKENS_TO_PROPOSE) {
            revert DAOGovernance__NotEnoughTokens();
        }
    }

    function _calculateFinalState(uint256 proposalId) internal view returns (ProposalState) {
        VotingData memory votes = votingData[proposalId];
        uint256 totalVotes = votes.votesFor + votes.votesAgainst + votes.votesAbstain;

        uint256 totalSupply = treasury.totalSupply();
        if (totalSupply == 0) return ProposalState.Defeated;
        
        if(totalVotes == 0) return ProposalState.Defeated;
        
        uint256 quorumPercentage = (totalVotes * 100) / totalSupply;
        if (quorumPercentage < QUORUM_PERCENTAGE) return ProposalState.Defeated;

        uint256 forPercentage = (votes.votesFor * 100) / totalVotes;

        return forPercentage >= APPROVAL_THRESHOLD
            ? ProposalState.Succeeded
            : ProposalState.Defeated;
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Get full proposal details (for UI)
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
    
    function getProposal(uint256 proposalId) external view returns (ProposalView memory) {
        if (proposalId >= proposalCount) revert DAOGovernance__ProposalDoesNotExist();
        
        ProposalCore memory core = proposalCore[proposalId];
        VotingData memory votes = votingData[proposalId];
        
        return ProposalView({
            id: proposalId,
            title: proposalTitle[proposalId],
            description: proposalDescription[proposalId],
            proposer: core.proposer,
            targetContract: core.targetContract,
            callData: proposalCallData[proposalId],
            ethAmount: core.ethAmount,
            votesFor: votes.votesFor,
            votesAgainst: votes.votesAgainst,
            votesAbstain: votes.votesAbstain,
            startTime: core.startTime,
            endTime: core.endTime,
            executionTime: core.executionTime,
            executedAt: proposalExecutedAt[proposalId],
            state: proposalState[proposalId]
        });
    }
    
    function getProposalState(uint256 proposalId) external view returns (ProposalState) {
        if (proposalId >= proposalCount) revert DAOGovernance__ProposalDoesNotExist();
        return proposalState[proposalId];
    }

    function getProposalCount() external view returns (uint256) {
        return proposalCount;
    }

    function hasUserVoted(uint256 proposalId, address user) external view returns (bool) {
        if (proposalId >= proposalCount) revert DAOGovernance__ProposalDoesNotExist();
        return hasVoted[proposalId][user];
    }

    function getUserVote(uint256 proposalId, address user) external view returns (VoteType) {
        if (proposalId >= proposalCount) revert DAOGovernance__ProposalDoesNotExist();
        return userVote[proposalId][user];
    }

    function getVotingResults(
        uint256 proposalId
    )
        external
        view
        returns (
            uint256 votesFor,
            uint256 votesAgainst,
            uint256 votesAbstain,
            uint256 totalVotes,
            uint256 totalSupply,
            bool quorumReached
        )
    {
        if (proposalId >= proposalCount) revert DAOGovernance__ProposalDoesNotExist();

        VotingData memory votes = votingData[proposalId];

        votesFor = votes.votesFor;
        votesAgainst = votes.votesAgainst;
        votesAbstain = votes.votesAbstain;
        totalVotes = votesFor + votesAgainst + votesAbstain;
        totalSupply = treasury.totalSupply();
        quorumReached = totalSupply > 0 && (totalVotes * 100) / totalSupply >= QUORUM_PERCENTAGE;
    }
}