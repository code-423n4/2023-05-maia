# FlywheelBribeRewards

- [constructor](#function-constructor)
- [setRewardsDepot](#function-setrewardsdepot)


This contract is inherited from the `FlywheelAcummulatedRewards` contract.

## Function: `constructor`

This contract is created inside the `BribesFactory:createBribeFlywheel()` function. First, the `FlywheelCore` contract is created, and after that, this address is passed to the `FlywheelBribeRewards` constructor.

## Function: `setRewardsDepot`

Allows any strategy to set the `RewardsDepot` address. However, despite this, the `RewardsDepot` contract will be called only for the trusted strategy address. The `getRewards` function from the `RewardsDepot` contract will be called inside the `getNextCycleRewards` function.

```solidity
    function getNextCycleRewards(ERC20 strategy) internal override returns (uint256) {
        return rewardsDepots[strategy].getRewards();
    }

    function setRewardsDepot(RewardsDepot rewardsDepot) external {
        /// @dev Anyone can call this, whitelisting is handled in FlywheelCore
        rewardsDepots[ERC20(msg.sender)] = rewardsDepot;
        emit AddRewardsDepot(msg.sender, rewardsDepot);
    }
```

There are two implementations of the `getRewards` function. The first one is inside the `MultiRewardsDepot` contract, and the second one is inside the `SingleRewardsDepot` contract. In the case of the `MultiRewardsDepot`, this function will transfer the reward value to the caller (strategy), and in the case of the `SingleRewardsDepot`, it will transfer the reward value to the `rewardsContract` address.

