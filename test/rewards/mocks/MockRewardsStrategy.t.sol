// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "@rewards/base/BaseFlywheelRewards.sol";

contract MockRewardsStrategy is BaseFlywheelRewards {
    /// @notice rewards amount per strategy
    mapping(ERC20 => uint256) public rewardsAmount;

    uint256 public rewards;

    constructor(FlywheelCore _flywheel) BaseFlywheelRewards(_flywheel) {}

    function setRewardsAmount(ERC20 _strategy, uint256 amount) external {
        rewardsAmount[_strategy] = amount;
    }

    function getAccruedRewards(ERC20 _strategy) external view onlyFlywheel returns (uint256 amount) {
        return rewardsAmount[_strategy];
    }
}
