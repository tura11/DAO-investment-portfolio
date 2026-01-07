// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;



contract DAOGovernance {

    enum ProposalState {
        Pending,    // Propozycja utworzona, czeka na start głosowania
        Active,     // Trwa głosowanie
        Succeeded,  // Głosowanie zakończone - PASSED
        Defeated,   // Głosowanie zakończone - FAILED
        Executed,   // Propozycja wykonana
        Canceled    // Propozycja anulowana
    }

    enum VoteType {
        Against,    // 0
        For,        // 1
        Abstain     // 2
    }

    struct Proposal {
        uint256 id;
        string title;             
        string description;         
        address proposer;
        address targetContract;     
        bytes callData;             
        uint256 ethAmount;          
        
        // Voting results
        uint256 votesFor;     
        uint256 votesAgainst;       
        uint256 votesAbstain;       
        
        // Timestamps
        uint256 startTime;          
        uint256 endTime;          
        uint256 executionTime;      
        uint256 executedAt;        
        
        ProposalState state;
    }


    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => mapping(address => VoteType)) public userVote;


    uint256 proposalCount;

    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant TIMELOCK_PERIOD = 2 days;
    uint256 public constant QUORUM_PERCENTAGE = 30; // 30% of aall tokens have to vote
    uint256 public constant APPROVAL_THRESHOLD = 51;  // 51% of votes for
    uint256 public constant MIN_TOKENS_TO_PROPOSE = 10 ether; // 10 tokens

}