// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "@rewards/base/BaseFlywheelRewards.sol";

contract MockRewardsInstant is BaseFlywheelRewards {
    /// @notice rewards amount per strategy
    mapping(ERC20 => uint256) public rewardsAmount;

    uint256 public rewards;

    constructor(FlywheelCore _flywheel) BaseFlywheelRewards(_flywheel) {}

    function setRewards(uint256 amount) external {
        rewards = amount;
    }

    function getAccruedRewards() external view onlyFlywheel returns (uint256 amount) {
        return rewards;
    }
}
