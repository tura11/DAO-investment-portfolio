// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { DAOTreasury } from "./DAOTreasury.sol";

contract DAOGovernance is ReentrancyGuard {
    error DAOGovernance__StringTooLong();
    error DAOGovernance__InvalidAddress();
    error DAOGovernance__NotEnoughTokens();
    error DAOGovernance__EmptyTitle();
    error DAOGovernance__EmptyDescription();
    error DAOGovernance__ProposalDoesNotExisit();
    error DAOGovernance__VotingNotActive();
    error DAOGovernance__AlreadyVoted();
    error DAOGovernance__NoVotingPower();
    error DAOGovernance__ProposalNotSucceeded();
    error DAOGovernance__ProposalAlreadyExecuted();
    error DAOGovernance__InsufficientTresuryBalance();

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
        
        ProposalState state;
    }

    Proposal[] public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => mapping(address => VoteType)) public userVote;

    uint256 public proposalCount;
    DAOTreasury public immutable treasury;

    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant TIMELOCK_PERIOD = 2 days;
    uint256 public constant QUORUM_PERCENTAGE = 30;
    uint256 public constant APPROVAL_THRESHOLD = 51;
    uint256 public constant MIN_TOKENS_TO_PROPOSE = 10 ether;
    uint256 public constant MAX_TITLE_LENGTH = 100;
    uint256 public constant MAX_DESCRIPTION_LENGTH = 500;

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
        address voter,
        VoteType voteType
    );
    event ProposalExecuted(
        uint256 indexed proposalId,
        address indexed executor,
        bytes returnData
    );

    constructor(address _treasury) {
        if(_treasury == address(0)) {
            revert DAOGovernance__InvalidAddress();
        }
        treasury = DAOTreasury(_treasury);
    }

    function createProposal(
        string memory _title,
        string memory _description,
        address _targetContract,
        bytes memory _callData,
        uint256 _ethAmount
    ) external nonReentrant returns (uint256) {

        if(bytes(_title).length == 0) {
            revert DAOGovernance__EmptyTitle();
        }
        if(bytes(_title).length > MAX_TITLE_LENGTH || bytes(_description).length > MAX_DESCRIPTION_LENGTH) {
            revert DAOGovernance__StringTooLong();
        }
        if(bytes(_description).length == 0) {
            revert DAOGovernance__EmptyDescription();
        }
        if(_targetContract == address(0)) {
            revert DAOGovernance__InvalidAddress();
        }
        if(treasury.balanceOf(msg.sender) < MIN_TOKENS_TO_PROPOSE) {
            revert DAOGovernance__NotEnoughTokens();
        }

        // Create proposal
        uint256 newProposalId = proposalCount;
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + VOTING_PERIOD;
        uint256 executionTime = endTime + TIMELOCK_PERIOD;

        Proposal memory newProposal = Proposal({
            id: newProposalId,
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
            executionTime: executionTime,
            executedAt: 0,
            state: ProposalState.Active 
        });

        proposals.push(newProposal);
        proposalCount++;

        emit ProposalCreated(
            newProposalId,
            msg.sender,
            _title,
            _targetContract,
            _ethAmount,
            startTime,
            endTime
        );

        return newProposalId;
    }


    function vote(uint256 proposalId, VoteType vote) external nonReentrant {
        if(proposalId >= proposalCount) {
            revert DAOGovernance__ProposalDoesNotExisit();
        }
        Proposal storage proposal = proposals[proposalId];

        if(block.timestamp < proposal.startTime || block.timestamp > proposal.endTime) {
            revert DAOGovernance__VotingNotActive();
        }

        if(hasVoted[proposalId][msg.sender]) {
            revert DAOGovernance__AlreadyVoted();
        }

        uint256 votingPower = treasury.balanceOf(msg.sender);
        if(votingPower == 0) {
            revert DAOGovernance__NoVotingPower();
        }

        hasVoted[proposalId][msg.sender] = true;
        userVote[proposalId][msg.sender] = voteType;

        if(voteType == VoteType.For) {
            proposal.votesFor += votingPower;
        } else if(voteType == VoteType.Against) {
            proposal.votesAgainst += votingPower;
        } else {
            proposal.votesAbstain += votingPower;
        }
        emit VoteCast(msg.sender, proposalId, voteType);
    }

    function executeProposal(uint256 proposalId) external nonReentrant {
        if(proposalId >= proposalCount) {
            revert DAOGovernance__ProposalDoesNotExisit();
        }

        Proposal storage proposal = proposals[proposalId];


        ProposalState currentState = getProposalState(proposalId); 
        if(currentState != ProposalState.Succeeded) {
            revert DAOGovernance__ProposalNotSucceeded();
        }


        if(block.timestamp < proposal.executionTime) {
            revert DAOGovernance__VotingNotActive();
        }


        if(proposal.executedAt > 0) {
            revert DAOGovernance__ProposalAlreadyExecuted();
        }

        if(proposal.ethAmount > 0) {
            if(address(treasury).balance < proposal.ethAmount) {
                revert DAOGovernance__InsufficientTresuryBalance();
            }
        }

        proposal.executedAt = block.timestamp;
        proposal.state = ProposalState.Executed;

        (bool success, bytes memory returnData) = proposal.targetContract.call{
            value: proposal.ethAmount
        }(proposal.callData);

        if(!success) {
            revert DAOGovernance__ExecutionFailed();
        }


        emit ProposalExecuted(proposalId, msg.sender, returnData);
    }

    function getProposalState(uint256 proposalId) external view returns (ProposalState) {
        if(proposalId >= proposalCount) {
            revert DAOGovernance__ProposalDoesNotExisit();
        }

        if(proposal.state == ProposalState.Canceled){
            return ProposalState.Canceled;
        }

        if(block.timestamp <= proposal.endTime) {
            return ProposalState.Active;
        }

        uint256 totalVotes = proposal.votesFor + proposal.votesAgainst + proposal.votesAbstain;
        uint256 totalSupply = treasury.totalSupply();


        bool quorumReached = (totalVotes * 100 / totalSupply) >= QUORUM_PERCENTAGE;

        if(!quorumReached) {
            return ProposalState.Defeated;
        }

        uint256 forPercentage = (proposal.votesFor * 100) / totalVotes;

        if(forPercentage >= APPROVAL_THRESHOLD) {
            return ProposalState.Succeeded;
        }else{
            return ProposalState.Defeated;
        }
    }


    function getProposal(uint256 proposalId) external view returns (Proposal memory) {
        require(proposalId < proposalCount, "Invalid proposal ID");
        return proposals[proposalId];
    }

    function getProposalCount() external view returns (uint256) {
        return proposalCount;
    }

    function hasUserVoted(address user, uint256 proposalId) external view returns (bool) {
        return hasVoted[proposalId][user];
    }

    function getUserVote(address user, uint256 proposalId) external view returns (VoteType) {
        return userVote[proposalId][user];
    }
}