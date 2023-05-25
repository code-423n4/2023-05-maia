// SPDX-License-Identifier: MIT
// Voting logic inspired by OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/ERC20Votes.sol)
pragma solidity ^0.8.0;

/**
 * @title ERC20 Multi-Delegation Voting contract
 *  @notice an ERC20 extension that allows delegations to multiple delegatees up to a user's balance on a given block.
 */
interface IERC20MultiVotes {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice A checkpoint for marking the number of votes from a given block.
     * @param fromBlock the block number that the votes were delegated.
     * @param votes the number of votes delegated.
     */
    struct Checkpoint {
        uint32 fromBlock;
        uint224 votes;
    }

    /*///////////////////////////////////////////////////////////////
                        VOTE CALCULATION LOGIC
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Get the `pos`-th checkpoint for `account`.
     */
    function checkpoints(address account, uint32 pos) external view returns (Checkpoint memory);

    /**
     * @notice Get number of checkpoints for `account`.
     */
    function numCheckpoints(address account) external view returns (uint32);

    /**
     * @notice Gets the amount of unallocated votes for `account`.
     * @param account the address to get free votes of.
     * @return the amount of unallocated votes.
     */
    function freeVotes(address account) external view returns (uint256);

    /**
     * @notice Gets the current votes balance for `account`.
     * @param account the address to get votes of.
     * @return the amount of votes.
     */
    function getVotes(address account) external view returns (uint256);

    /**
     * @notice helper function exposing the amount of weight available to allocate for a user
     */
    function userUnusedVotes(address user) external view returns (uint256);

    /**
     * @notice Retrieve the number of votes for `account` at the end of `blockNumber`.
     * @param account the address to get votes of.
     * @param blockNumber the block to calculate votes for.
     * @return the amount of votes.
     */
    function getPriorVotes(address account, uint256 blockNumber) external view returns (uint256);

    /*///////////////////////////////////////////////////////////////
                        ADMIN OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice the maximum amount of delegates for a user at a given time
     */
    function maxDelegates() external view returns (uint256);

    /**
     * @notice an approve list for contracts to go above the max delegate limit.
     */
    function canContractExceedMaxDelegates(address) external view returns (bool);

    /**
     * @notice set the new max delegates per user. Requires auth by `authority`.
     */
    function setMaxDelegates(uint256 newMax) external;

    /**
     * @notice set the canContractExceedMaxDelegates flag for an account.
     */
    function setContractExceedMaxDelegates(address account, bool canExceedMax) external;

    /**
     * @notice mapping from a delegator to the total number of delegated votes.
     */
    function userDelegatedVotes(address) external view returns (uint256);

    /*///////////////////////////////////////////////////////////////
                        DELEGATION LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get the amount of votes currently delegated by `delegator` to `delegatee`.
     * @param delegator the account which is delegating votes to `delegatee`.
     * @param delegatee the account receiving votes from `delegator`.
     * @return the total amount of votes delegated to `delegatee` by `delegator`
     */
    function delegatesVotesCount(address delegator, address delegatee) external view returns (uint256);

    /**
     * @notice Get the list of delegates from `delegator`.
     * @param delegator the account which is delegating votes to delegates.
     * @return the list of delegated accounts.
     */
    function delegates(address delegator) external view returns (address[] memory);

    /**
     * @notice Get the number of delegates from `delegator`.
     * @param delegator the account which is delegating votes to delegates.
     * @return the number of delegated accounts.
     */
    function delegateCount(address delegator) external view returns (uint256);

    /**
     * @notice Delegate `amount` votes from the sender to `delegatee`.
     * @param delegatee the receivier of votes.
     * @param amount the amount of votes received.
     * @dev requires "freeVotes(msg.sender) > amount" and will not exceed max delegates
     */
    function incrementDelegation(address delegatee, uint256 amount) external;

    /**
     * @notice Undelegate `amount` votes from the sender from `delegatee`.
     * @param delegatee the receivier of undelegation.
     * @param amount the amount of votes taken away.
     */
    function undelegate(address delegatee, uint256 amount) external;

    /**
     * @notice Delegate all votes `newDelegatee`. First undelegates from an existing delegate. If `newDelegatee` is zero, only undelegates.
     * @param newDelegatee the receiver of votes.
     * @dev undefined for `delegateCount(msg.sender) > 1`
     * NOTE This is meant for backward compatibility with the `ERC20Votes` and `ERC20VotesComp` interfaces from OpenZeppelin.
     */
    function delegate(address newDelegatee) external;

    /*///////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice emitted when updating the maximum amount of delegates per user
    event MaxDelegatesUpdate(uint256 oldMaxDelegates, uint256 newMaxDelegates);

    /// @notice emitted when updating the canContractExceedMaxDelegates flag for an account
    event CanContractExceedMaxDelegatesUpdate(address indexed account, bool canContractExceedMaxDelegates);

    /// @dev Emitted when a `delegator` delegates `amount` votes to `delegate`.
    event Delegation(address indexed delegator, address indexed delegate, uint256 amount);

    /// @dev Emitted when a `delegator` undelegates `amount` votes from `delegate`.
    event Undelegation(address indexed delegator, address indexed delegate, uint256 amount);

    /// @dev Emitted when a token transfer or delegate change results in changes to an account's voting power.
    event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);

    /// @notice An event thats emitted when an account changes its delegate
    /// @dev this is used for backward compatibility with OZ interfaces for ERC20Votes and ERC20VotesComp.
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

    /*///////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice thrown when trying to read from an invalid block.
    error BlockError();

    /// @dev thrown when attempting to delegate more votes than an address has free, or exceeding the max delegates
    error DelegationError();

    /// @dev thrown when attempting to undelegate more votes than the delegatee has unused.
    error UndelegationVoteError();
}
