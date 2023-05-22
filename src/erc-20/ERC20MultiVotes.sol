// SPDX-License-Identifier: MIT
// Voting logic inspired by OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/ERC20Votes.sol)

pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {EnumerableSet} from "@lib/EnumerableSet.sol";

import {IBaseV2Gauge} from "@gauges/interfaces/IBaseV2Gauge.sol";

import {Errors} from "./interfaces/Errors.sol";
import {IERC20MultiVotes} from "./interfaces/IERC20MultiVotes.sol";

/// @title ERC20 Multi-Delegation Voting contract
abstract contract ERC20MultiVotes is ERC20, Ownable, IERC20MultiVotes {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeCastLib for *;

    /*///////////////////////////////////////////////////////////////
                        VOTE CALCULATION LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice votes checkpoint list per user.
    mapping(address => Checkpoint[]) private _checkpoints;

    /// @inheritdoc IERC20MultiVotes
    function checkpoints(address account, uint32 pos) public view virtual returns (Checkpoint memory) {
        return _checkpoints[account][pos];
    }

    /// @inheritdoc IERC20MultiVotes
    function numCheckpoints(address account) public view virtual returns (uint32) {
        return _checkpoints[account].length.toUint32();
    }

    /// @inheritdoc IERC20MultiVotes
    function freeVotes(address account) public view virtual returns (uint256) {
        return balanceOf[account] - userDelegatedVotes[account];
    }

    /// @inheritdoc IERC20MultiVotes
    function getVotes(address account) public view virtual returns (uint256) {
        uint256 pos = _checkpoints[account].length;
        return pos == 0 ? 0 : _checkpoints[account][pos - 1].votes;
    }

    /// @inheritdoc IERC20MultiVotes
    function userUnusedVotes(address user) public view virtual returns (uint256) {
        return getVotes(user);
    }

    /// @inheritdoc IERC20MultiVotes
    function getPriorVotes(address account, uint256 blockNumber) public view virtual returns (uint256) {
        if (blockNumber >= block.number) revert BlockError();
        return _checkpointsLookup(_checkpoints[account], blockNumber);
    }

    /// @dev Lookup a value in a list of (sorted) checkpoints.
    function _checkpointsLookup(Checkpoint[] storage ckpts, uint256 blockNumber) private view returns (uint256) {
        // We run a binary search to look for the earliest checkpoint taken after `blockNumber`.
        uint256 high = ckpts.length;
        uint256 low = 0;
        while (low < high) {
            uint256 mid = average(low, high);
            if (ckpts[mid].fromBlock > blockNumber) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        return high == 0 ? 0 : ckpts[high - 1].votes;
    }

    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /*///////////////////////////////////////////////////////////////
                        ADMIN OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC20MultiVotes
    uint256 public override maxDelegates;

    /// @inheritdoc IERC20MultiVotes
    mapping(address => bool) public override canContractExceedMaxDelegates;

    /// @inheritdoc IERC20MultiVotes
    function setMaxDelegates(uint256 newMax) external onlyOwner {
        uint256 oldMax = maxDelegates;
        maxDelegates = newMax;

        emit MaxDelegatesUpdate(oldMax, newMax);
    }

    /// @inheritdoc IERC20MultiVotes
    function setContractExceedMaxDelegates(address account, bool canExceedMax) external onlyOwner {
        if (canExceedMax && account.code.length == 0) revert Errors.NonContractError(); // can only approve contracts

        canContractExceedMaxDelegates[account] = canExceedMax;

        emit CanContractExceedMaxDelegatesUpdate(account, canExceedMax);
    }

    /*///////////////////////////////////////////////////////////////
                        DELEGATION LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice How many votes a user has delegated to a delegatee.
    mapping(address => mapping(address => uint256)) private _delegatesVotesCount;

    /// @notice How many votes a user has delegated to him.
    mapping(address => uint256) public userDelegatedVotes;

    /// @notice The delegatees of a user.
    mapping(address => EnumerableSet.AddressSet) private _delegates;

    /// @inheritdoc IERC20MultiVotes
    function delegatesVotesCount(address delegator, address delegatee) public view virtual returns (uint256) {
        return _delegatesVotesCount[delegator][delegatee];
    }

    /// @inheritdoc IERC20MultiVotes
    function delegates(address delegator) public view returns (address[] memory) {
        return _delegates[delegator].values();
    }

    /// @inheritdoc IERC20MultiVotes
    function delegateCount(address delegator) public view returns (uint256) {
        return _delegates[delegator].length();
    }

    /// @inheritdoc IERC20MultiVotes
    function incrementDelegation(address delegatee, uint256 amount) public virtual {
        _incrementDelegation(msg.sender, delegatee, amount);
    }

    /// @inheritdoc IERC20MultiVotes
    function undelegate(address delegatee, uint256 amount) public virtual {
        _undelegate(msg.sender, delegatee, amount);
    }

    /// @inheritdoc IERC20MultiVotes
    function delegate(address newDelegatee) external virtual {
        _delegate(msg.sender, newDelegatee);
    }

    /**
     * @notice Delegates all votes from `delegator` to `delegatee`
     * @dev Reverts if delegateCount > 1
     * @param delegator The address to delegate votes from
     * @param newDelegatee The address to delegate votes to
     */
    function _delegate(address delegator, address newDelegatee) internal virtual {
        uint256 count = delegateCount(delegator);

        // undefined behavior for delegateCount > 1
        if (count > 1) revert DelegationError();

        address oldDelegatee;
        // if already delegated, undelegate first
        if (count == 1) {
            oldDelegatee = _delegates[delegator].at(0);
            _undelegate(delegator, oldDelegatee, _delegatesVotesCount[delegator][oldDelegatee]);
        }

        // redelegate only if newDelegatee is not empty
        if (newDelegatee != address(0)) {
            _incrementDelegation(delegator, newDelegatee, freeVotes(delegator));
        }
        emit DelegateChanged(delegator, oldDelegatee, newDelegatee);
    }

    /**
     * @notice Delegates votes from `delegator` to `delegatee`
     * @dev Reverts if delegator is not approved and exceeds maxDelegates
     * @param delegator The address to delegate votes from
     * @param delegatee The address to delegate votes to
     * @param amount The amount of votes to delegate
     */
    function _incrementDelegation(address delegator, address delegatee, uint256 amount) internal virtual {
        // Require freeVotes exceed the delegation size
        uint256 free = freeVotes(delegator);
        if (delegatee == address(0) || free < amount || amount == 0) revert DelegationError();

        bool newDelegate = _delegates[delegator].add(delegatee); // idempotent add
        if (newDelegate && delegateCount(delegator) > maxDelegates && !canContractExceedMaxDelegates[delegator]) {
            // if is a new delegate, exceeds max and is not approved to exceed, revert
            revert DelegationError();
        }

        _delegatesVotesCount[delegator][delegatee] += amount;
        userDelegatedVotes[delegator] += amount;

        emit Delegation(delegator, delegatee, amount);
        _writeCheckpoint(delegatee, _add, amount);
    }

    /**
     * @notice Undelegates votes from `delegator` to `delegatee`
     * @dev Reverts if delegatee does not have enough free votes
     * @param delegator The address to undelegate votes from
     * @param delegatee The address to undelegate votes to
     * @param amount The amount of votes to undelegate
     */
    function _undelegate(address delegator, address delegatee, uint256 amount) internal virtual {
        /**
         * @dev delegatee needs to have sufficient free votes for delegator to undelegate.
         *         Delegatee needs to be trusted, can be either a contract or an EOA.
         *         If delegatee does not have any free votes and doesn't change their vote delegator won't be able to undelegate.
         *         If it is a contract, a possible safety measure is to have an emergency clear votes.
         */
        if (userUnusedVotes(delegatee) < amount) revert UndelegationVoteError();

        uint256 newDelegates = _delegatesVotesCount[delegator][delegatee] - amount;

        if (newDelegates == 0) {
            require(_delegates[delegator].remove(delegatee));
        }

        _delegatesVotesCount[delegator][delegatee] = newDelegates;
        userDelegatedVotes[delegator] -= amount;

        emit Undelegation(delegator, delegatee, amount);
        _writeCheckpoint(delegatee, _subtract, amount);
    }

    /**
     * @notice Writes a checkpoint for `delegatee` with `delta` votes
     * @param delegatee The address to write a checkpoint for
     * @param op The operation to perform on the checkpoint
     * @param delta The difference in votes to write
     */
    function _writeCheckpoint(address delegatee, function(uint256, uint256) view returns (uint256) op, uint256 delta)
        private
    {
        Checkpoint[] storage ckpts = _checkpoints[delegatee];

        uint256 pos = ckpts.length;
        uint256 oldWeight = pos == 0 ? 0 : ckpts[pos - 1].votes;
        uint256 newWeight = op(oldWeight, delta);

        if (pos > 0 && ckpts[pos - 1].fromBlock == block.number) {
            ckpts[pos - 1].votes = newWeight.toUint224();
        } else {
            ckpts.push(Checkpoint({fromBlock: block.number.toUint32(), votes: newWeight.toUint224()}));
        }
        emit DelegateVotesChanged(delegatee, oldWeight, newWeight);
    }

    function _add(uint256 a, uint256 b) private pure returns (uint256) {
        return a + b;
    }

    function _subtract(uint256 a, uint256 b) private pure returns (uint256) {
        return a - b;
    }

    /*///////////////////////////////////////////////////////////////
                             ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    /// NOTE: any "removal" of tokens from a user requires freeVotes(user) < amount.
    /// _decrementVotesUntilFree is called as a greedy algorithm to free up votes.
    /// It may be more gas efficient to free weight before burning or transferring tokens.

    /**
     * @notice Burns `amount` of tokens from `from` address.
     * @dev Frees votes with a greedy algorithm if needed to burn tokens
     * @param from The address to burn tokens from.
     * @param amount The amount of tokens to burn.
     */
    function _burn(address from, uint256 amount) internal virtual override {
        _decrementVotesUntilFree(from, amount);
        super._burn(from, amount);
    }

    /**
     * @notice Transfers `amount` of tokens from `msg.sender` to `to` address.
     * @dev Frees votes with a greedy algorithm if needed to burn tokens
     * @param to the address to transfer to.
     * @param amount the amount to transfer.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        _decrementVotesUntilFree(msg.sender, amount);
        return super.transfer(to, amount);
    }

    /**
     * @notice Transfers `amount` of tokens from `from` address to `to` address.
     * @dev Frees votes with a greedy algorithm if needed to burn tokens
     * @param from the address to transfer from.
     * @param to the address to transfer to.
     * @param amount the amount to transfer.
     */
    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        _decrementVotesUntilFree(from, amount);
        return super.transferFrom(from, to, amount);
    }

    /**
     * @notice A greedy algorithm for freeing votes before a token burn/transfer
     * @dev Frees up entire delegates, so likely will free more than `votes`
     * @param user The address to free votes from.
     * @param votes The amount of votes to free.
     */
    function _decrementVotesUntilFree(address user, uint256 votes) internal {
        uint256 userFreeVotes = freeVotes(user);

        // early return if already free
        if (userFreeVotes >= votes) return;

        // cache total for batch updates
        uint256 totalFreed;

        // Loop through all delegates
        address[] memory delegateList = _delegates[user].values();

        // Free gauges through the entire list or until underweight
        uint256 size = delegateList.length;
        for (uint256 i = 0; i < size && (userFreeVotes + totalFreed) < votes; i++) {
            address delegatee = delegateList[i];
            uint256 delegateVotes = _delegatesVotesCount[user][delegatee];
            // Minimum of votes delegated to delegatee and unused votes of delegatee
            uint256 votesToFree = FixedPointMathLib.min(delegateVotes, userUnusedVotes(delegatee));
            // Skip if votesToFree is zero
            if (votesToFree != 0) {
                totalFreed += votesToFree;

                if (delegateVotes == votesToFree) {
                    // If all votes are freed, remove delegatee from list
                    require(_delegates[user].remove(delegatee)); // Remove from set. Should never fail.
                    _delegatesVotesCount[user][delegatee] = 0;
                } else {
                    // If not all votes are freed, update the votes count
                    _delegatesVotesCount[user][delegatee] -= votesToFree;
                }

                _writeCheckpoint(delegatee, _subtract, votesToFree);
                emit Undelegation(user, delegatee, votesToFree);
            }
        }

        if ((userFreeVotes + totalFreed) < votes) revert UndelegationVoteError();

        userDelegatedVotes[user] -= totalFreed;
    }

    /*///////////////////////////////////////////////////////////////
                             EIP-712 LOGIC
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    function delegateBySig(address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) public {
        require(block.timestamp <= expiry, "ERC20MultiVotes: signature expired");
        address signer = ecrecover(
            keccak256(
                abi.encodePacked(
                    "\x19\x01", DOMAIN_SEPARATOR(), keccak256(abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry))
                )
            ),
            v,
            r,
            s
        );
        require(nonce == nonces[signer]++, "ERC20MultiVotes: invalid nonce");
        require(signer != address(0));
        _delegate(signer, delegatee);
    }
}
