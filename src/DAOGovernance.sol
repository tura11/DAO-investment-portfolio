// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { DAOTreasury } from "./DAOTreasury.sol";

contract DAOGovernance is ReentrancyGuard {
    error DAOGovernance__StringTooLong();
    error DAOGovernance__InvalidAddress();
    error DAOGovernance__NotEnoughTokens();
    error DAOGovernance__EmptyTitle();

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
        // Validation
        if(bytes(_title).length == 0) {
            revert DAOGovernance__EmptyTitle();
        }
        if(bytes(_title).length > MAX_TITLE_LENGTH || bytes(_description).length > MAX_DESCRIPTION_LENGTH) {
            revert DAOGovernance__StringTooLong();
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
            state: ProposalState.Active  // ✅ Od razu Active
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

    // Getter functions
    function getProposal(uint256 proposalId) external view returns (Proposal memory) {
        require(proposalId < proposalCount, "Invalid proposal ID");
        return proposals[proposalId];
    }

    function getProposalCount() external view returns (uint256) {
        return proposalCount;
    }
}