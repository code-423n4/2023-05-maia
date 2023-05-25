// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {UlyssesERC4626} from "@ERC4626/UlyssesERC4626.sol";

import {UlyssesFactory} from "./factories/UlyssesFactory.sol";

import {IUlyssesPool} from "./interfaces/IUlyssesPool.sol";

/// @title Ulysses Pool - Single Sided Stableswap LP
/// @author Maia DAO (https://github.com/Maia-DAO)
contract UlyssesPool is UlyssesERC4626, Ownable, IUlyssesPool {
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;
    using SafeCastLib for uint256;

    /// @notice ulysses factory associated with the Ulysses LP
    UlyssesFactory public immutable factory;

    /// @notice ID of this Ulysses LP
    uint256 public immutable id;

    /// @notice List of all added LPs
    BandwidthState[] public bandwidthStateList;

    /// @notice destinations[destinationId] => bandwidthStateList index
    mapping(uint256 => uint256) public destinations;

    /// @notice destinationIds[address] => destinationId
    mapping(address => uint256) public destinationIds;

    /// @notice Sum of all weights
    uint256 public totalWeights;

    /// @notice The minimum amount that can be swapped
    uint256 private constant MIN_SWAP_AMOUNT = 1e4;

    /// @notice The maximum sum of all weights
    uint256 private constant MAX_TOTAL_WEIGHT = 256;

    /// @notice The maximum destinations that can be added
    uint256 private constant MAX_DESTINATIONS = 15;

    /// @notice The maximum protocol fee that can be set (1%)
    uint256 private constant MAX_PROTOCOL_FEE = 1e16;

    /// @notice The maximum lambda1 that can be set (10%)
    uint256 private constant MAX_LAMBDA1 = 1e17;

    /// @notice The minimum sigma2 that can be set (1%)
    uint256 private constant MIN_SIGMA2 = 1e16;

    /*//////////////////////////////////////////////////////////////
                            FEE PARAMETERS
    //////////////////////////////////////////////////////////////*/

    /// @notice The divisioner for fee calculations
    uint256 private constant DIVISIONER = 1 ether;

    uint256 public protocolFee = 1e14;

    /// @notice The current rebalancing fees
    Fees public fees = Fees({lambda1: 20e14, lambda2: 4980e14, sigma1: 6000e14, sigma2: 500e14});

    /**
     * @param _id the Ulysses LP ID
     * @param _asset the underlying asset
     * @param _name the name of the LP
     * @param _symbol the symbol of the LP
     * @param _owner the owner of this contract
     * @param _factory the Ulysses factory
     */
    constructor(
        uint256 _id,
        address _asset,
        string memory _name,
        string memory _symbol,
        address _owner,
        address _factory
    ) UlyssesERC4626(_asset, _name, _symbol) {
        require(_owner != address(0));
        factory = UlyssesFactory(_factory);
        _initializeOwner(_owner);
        require(_id != 0);
        id = _id;

        bandwidthStateList.push(BandwidthState({bandwidth: 0, destination: UlyssesPool(address(0)), weight: 0}));
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // @inheritdoc UlyssesERC4626
    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this)) - getProtocolFees();
    }

    // @inheritdoc UlyssesERC4626
    function maxRedeem(address owner) public view override returns (uint256) {
        return balanceOf[owner].min(asset.balanceOf(address(this)));
    }

    /// @inheritdoc IUlyssesPool
    function getBandwidth(uint256 destinationId) external view returns (uint256) {
        /**
         * @dev bandwidthStateList first element has always 0 bandwidth
         *      so this line will never fail and return 0 instead
         */
        return bandwidthStateList[destinations[destinationId]].bandwidth;
    }

    /// @inheritdoc IUlyssesPool
    function getBandwidthStateList() external view returns (BandwidthState[] memory) {
        return bandwidthStateList;
    }

    /// @inheritdoc IUlyssesPool
    function getProtocolFees() public view returns (uint256) {
        uint256 balance = asset.balanceOf(address(this));
        uint256 assets;

        for (uint256 i = 1; i < bandwidthStateList.length; i++) {
            uint256 targetBandwidth = totalSupply.mulDiv(bandwidthStateList[i].weight, totalWeights);

            assets += _calculateRebalancingFee(bandwidthStateList[i].bandwidth, targetBandwidth, false);

            assets += bandwidthStateList[i].bandwidth;
        }

        if (balance > assets) {
            return balance - assets;
        } else {
            return 0;
        }
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IUlyssesPool
    function claimProtocolFees() external nonReentrant returns (uint256 claimed) {
        claimed = getProtocolFees();

        if (claimed > 0) {
            asset.safeTransfer(factory.owner(), claimed);
        }
    }

    /// @inheritdoc IUlyssesPool
    function addNewBandwidth(uint256 poolId, uint8 weight) external nonReentrant onlyOwner returns (uint256 index) {
        if (weight == 0) revert InvalidWeight();

        UlyssesPool destination = factory.pools(poolId);
        uint256 destinationId = destination.id();

        if (destinationIds[address(destination)] != 0 || destinationId == id) revert InvalidPool();

        if (destinationId == 0) revert NotUlyssesLP();

        index = bandwidthStateList.length;

        if (index > MAX_DESTINATIONS) revert TooManyDestinations();

        uint256 oldRebalancingFee;

        for (uint256 i = 1; i < index; i++) {
            uint256 targetBandwidth = totalSupply.mulDiv(bandwidthStateList[i].weight, totalWeights);

            oldRebalancingFee += _calculateRebalancingFee(bandwidthStateList[i].bandwidth, targetBandwidth, false);
        }

        uint256 oldTotalWeights = totalWeights;
        uint256 newTotalWeights = oldTotalWeights + weight;
        totalWeights = newTotalWeights;

        if (newTotalWeights > MAX_TOTAL_WEIGHT) revert InvalidWeight();

        uint256 newBandwidth;

        for (uint256 i = 1; i < index;) {
            uint256 oldBandwidth = bandwidthStateList[i].bandwidth;
            if (oldBandwidth > 0) {
                bandwidthStateList[i].bandwidth = oldBandwidth.mulDivUp(oldTotalWeights, newTotalWeights).toUint248();

                newBandwidth += oldBandwidth - bandwidthStateList[i].bandwidth;
            }

            unchecked {
                ++i;
            }
        }

        bandwidthStateList.push(
            BandwidthState({bandwidth: newBandwidth.toUint248(), destination: destination, weight: weight})
        );

        destinations[destinationId] = index;
        destinationIds[address(destination)] = index;

        uint256 newRebalancingFee;

        for (uint256 i = 1; i <= index; i++) {
            uint256 targetBandwidth = totalSupply.mulDiv(bandwidthStateList[i].weight, totalWeights);

            newRebalancingFee += _calculateRebalancingFee(bandwidthStateList[i].bandwidth, targetBandwidth, false);
        }

        if (oldRebalancingFee < newRebalancingFee) {
            asset.safeTransferFrom(msg.sender, address(this), newRebalancingFee - oldRebalancingFee);
        }
    }

    /// @inheritdoc IUlyssesPool
    function setWeight(uint256 poolId, uint8 weight) external nonReentrant onlyOwner {
        if (weight == 0) revert InvalidWeight();

        uint256 poolIndex = destinations[poolId];

        if (poolIndex == 0) revert NotUlyssesLP();

        uint256 oldRebalancingFee;

        for (uint256 i = 1; i < bandwidthStateList.length; i++) {
            uint256 targetBandwidth = totalSupply.mulDiv(bandwidthStateList[i].weight, totalWeights);

            oldRebalancingFee += _calculateRebalancingFee(bandwidthStateList[i].bandwidth, targetBandwidth, false);
        }

        uint256 oldTotalWeights = totalWeights;
        uint256 weightsWithoutPool = oldTotalWeights - bandwidthStateList[poolIndex].weight;
        uint256 newTotalWeights = weightsWithoutPool + weight;
        totalWeights = newTotalWeights;

        if (totalWeights > MAX_TOTAL_WEIGHT || oldTotalWeights == newTotalWeights) {
            revert InvalidWeight();
        }

        uint256 leftOverBandwidth;

        BandwidthState storage poolState = bandwidthStateList[poolIndex];
        poolState.weight = weight;

        if (oldTotalWeights > newTotalWeights) {
            for (uint256 i = 1; i < bandwidthStateList.length;) {
                if (i != poolIndex) {
                    uint256 oldBandwidth = bandwidthStateList[i].bandwidth;
                    if (oldBandwidth > 0) {
                        bandwidthStateList[i].bandwidth =
                            oldBandwidth.mulDivUp(oldTotalWeights, newTotalWeights).toUint248();

                        leftOverBandwidth += oldBandwidth - bandwidthStateList[i].bandwidth;
                    }
                }

                unchecked {
                    ++i;
                }
            }

            poolState.bandwidth += leftOverBandwidth.toUint248();
        } else {
            uint256 oldBandwidth = poolState.bandwidth;
            if (oldBandwidth > 0) {
                poolState.bandwidth = oldBandwidth.mulDivUp(oldTotalWeights, newTotalWeights).toUint248();

                leftOverBandwidth += oldBandwidth - poolState.bandwidth;
            }

            for (uint256 i = 1; i < bandwidthStateList.length;) {
                if (i != poolIndex) {
                    if (i == bandwidthStateList.length - 1) {
                        bandwidthStateList[i].bandwidth += leftOverBandwidth.toUint248();
                    } else if (leftOverBandwidth > 0) {
                        bandwidthStateList[i].bandwidth +=
                            leftOverBandwidth.mulDiv(bandwidthStateList[i].weight, weightsWithoutPool).toUint248();
                    }
                }

                unchecked {
                    ++i;
                }
            }
        }

        uint256 newRebalancingFee;

        for (uint256 i = 1; i < bandwidthStateList.length; i++) {
            uint256 targetBandwidth = totalSupply.mulDiv(bandwidthStateList[i].weight, totalWeights);

            newRebalancingFee += _calculateRebalancingFee(bandwidthStateList[i].bandwidth, targetBandwidth, false);
        }

        if (oldRebalancingFee < newRebalancingFee) {
            asset.safeTransferFrom(msg.sender, address(this), newRebalancingFee - oldRebalancingFee);
        }
    }

    /// @inheritdoc IUlyssesPool
    function setFees(Fees calldata _fees) external nonReentrant onlyOwner {
        // Lower fee must be lower than 1%
        if (_fees.lambda1 > MAX_LAMBDA1) revert InvalidFee();
        // Sum of both fees must be 50%
        if (_fees.lambda1 + _fees.lambda2 != DIVISIONER / 2) revert InvalidFee();

        // Upper bound must be lower than 100%
        if (_fees.sigma1 > DIVISIONER) revert InvalidFee();
        // Lower bound must be lower than Upper bound and higher than 1%
        if (_fees.sigma1 <= _fees.sigma2 || _fees.sigma2 < MIN_SIGMA2) revert InvalidFee();

        fees = _fees;
    }

    /// @inheritdoc IUlyssesPool
    function setProtocolFee(uint256 _protocolFee) external nonReentrant {
        if (msg.sender != factory.owner()) revert Unauthorized();

        // Revert if the protocol fee is larger than 1%
        if (_protocolFee > MAX_PROTOCOL_FEE) revert InvalidFee();

        protocolFee = _protocolFee;
    }

    /*//////////////////////////////////////////////////////////////
                            ULYSSES LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates the bandwidth increase/decrease amount.
     * Is called when a user is doing a swap or adding/removing liquidity.
     * @param roundUp Whether to round up or down
     * @param positiveTransfer Whether the transfer is positive or negative
     * @param amount The amount to transfer
     * @param _totalWeights The total weights
     * @param _totalSupply The total supply
     */
    function getBandwidthUpdateAmounts(
        bool roundUp,
        bool positiveTransfer,
        uint256 amount,
        uint256 _totalWeights,
        uint256 _totalSupply
    ) private view returns (uint256[] memory bandwidthUpdateAmounts, uint256 length) {
        // Get the bandwidth state list length
        length = bandwidthStateList.length;

        /// @solidity memory-safe-assembly
        assembly {
            // Revert if the list is empty
            if eq(length, 1) {
                // Store the function selector of `NotInitialized()`.
                mstore(0x00, 0x87138d5c)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }

            // Revert if the amount is too small
            if lt(amount, MIN_SWAP_AMOUNT) {
                // Store the function selector of `AmountTooSmall()`.
                mstore(0x00, 0xc2f5625a)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }
        }

        // Initialize bandwidth update amounts
        bandwidthUpdateAmounts = new uint256[](length);
        // Initialize bandwidth differences from target bandwidth
        uint256[] memory diffs = new uint256[](length);

        /// @solidity memory-safe-assembly
        assembly {
            // Store bandwidth state slot in memory
            mstore(0x00, bandwidthStateList.slot)
            // Hash the bandwidth state slot to get the bandwidth state list start
            let bandwidthStateListStart := keccak256(0x00, 0x20)

            // Total difference from target bandwidth of all bandwidth states
            let totalDiff
            // Total difference from target bandwidth of all bandwidth states
            let transfered
            // Total amount to be distributed according to each bandwidth weights
            let transferedChange

            for { let i := 1 } lt(i, length) { i := add(i, 1) } {
                // Load bandwidth and weight from storage
                // Each bandwidth state occupies two storage slots
                let slot := sload(add(bandwidthStateListStart, mul(i, 2)))
                // Bandwidth is the first 248 bits of the slot
                let bandwidth := and(slot, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
                // Weight is the last 8 bits of the slot
                let weight := shr(248, slot)

                // Equivalent to `require(y == 0 || x <= type(uint256).max / y)`.
                if mul(weight, gt(_totalSupply, div(not(0), weight))) {
                    // Store the function selector of `MulDivFailed()`.
                    mstore(0x00, 0xad251c27)
                    // Revert with (offset, size).
                    revert(0x1c, 0x04)
                }

                // Calculate the target bandwidth
                let targetBandwidth := div(mul(_totalSupply, weight), _totalWeights)

                // Calculate the difference from the target bandwidth
                switch positiveTransfer
                // If the transfer is positive, calculate deficit from target bandwidth
                case true {
                    // If there is a deficit, store the difference
                    if gt(targetBandwidth, bandwidth) {
                        // Calculate the difference
                        let diff := sub(targetBandwidth, bandwidth)
                        // Add the difference to the total difference
                        totalDiff := add(totalDiff, diff)
                        // Store the difference in the diffs array
                        mstore(add(diffs, add(mul(i, 0x20), 0x20)), diff)
                    }
                }
                // If the transfer is negative, calculate surplus from target bandwidth
                default {
                    // If there is a surplus, store the difference
                    if gt(bandwidth, targetBandwidth) {
                        // Calculate the difference
                        let diff := sub(bandwidth, targetBandwidth)
                        // Add the difference to the total difference
                        totalDiff := add(totalDiff, diff)
                        // Store the difference in the diffs array
                        mstore(add(diffs, add(mul(i, 0x20), 0x20)), diff)
                    }
                }
            }

            // Calculate the amount to be distributed according deficit/surplus
            // and/or the amount to be distributed according to each bandwidth weights
            switch gt(amount, totalDiff)
            // If the amount is greater than the total deficit/surplus
            case true {
                // Total deficit/surplus is distributed
                transfered := totalDiff
                // Set rest to be distributed according to each bandwidth weights
                transferedChange := sub(amount, totalDiff)
            }
            // If the amount is less than the total deficit/surplus
            default {
                // Amount will be distributed according to deficit/surplus
                transfered := amount
            }

            for { let i := 1 } lt(i, length) { i := add(i, 1) } {
                // Increase/decrease amount of bandwidth for each bandwidth state
                let bandwidthUpdate

                // If there is a deficit/surplus, calculate the amount to be distributed
                if gt(transfered, 0) {
                    // Load the difference from the diffs array
                    let diff := mload(add(diffs, add(mul(i, 0x20), 0x20)))

                    // Equivalent to `require(y == 0 || x <= type(uint256).max / y)`.
                    if mul(diff, gt(transfered, div(not(0), diff))) {
                        // Store the function selector of `MulDivFailed()`.
                        mstore(0x00, 0xad251c27)
                        // Revert with (offset, size).
                        revert(0x1c, 0x04)
                    }

                    // Calculate the amount to be distributed according to deficit/surplus
                    switch roundUp
                    // If round up then do mulDivUp(transfered, diff, totalDiff)
                    case true {
                        bandwidthUpdate :=
                            add(
                                iszero(iszero(mod(mul(transfered, diff), totalDiff))), div(mul(transfered, diff), totalDiff)
                            )
                    }
                    // If round down then do mulDiv(transfered, diff, totalDiff)
                    default { bandwidthUpdate := div(mul(transfered, diff), totalDiff) }
                }

                // If there is a rest, calculate the amount to be distributed according to each bandwidth weights
                if gt(transferedChange, 0) {
                    // Load weight from storage
                    let weight := shr(248, sload(add(bandwidthStateListStart, mul(i, 2))))

                    // Equivalent to `require(y == 0 || x <= type(uint256).max / y)`.
                    if mul(weight, gt(transferedChange, div(not(0), weight))) {
                        // Store the function selector of `MulDivFailed()`.
                        mstore(0x00, 0xad251c27)
                        // Revert with (offset, size).
                        revert(0x1c, 0x04)
                    }

                    // Calculate the amount to be distributed according to each bandwidth weights
                    switch roundUp
                    // If round up then do mulDivUp(transferedChange, weight, _totalWeights)
                    case true {
                        bandwidthUpdate :=
                            add(
                                bandwidthUpdate,
                                add(
                                    iszero(iszero(mod(mul(transferedChange, weight), _totalWeights))),
                                    div(mul(transferedChange, weight), _totalWeights)
                                )
                            )
                    }
                    // If round down then do mulDiv(transferedChange, weight, _totalWeights)
                    default {
                        bandwidthUpdate := add(bandwidthUpdate, div(mul(transferedChange, weight), _totalWeights))
                    }
                }

                // If there is an update in bandwidth
                if gt(bandwidthUpdate, 0) {
                    // Store the amount to be updated in the bandwidthUpdateAmounts array
                    mstore(add(bandwidthUpdateAmounts, add(mul(i, 0x20), 0x20)), bandwidthUpdate)
                }
            }
        }
    }

    /**
     * @notice Updates the bandwidth of the destination Ulysses LP
     * @param depositFees Whether to deposit fees or not
     * @param positiveTransfer Whether the transfer is positive or negative
     * @param destinationState The state of the destination Ulysses LP
     * @param difference The difference between the old and new total supply
     * @param _totalWeights The total weights of all Ulysses LPs
     * @param _totalSupply The total supply of the Ulysses LP
     * @param _newTotalSupply  The new total supply of the Ulysses LP
     * @return positivefee The positive fee
     */
    function updateBandwidth(
        bool depositFees,
        bool positiveTransfer,
        BandwidthState storage destinationState,
        uint256 difference,
        uint256 _totalWeights,
        uint256 _totalSupply,
        uint256 _newTotalSupply
    ) private returns (uint256 positivefee, uint256 negativeFee) {
        uint256 bandwidth;
        uint256 targetBandwidth;
        uint256 weight;

        /// @solidity memory-safe-assembly
        assembly {
            // Load bandwidth and weight from storage
            let slot := sload(destinationState.slot)
            // Bandwidth is the first 248 bits of the slot
            bandwidth := and(slot, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
            // Weight is the last 8 bits of the slot
            weight := shr(248, slot)

            // Equivalent to `require(y == 0 || x <= type(uint256).max / y)`.
            if mul(weight, gt(_totalSupply, div(not(0), weight))) {
                // Store the function selector of `MulDivFailed()`.
                mstore(0x00, 0xad251c27)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }

            // Get the target bandwidth
            targetBandwidth := div(mul(_totalSupply, weight), _totalWeights)
        }

        // get the rebalancing fee prior to updating the bandwidth
        uint256 oldRebalancingFee = _calculateRebalancingFee(
            bandwidth,
            targetBandwidth,
            positiveTransfer // Rounds down if positive, up if negative
        );

        /// @solidity memory-safe-assembly
        assembly {
            switch positiveTransfer
            // If the transfer is positive
            case true {
                // Add the difference to the bandwidth
                bandwidth := add(bandwidth, difference)

                // Revert if bandwidth overflows
                if lt(bandwidth, difference) {
                    // Store the function selector of `Overflow()`.
                    mstore(0x00, 0x35278d12)
                    // Revert with (offset, size).
                    revert(0x1c, 0x04)
                }
            }
            // If the transfer is negative
            default {
                // Revert if bandwidth underflows
                if gt(difference, bandwidth) {
                    // Store the function selector of `Underflow()`.
                    mstore(0x00, 0xcaccb6d9)
                    // Revert with (offset, size).
                    revert(0x1c, 0x04)
                }

                // Subtract the difference from the bandwidth
                bandwidth := sub(bandwidth, difference)
            }

            // True on deposit, mint and redeem
            if gt(_newTotalSupply, 0) {
                // Equivalent to `require(y == 0 || x <= type(uint256).max / y)`.
                if mul(weight, gt(_newTotalSupply, div(not(0), weight))) {
                    // Store the function selector of `MulDivFailed()`.
                    mstore(0x00, 0xad251c27)
                    // Revert with (offset, size).
                    revert(0x1c, 0x04)
                }

                // Get the new target bandwidth after total supply change
                targetBandwidth := div(mul(_newTotalSupply, weight), _totalWeights)
            }
        }

        // get the rebalancing fee after updating the bandwidth
        uint256 newRebalancingFee = _calculateRebalancingFee(
            bandwidth,
            targetBandwidth,
            positiveTransfer // Rounds down if positive, up if negative
        );

        /// @solidity memory-safe-assembly
        assembly {
            switch lt(newRebalancingFee, oldRebalancingFee)
            // If new fee is lower than old fee
            case true {
                // Calculate the positive fee
                positivefee := sub(oldRebalancingFee, newRebalancingFee)

                // If depositFees is true, add the positive fee to the bandwidth
                if depositFees {
                    bandwidth := add(bandwidth, positivefee)

                    // Revert if bandwidth overflows
                    if lt(bandwidth, positivefee) {
                        // Store the function selector of `Overflow()`.
                        mstore(0x00, 0x35278d12)
                        // Revert with (offset, size).
                        revert(0x1c, 0x04)
                    }
                }
            }
            default {
                // If new fee is higher than old fee
                if gt(newRebalancingFee, oldRebalancingFee) {
                    // Calculate the negative fee
                    negativeFee := sub(newRebalancingFee, oldRebalancingFee)
                }
            }

            if gt(bandwidth, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) {
                // Store the function selector of `Overflow()`.
                mstore(0x00, 0x35278d12)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }

            // Update storage with the new bandwidth
            sstore(destinationState.slot, or(bandwidth, shl(248, weight)))
        }
    }

    /**
     * @notice Calculates the positive or negative rebalancing fee for a bandwidth change
     * @param bandwidth The new bandwidth, after decreasing or increasing the current bandwidth
     * @param targetBandwidth The ideal bandwidth according to weight and totalSupply
     * @param roundDown Whether to round down or up
     * @return fee The rebalancing fee for this action
     */
    function _calculateRebalancingFee(uint256 bandwidth, uint256 targetBandwidth, bool roundDown)
        internal
        view
        returns (uint256 fee)
    {
        // If the bandwidth is larger or equal to the target bandwidth, return 0
        if (bandwidth >= targetBandwidth) return 0;

        // Upper bound of the first fee interval
        uint256 upperBound1;
        // Upper bound of the second fee interval
        uint256 upperBound2;
        // Fee tier 1 (fee % divided by 2)
        uint256 lambda1;
        // Fee tier 2 (fee % divided by 2)
        uint256 lambda2;

        // @solidity memory-safe-assembly
        assembly {
            // Load the rebalancing fee slot to get the fee parameters
            let feeSlot := sload(fees.slot)
            // Get sigma2 from the first 8 bytes of the fee slot
            let sigma2 := shr(192, feeSlot)
            // Get sigma1 from the next 8 bytes of the fee slot
            let sigma1 := and(shr(128, feeSlot), 0xffffffffffffffff)
            // Get lambda2 from the next 8 bytes of the fee slot
            lambda2 := and(shr(64, feeSlot), 0xffffffffffffffff)
            // Get lambda1 from the last 8 bytes of the fee slot
            lambda1 := and(feeSlot, 0xffffffffffffffff)

            // Equivalent to require(denominator != 0 && (y == 0 || x <= type(uint256).max / y))
            if mul(sigma1, gt(targetBandwidth, div(not(0), sigma1))) {
                // Store the function selector of `MulDivFailed()`.
                mstore(0x00, 0xad251c27)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }

            // Calculate the upper bound for the first fee
            upperBound1 := div(mul(targetBandwidth, sigma1), DIVISIONER)

            // Equivalent to require(denominator != 0 && (y == 0 || x <= type(uint256).max / y))
            if mul(sigma2, gt(targetBandwidth, div(not(0), sigma2))) {
                // Store the function selector of `MulDivFailed()`.
                mstore(0x00, 0xad251c27)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }

            // Calculate the upper bound for the second fee
            upperBound2 := div(mul(targetBandwidth, sigma2), DIVISIONER)
        }

        if (bandwidth >= upperBound1) return 0;

        uint256 maxWidth;
        /// @solidity memory-safe-assembly
        assembly {
            // Calculate the maximum width of the trapezium
            maxWidth := sub(upperBound1, upperBound2)
        }

        // If the bandwidth is smaller than upperBound2
        if (bandwidth >= upperBound2) {
            // Calculate the fee for the first interval
            fee = calcFee(lambda1, maxWidth, upperBound1, bandwidth, 0, roundDown);
        } else {
            // Calculate the fee for the first interval
            fee = calcFee(lambda1, maxWidth, upperBound1, upperBound2, 0, roundDown);

            /// @solidity memory-safe-assembly
            assembly {
                // offset = lambda1 * 2
                lambda1 := shl(1, lambda1)
            }

            // Calculate the fee for the second interval
            uint256 fee2 = calcFee(lambda2, upperBound2, upperBound2, bandwidth, lambda1, roundDown);

            /// @solidity memory-safe-assembly
            assembly {
                // Add the two fees together
                fee := add(fee, fee2)
            }
        }
    }

    /**
     *  @notice Calculates outstanding rebalancing fees for a specific bandwidth
     *  @dev The fee is calculated as a trapezium with a base of width and a height of height
     *       The formula for the area of a trapezium is (a + b) * h / 2
     *                          ___________
     *          fee1 + fee2 -->|          /|
     *                         |         / |
     *                         |________/  |
     *  fee1 + fee2 * amount-->|       /|  |
     *         -------------   |      / |  |
     *           max width     |     /  |  |
     *                         |____/   |  |
     *                 fee1 -->|   |    |  |
     *                         |   |    |  |
     *                         |___|____|__|_____
     *                             |    |  |
     *                    upper bound 2 |  0
     *                                  |
     *                              bandwidth
     *
     *         max width = upper bound 2
     *         amount = upper bound 2 - bandwidth
     *
     *           h = amount
     *           a = fee1 + (fee2 * amount / max width)
     *           b = fee1
     *
     *           fee = (a + b) * h / 2
     *               = (fee1 + fee1 + (fee2 * amount / max width)) * amount / 2
     *               = ((fee1 * 2) + (fee2 * amount / max width)) * amount / 2
     *
     *         Because lambda1 = fee1 / 2 and lambda2 = fee2 / 2
     *
     *         fee = ((fee1 * 2) + (fee2 * amount / max width)) * amount / 2
     *             = (lambda1 * 2 * amount) + (lambda2 * amount * amount) / max width
     *             = amount * ((lambda1 * 2) + (lambda2 * amount / max width))
     *
     *
     *       When offset (b) is 0, the trapezium is equivalent to a triangle:
     *                          ___________
     *                 fee1 -->|          /|
     *                         |         / |
     *                         |________/  |
     *        fee1 * amount -->|       /|  |
     *        -------------    |      / |  |
     *          max width      |     /  |  |
     *                         |    /   |  |
     *                         |___/____|__|_____
     *                             |    |  |
     *                    upper bound 1 | upper bound 2
     *                                  |
     *                              bandwidth
     *
     *         max width = upper bound 1 - upper bound 2
     *         amount = upper bound 1 - bandwidth
     *
     *           h = amount
     *           a = fee1 * amount / max width
     *           b = 0
     *
     *           fee = (a + b) * h / 2
     *               = fee1 * amount * amount / (2 * max width)
     *
     *         Because lambda1 = fee1 / 2
     *
     *         fee = fee1 * amount * amount / (2 * max width)
     *             = lambda2 * amount * amount / max width
     *
     *  @param feeTier The fee tier of the bandwidth
     *  @param maxWidth The maximum width of the bandwidth
     *  @param upperBound The upper bound of the bandwidth
     *  @param bandwidth The bandwidth of the bandwidth
     *  @param offset The offset of the bandwidth
     *  @param roundDown Whether to round down or up
     */
    function calcFee(
        uint256 feeTier,
        uint256 maxWidth,
        uint256 upperBound,
        uint256 bandwidth,
        uint256 offset,
        bool roundDown
    ) private pure returns (uint256 fee) {
        /// @solidity memory-safe-assembly
        assembly {
            // Calculate the height of the trapezium
            // The height is calculated as `upperBound - bandwidth`
            let height := sub(upperBound, bandwidth)

            // Equivalent to `require(y == 0 || x <= type(uint256).max / y)`.
            if mul(feeTier, gt(height, div(not(0), feeTier))) {
                // Store the function selector of `MulDivFailed()`.
                mstore(0x00, 0xad251c27)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }

            // Calculate the width of the trapezium, rounded up
            // The width is calculated as `feeTier * height / maxWidth + offset`
            let width :=
                add(add(iszero(iszero(mod(mul(height, feeTier), maxWidth))), div(mul(height, feeTier), maxWidth)), offset)

            // Equivalent to require(denominator != 0 && (y == 0 || x <= type(uint256).max / y))
            if mul(height, gt(width, div(not(0), height))) {
                // Store the function selector of `MulDivFailed()`.
                mstore(0x00, 0xad251c27)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }

            // Calculate the fee for this tier
            switch roundDown
            // If round down then do mulDiv(transfered, diff, totalDiff)
            case true { fee := div(mul(width, height), DIVISIONER) }
            // If round up then do mulDivUp(transfered, diff, totalDiff)
            default {
                fee := add(iszero(iszero(mod(mul(width, height), DIVISIONER))), div(mul(width, height), DIVISIONER))
            }
        }
    }

    /**
     * @notice Adds assets to bandwidths and returns the assets to be swapped to a destination pool
     * @param assets The assets to be distributed between all bandwidths
     * @return output The assets of assets to be swapped to a destination pool
     */
    function ulyssesSwap(uint256 assets) private returns (uint256 output) {
        uint256 _totalWeights = totalWeights;
        uint256 _totalSupply = totalSupply;

        // Get the bandwidth update amounts and chainStateList length
        (uint256[] memory bandwidthUpdateAmounts, uint256 length) = getBandwidthUpdateAmounts(
            false, // round down bandwidths
            true, // is positive transfer
            assets,
            _totalWeights,
            _totalSupply
        );

        for (uint256 i = 1; i < length;) {
            // Get the update amount for this bandwidth
            uint256 updateAmount = bandwidthUpdateAmounts[i];

            // if updateAmount > 0
            if (updateAmount > 0) {
                /// @solidity memory-safe-assembly
                assembly {
                    // Add updateAmount to output
                    output := add(output, updateAmount)
                }

                // Update bandwidth with the update amount and get the positive fee
                // Negative fee is always 0 because totalSupply does not increase
                (uint256 positiveFee,) =
                    updateBandwidth(true, true, bandwidthStateList[i], updateAmount, _totalWeights, _totalSupply, 0);

                /// @solidity memory-safe-assembly
                assembly {
                    // if positiveFee > 0 then add positiveFee to output
                    if gt(positiveFee, 0) { output := add(output, positiveFee) }
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Adds amount to bandwidths and returns assets to deposit or shares to mint
     * @param amount The amount to be distributed between all bandwidths
     * @param depositFees True when called from deposit, false when called from mint
     * @return output The output amount to be minted or deposited
     */
    function ulyssesAddLP(uint256 amount, bool depositFees) private returns (uint256 output) {
        uint256 _totalWeights = totalWeights;
        uint256 _totalSupply = totalSupply;
        uint256 _newTotalSupply;

        /// @solidity memory-safe-assembly
        assembly {
            // Get the new total supply by adding amount to totalSupply
            _newTotalSupply := add(_totalSupply, amount)
        }

        // Get the bandwidth update amounts and chainStateList length
        // newTotalSupply is used to avoid negative rebalancing fees
        // Rounds up when depositFees is false
        (uint256[] memory bandwidthUpdateAmounts, uint256 length) =
            getBandwidthUpdateAmounts(!depositFees, true, amount, _totalWeights, _newTotalSupply);

        // Discount in assets in `mint` or negative fee in `deposit`
        uint256 negativeFee;
        for (uint256 i = 1; i < length;) {
            // Get the update amount for this bandwidth
            uint256 updateAmount = bandwidthUpdateAmounts[i];

            /// @solidity memory-safe-assembly
            assembly {
                // if updateAmount > 0 then add updateAmount to output
                if gt(updateAmount, 0) { output := add(output, updateAmount) }
            }

            // Update bandwidth with the update amount and get the positive fee and negative fee
            (uint256 _positiveFee, uint256 _negativeFee) = updateBandwidth(
                depositFees, true, bandwidthStateList[i], updateAmount, _totalWeights, _totalSupply, _newTotalSupply
            );

            /// @solidity memory-safe-assembly
            assembly {
                switch depositFees
                // if depositFees is true, `deposit` was called
                case true {
                    switch gt(_positiveFee, 0)
                    // if _positiveFee > 0 then add _positiveFee to output
                    // Adding shares to mint
                    case true { output := add(output, _positiveFee) }
                    // if _positiveFee <= 0 then add _negativeFee to negativeFee
                    // Subtracting shares to mint
                    default { negativeFee := add(negativeFee, _negativeFee) }
                }
                // if depositFees is false, `mint` was called
                default {
                    switch gt(_positiveFee, 0)
                    // if _positiveFee > 0 then add _positiveFee to output
                    // Subtracting assets to deposit
                    case true { negativeFee := add(negativeFee, _positiveFee) }
                    // if _positiveFee <= 0 then add _negativeFee to output
                    // Adding assets to deposit
                    default { output := add(output, _negativeFee) }
                }
            }

            unchecked {
                ++i;
            }
        }

        /// @solidity memory-safe-assembly
        assembly {
            // Revert if output underflows
            if gt(negativeFee, output) {
                // Store the function selector of `Underflow()`.
                mstore(0x00, 0xcaccb6d9)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }

            // Subtracting assets to deposit or shares to mint
            output := sub(output, negativeFee)
        }
    }

    /**
     * @notice Removes shares from bandwidths and returns assets to withdraw
     * @param shares The shares to be removed between all bandwidths
     * @return assets The shares of assets to withdraw
     */
    function ulyssesRemoveLP(uint256 shares) private returns (uint256 assets) {
        uint256 _totalWeights = totalWeights;
        uint256 _totalSupply;
        uint256 _newTotalSupply = totalSupply;

        /// @solidity memory-safe-assembly
        assembly {
            // Get the old total supply by adding burned shares to totalSupply
            _totalSupply := add(_newTotalSupply, shares)
        }

        // Get the bandwidth update amounts and chainStateList length
        (uint256[] memory bandwidthUpdateAmounts, uint256 length) =
            getBandwidthUpdateAmounts(false, false, shares, _totalWeights, _totalSupply);

        // Assets paid as negative rebalancing fees
        uint256 negativeFee;
        for (uint256 i = 1; i < length;) {
            // Get the update amount for this bandwidth
            uint256 updateAmount = bandwidthUpdateAmounts[i];

            // If updateAmount > 0, update bandwidth and add assets to withdraw
            if (updateAmount > 0) {
                /// @solidity memory-safe-assembly
                assembly {
                    // Add updateAmount to assets
                    assets := add(assets, updateAmount)
                }

                // Update bandwidth with the update amount and get the negative fee
                // If any, positive fees are accumulated by the protocol
                (, uint256 _negativeFee) = updateBandwidth(
                    false, false, bandwidthStateList[i], updateAmount, _totalWeights, _totalSupply, _newTotalSupply
                );

                /// @solidity memory-safe-assembly
                assembly {
                    // Update negativeFee
                    negativeFee := add(negativeFee, _negativeFee)
                }
            }

            unchecked {
                ++i;
            }
        }

        /// @solidity memory-safe-assembly
        assembly {
            // Revert if assets underflows
            if gt(negativeFee, assets) {
                // Store the function selector of `Underflow()`.
                mstore(0x00, 0xcaccb6d9)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }

            // Subtracting assets to withdraw
            assets := sub(assets, negativeFee)
        }
    }

    /*//////////////////////////////////////////////////////////////
                            SWAP LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IUlyssesPool
    function swapIn(uint256 assets, uint256 poolId) external nonReentrant returns (uint256 output) {
        // Get bandwidth state index from poolId
        uint256 index = destinations[poolId]; // Saves an extra SLOAD if poolId is valid

        /// @solidity memory-safe-assembly
        assembly {
            // Revert if poolId is invalid
            if iszero(index) {
                // Store the function selector of `NotUlyssesLP()`.
                mstore(0x00, 0x3c930918)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }
        }

        // Transfer assets from msg.sender to this contract
        asset.safeTransferFrom(msg.sender, address(this), assets);

        /// @solidity memory-safe-assembly
        assembly {
            // Get the protocol fee from storage
            let _protocolFee := sload(protocolFee.slot)

            // Equivalent to require(denominator != 0 && (y == 0 || x <= type(uint256).max / y))
            if mul(_protocolFee, gt(assets, div(not(0), _protocolFee))) {
                // Store the function selector of `MulDivFailed()`.
                mstore(0x00, 0xad251c27)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }

            // Calculate the base fee, rounding up
            let baseFee :=
                add(iszero(iszero(mod(mul(assets, _protocolFee), DIVISIONER))), div(mul(assets, _protocolFee), DIVISIONER))

            // Revert if assets underflows
            if gt(baseFee, assets) {
                // Store the function selector of `Underflow()`.
                mstore(0x00, 0xcaccb6d9)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }

            // Subtract the base fee from assets
            output := sub(assets, baseFee)
        }

        emit Swap(msg.sender, poolId, assets);

        // Update bandwidths, swap assets to destination, and return output
        output = bandwidthStateList[index].destination.swapFromPool(ulyssesSwap(output), msg.sender);
    }

    /// @inheritdoc IUlyssesPool
    function swapFromPool(uint256 assets, address user) external nonReentrant returns (uint256 output) {
        // Get bandwidth state index from msg.sender
        uint256 index = destinationIds[msg.sender]; // Saves an extra SLOAD if msg.sender is valid

        /// @solidity memory-safe-assembly
        assembly {
            // Revert if msg.sender is invalid
            if iszero(index) {
                // Store the function selector of `NotUlyssesLP()`.
                mstore(0x00, 0x3c930918)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }
            // Revert if the amount is zero
            if iszero(assets) {
                // Store the function selector of `AmountTooSmall()`.
                mstore(0x00, 0xc2f5625a)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }
        }

        // Update bandwidths and get the negative fee
        // Positive fee is always 0 because totalSupply does not decrease
        (, uint256 negativeFee) =
            updateBandwidth(false, false, bandwidthStateList[index], assets, totalWeights, totalSupply, 0);

        /// @solidity memory-safe-assembly
        assembly {
            // Revert if output underflows
            if gt(negativeFee, assets) {
                // Store the function selector of `Underflow()`.
                mstore(0x00, 0xcaccb6d9)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }

            // Subtract the negative fee from assets
            output := sub(assets, negativeFee)
        }

        // Transfer output to user
        asset.safeTransfer(user, output);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL HOOKS LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Performs the necessary steps to make after depositing.
     * @param assets to be deposited
     */
    function beforeDeposit(uint256 assets) internal override returns (uint256 shares) {
        // Update deposit/mint
        shares = ulyssesAddLP(assets, true);
    }

    /**
     * @notice Performs the necessary steps to make after depositing.
     * @param assets to be deposited
     */
    function beforeMint(uint256 shares) internal override returns (uint256 assets) {
        // Update deposit/mint
        assets = ulyssesAddLP(shares, false);
    }

    /**
     * @notice Performs the necessary steps to take before withdrawing assets
     * @param shares to be burned
     */
    function afterRedeem(uint256 shares) internal override returns (uint256 assets) {
        // Update withdraw/redeem
        assets = ulyssesRemoveLP(shares);
    }
}
