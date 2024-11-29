// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";

/// @title Interface for the CryptoAnts ERC721 contract.
interface ICryptoAnts is IERC721 {
    /// @notice Sets the price of eggs.
    /// @param _price The new price of eggs.
    function SetEggsPrice(uint256 _price) external;
}

/// @title Interface for the governance contract.
interface IGovernance {
    /// @notice Emitted when new proposal is created.
    event ProposalCreated(
        uint256 indexed proposalId,
        uint256 newPrice,
        uint256 startTime
    );

    /// @notice Emitted when Token holder have voted for proposal.
    event Voted(uint256 indexed proposalId, address indexed voter, bool vote);

    /// @notice Emitted when proposal is executed.
    event ProposalExecuted(uint256 indexed proposalId);

    /// @dev Custom error message for unauthorized access.
    error NotAuthorized();

    /// @dev Custom error message for only token holders being allowed to vote.
    error onlyTokenHolderscanVote();

    /// @dev Custom error message for wrong price.
    error WrongPrice();

    /// @dev Custom error message for invalid proposal ID.
    error InvalidProposalID();

    /// @dev Custom error message for already executed proposal.
    error Proposal_Executed();

    /// @dev Custom error message for already voted proposal.
    error AlreadyVoted();

    /// @dev Custom error message for voting period ended.
    error VotingPeriodEnded();

    /// @dev Custom error message for voting period not ended.
    error VotingPeriodNotEnded();

    /// @dev Custom error message for execution failure.
    error ExecutionFailed();

    /// @notice Creates a proposal to change the price of eggs.
    /// @param _newPrice The new price of eggs.
    function createProposal(uint256 _newPrice) external;

    /// @notice Votes on a proposal.
    /// @param _proposalId The ID of the proposal.
    /// @param _vote The vote (true for yes, false for no).
    function vote(uint256 _proposalId, bool _vote) external;

    /// @notice Executes a proposal if it passes.
    /// @param _proposalId The ID of the proposal.
    function executeProposal(uint256 _proposalId) external;
}

/// @title Governance contract for managing proposals and voting.
contract Governance is IGovernance, Context {
    // Define the time duration for voting (in seconds)
    uint256 public constant VOTING_DURATION = 4 hours;

    address public governor; // The address with governance rights
    IERC20 public immutable tokenContract;
    ICryptoAnts public immutable CryptoAnts;

    struct Proposal {
        uint256 id;
        uint256 newPrice;
        uint256 startTime; // Start time of the proposal
        bool executed;
        address[] voters; // Track addresses of token holders who voted
    }

    mapping(uint256 => mapping(address => bool)) public votes; // Proposal ID => Voter => Voted
    Proposal[] public proposals;

    constructor(address _tokenContract, address _CryptoAnts) {
        governor = _msgSender();
        tokenContract = IERC20(_tokenContract);
        CryptoAnts = ICryptoAnts(_CryptoAnts);
    }
    /**
     * @dev Modifier to restrict access to the governor only.
     */
    modifier onlyGovernor() {
        require(_msgSender() == governor, "NotAuthorized");
        _;
    }

    /**
     * @dev Modifier to allow only token holders to vote.
     */
    modifier onlyTokenHolders() {
        require(
            tokenContract.balanceOf(_msgSender()) > 0,
            "OnlyTokenHoldersCanVote"
        );
        _;
    }

    /**
     * @notice Creates a new proposal to change the price of eggs.
     * @dev This function is part of the governance system and can only be called by the designated governor.
     * @param _newPrice The new price of eggs proposed to be set.
     */
    function createProposal(uint256 _newPrice) external onlyGovernor {
        require(_newPrice > 0, "WrongPrice");

        // Generate a unique proposal ID
        uint256 proposalId = proposals.length;

        // Initialize an empty array for voters
        address[] memory emptyArray;

        // Create a new Proposal object and add it to the proposals array
        proposals.push(
            Proposal(proposalId, _newPrice, block.timestamp, false, emptyArray)
        );

        // Emit an event to notify observers about the creation of the proposal
        emit ProposalCreated(proposalId, _newPrice, block.timestamp);
    }

    /**
     * @notice Checks whether the specified `_voter` is present in the array of voters within the Proposal struct.
     * @param _proposalId The ID of the proposal.
     * @param _voter The address of the voter to be checked.
     * @return A boolean indicating whether the voter has cast a vote for the given proposal.
     */
    function hasVoted(
        uint256 _proposalId,
        address _voter
    ) internal view returns (bool) {
        address[] memory voters = proposals[_proposalId].voters;

        for (uint256 i = 0; i < voters.length; i++) {
            if (voters[i] == _voter) {
                return true; // Voter found, exit loop and function
            }
        }

        return false; // Voter not found after iterating through all voters
    }

    /**
     * @notice Allows token holders to cast their votes on a proposal.
     * @dev This function is part of the governance system and can only be called by token holders.
     * @param _proposalId The ID of the proposal on which the voter wants to cast their vote.
     * @param _vote A boolean indicating the choice of the voter (true for yes, false for no).
     */
    function vote(uint256 _proposalId, bool _vote) external onlyTokenHolders {
        require(_proposalId < proposals.length, "InvalidProposalID");
        require(!proposals[_proposalId].executed, "Proposal_Executed");
        require(!hasVoted(_proposalId, _msgSender()), "AlreadyVoted");
        require(
            block.timestamp <
                proposals[_proposalId].startTime + VOTING_DURATION,
            "VotingPeriodEnded"
        );

        proposals[_proposalId].voters.push(_msgSender());
        votes[_proposalId][_msgSender()] = _vote;

        emit Voted(_proposalId, _msgSender(), _vote);
    }

    /**
     * @notice Executes a proposal if conditions are met, based on the outcome of a voting process.
     * @dev This function is part of the governance system and can only be called by the designated governor.
     * @param _proposalId The ID of the proposal to be executed.
     */
    function executeProposal(uint256 _proposalId) external onlyGovernor {
        require(_proposalId < proposals.length, "InvalidProposalID");
        require(!proposals[_proposalId].executed, "Proposal_Executed");
        require(
            block.timestamp >=
                proposals[_proposalId].startTime + VOTING_DURATION,
            "VotingPeriodNotEnded"
        );

        uint256 totalVotes = proposals[_proposalId].voters.length;
        uint256 favorableVotes = 0;

        for (uint256 i = 0; i < totalVotes; i++) {
            if (votes[_proposalId][proposals[_proposalId].voters[i]]) {
                favorableVotes++;
            }
        }

        if (favorableVotes > totalVotes / 2) {
            (bool success, ) = address(CryptoAnts).call(
                abi.encodeWithSignature(
                    "SetEggsPrice(uint256)",
                    proposals[_proposalId].newPrice
                )
            );
            require(success, "ExecutionFailed");

            proposals[_proposalId].executed = true;
            emit ProposalExecuted(_proposalId);
        }
    }
}
