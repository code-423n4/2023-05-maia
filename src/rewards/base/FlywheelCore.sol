// SPDX-License-Identifier: MIT
// Rewards logic inspired by Tribe DAO Contracts (flywheel-v2/src/FlywheelCore.sol)
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {IFlywheelBooster} from "../interfaces/IFlywheelBooster.sol";
import {IFlywheelCore} from "../interfaces/IFlywheelCore.sol";

/// @title Flywheel Core Incentives Manager
abstract contract FlywheelCore is Ownable, IFlywheelCore {
    using SafeTransferLib for address;
    using SafeCastLib for uint256;

    /*///////////////////////////////////////////////////////////////
                        FLYWHEEL CORE STATE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IFlywheelCore
    address public immutable override rewardToken;

    /// @inheritdoc IFlywheelCore
    ERC20[] public override allStrategies;

    /// @inheritdoc IFlywheelCore
    mapping(ERC20 => uint256) public override strategyIds;

    /// @inheritdoc IFlywheelCore
    address public override flywheelRewards;

    /// @inheritdoc IFlywheelCore
    IFlywheelBooster public override flywheelBooster;

    /**
     * @notice Flywheel Core constructor.
     *  @param _rewardToken the reward token
     *  @param _flywheelRewards the flywheel rewards contract
     *  @param _flywheelBooster the flywheel booster contract
     *  @param _owner the owner of this contract
     */
    constructor(address _rewardToken, address _flywheelRewards, IFlywheelBooster _flywheelBooster, address _owner) {
        _initializeOwner(_owner);
        rewardToken = _rewardToken;
        flywheelRewards = _flywheelRewards;
        flywheelBooster = _flywheelBooster;
    }

    /// @inheritdoc IFlywheelCore
    function getAllStrategies() external view returns (ERC20[] memory) {
        return allStrategies;
    }

    /*///////////////////////////////////////////////////////////////
                        ACCRUE/CLAIM LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IFlywheelCore
    mapping(address => uint256) public override rewardsAccrued;

    /// @inheritdoc IFlywheelCore
    function accrue(address user) external returns (uint256) {
        return _accrue(ERC20(msg.sender), user);
    }

    /// @inheritdoc IFlywheelCore
    function accrue(ERC20 strategy, address user) external returns (uint256) {
        return _accrue(strategy, user);
    }

    function _accrue(ERC20 strategy, address user) internal returns (uint256) {
        uint256 index = strategyIndex[strategy];

        if (index == 0) return 0;

        index = accrueStrategy(strategy, index);
        return accrueUser(strategy, user, index);
    }

    /// @inheritdoc IFlywheelCore
    function accrue(ERC20 strategy, address user, address secondUser) public returns (uint256, uint256) {
        uint256 index = strategyIndex[strategy];

        if (index == 0) return (0, 0);

        index = accrueStrategy(strategy, index);
        return (accrueUser(strategy, user, index), accrueUser(strategy, secondUser, index));
    }

    /// @inheritdoc IFlywheelCore
    function claimRewards(address user) external {
        uint256 accrued = rewardsAccrued[user];

        if (accrued != 0) {
            rewardsAccrued[user] = 0;

            rewardToken.safeTransferFrom(address(flywheelRewards), user, accrued);

            emit ClaimRewards(user, accrued);
        }
    }

    /*///////////////////////////////////////////////////////////////
                          ADMIN LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IFlywheelCore
    function addStrategyForRewards(ERC20 strategy) external onlyOwner {
        _addStrategyForRewards(strategy);
    }

    function _addStrategyForRewards(ERC20 strategy) internal {
        require(strategyIndex[strategy] == 0, "strategy");
        strategyIndex[strategy] = ONE;

        strategyIds[strategy] = allStrategies.length;
        allStrategies.push(strategy);
        emit AddStrategy(address(strategy));
    }

    /// @inheritdoc IFlywheelCore
    function setFlywheelRewards(address newFlywheelRewards) external onlyOwner {
        uint256 oldRewardBalance = rewardToken.balanceOf(address(flywheelRewards));
        if (oldRewardBalance > 0) {
            rewardToken.safeTransferFrom(address(flywheelRewards), address(newFlywheelRewards), oldRewardBalance);
        }

        flywheelRewards = newFlywheelRewards;

        emit FlywheelRewardsUpdate(address(newFlywheelRewards));
    }

    /// @inheritdoc IFlywheelCore
    function setBooster(IFlywheelBooster newBooster) external onlyOwner {
        flywheelBooster = newBooster;

        emit FlywheelBoosterUpdate(address(newBooster));
    }

    /*///////////////////////////////////////////////////////////////
                    INTERNAL ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice the fixed point factor of flywheel
    uint256 private constant ONE = 1e18;

    /// @inheritdoc IFlywheelCore
    mapping(ERC20 => uint256) public strategyIndex;

    /// @inheritdoc IFlywheelCore
    mapping(ERC20 => mapping(address => uint256)) public userIndex;

    /// @notice accumulate global rewards on a strategy
    function accrueStrategy(ERC20 strategy, uint256 state) private returns (uint256 rewardsIndex) {
        // calculate accrued rewards through rewards module
        uint256 strategyRewardsAccrued = _getAccruedRewards(strategy);

        rewardsIndex = state;
        if (strategyRewardsAccrued > 0) {
            // use the booster or token supply to calculate the reward index denominator
            uint256 supplyTokens = address(flywheelBooster) != address(0)
                ? flywheelBooster.boostedTotalSupply(strategy)
                : strategy.totalSupply();

            uint224 deltaIndex;

            if (supplyTokens != 0) {
                deltaIndex = ((strategyRewardsAccrued * ONE) / supplyTokens).toUint224();
            }

            // accumulate rewards per token onto the index, multiplied by a fixed-point factor
            rewardsIndex += deltaIndex;
            strategyIndex[strategy] = rewardsIndex;
        }
    }

    /// @notice accumulate rewards on a strategy for a specific user
    function accrueUser(ERC20 strategy, address user, uint256 index) private returns (uint256) {
        // load indices
        uint256 supplierIndex = userIndex[strategy][user];

        // sync user index to global
        userIndex[strategy][user] = index;

        // if user hasn't yet accrued rewards, grant them interest from the strategy beginning if they have a balance
        // zero balances will have no effect other than syncing to global index
        if (supplierIndex == 0) {
            supplierIndex = ONE;
        }

        uint256 deltaIndex = index - supplierIndex;
        // use the booster or token balance to calculate reward balance multiplier
        uint256 supplierTokens = address(flywheelBooster) != address(0)
            ? flywheelBooster.boostedBalanceOf(strategy, user)
            : strategy.balanceOf(user);

        // accumulate rewards by multiplying user tokens by rewardsPerToken index and adding on unclaimed
        uint256 supplierDelta = (supplierTokens * deltaIndex) / ONE;
        uint256 supplierAccrued = rewardsAccrued[user] + supplierDelta;

        rewardsAccrued[user] = supplierAccrued;

        emit AccrueRewards(strategy, user, supplierDelta, index);

        return supplierAccrued;
    }

    function _getAccruedRewards(ERC20 strategy) internal virtual returns (uint256);
}
