# UniswapV3Staker

- [claimAllRewards](#function-claimallrewards)
- [claimReward](#function-claimreward)
- [withdrawToken](#function-withdrawtoken)
- [endIncentive](#function-endincentive)
- [createIncentive](#function-createincentive)
- [createIncentiveFromGauge](#function-createincentivefromgauge)
- [onERC721Received](#function-onerc721received)
- [stakeToken](#function-staketoken)
- [unstakeToken](#function-unstaketoken)
- [updateGauges](#function-updategauges)
- [updateBribeDepot](#function-updatebribedepot)
- [updatePoolMinimumWidth](#function-updatepoolminimumwidth)


## Function: `claimAllRewards`

Allows any caller to receive the full reward if it is accrued for them.

### Branches and code coverage

**Intended branches:**

- Claim full reward.
  - [ ] Test coverage

**Negative behavior:**

- `msg.sender` does not have any reward value.
  - [ ] Negative test?

### Inputs

- `msg.sender`:
  - **Control**: N/A.
  - **Authorization**: The reward value for the caller must be nonzero.
  - **Impact**: The user who was assigned a reward.
- `to`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: The receiver of the reward.

### Function call analysis

- `hermes.safeTransfer(to, reward)`:
  - **What is controllable?**: `to`.
  - **If return value controllable, how is it used and how can it go wrong?**: There is no return value.
  - **What happens if it reverts, reenters, or does other unusual control flow?**: It can revert if the balance of the current contract is less than the reward value.

## Function: `claimReward`

Allows any caller to receive the reward if it is assigned to them.

### Branches and code coverage

**Intended branches:**

- Claim of reward in two parts.
  - [ ] Test coverage
- Claim full reward.
  - [ ] Test coverage

**Negative behavior:**

- Repeated claim after full claim.
  - [ ] Negative test?
- The caller tries to claim more.
  - [ ] Negative test?
- The caller does not have a reward to claim.
  - [ ] Negative test?

### Inputs

- `amountRequested`:
  - **Control**: Full control.
  - **Authorization**: Cannot be more than `rewards[msg.sender]`.
  - **Impact**: The amount that the caller wants to claim.
- `to`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: The receiver of the reward.

### Function call analysis

- `hermes.safeTransfer(to, reward)`:
  - **What is controllable?**: `to`.
  - **If return value controllable, how is it used and how can it go wrong?**: There is no return value here.
  - **What happens if it reverts, reenters, or does other unusual control flow?**: It can revert if the balance of the current contract is less than the reward value.

## Function: `withdrawToken`

Allows the withdrawal of unstaked tokens. The `stakedTimestamp` must be zero, otherwise the token is staked. Only the owner of the tokens can call this function.

### Branches and code coverage

**Intended branches:**

- To a new owner of the token.
  - [ ] Test coverage

**Negative behavior:**

- `tokenId` does not exist.
  - [ ] Negative test?
- `tokenId` is staked.
  - [ ] Negative test?
- `msg.sender` is not `deposit.owner`.
  - [ ] Negative test?

### Inputs

- `data`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: Any data that will be passed to the `ERC721TokenReceiver(to).onERC721Received` function call.
- `to`:
  - **Control**: Full control.
  - **Authorization**: `to != address(0)`.
  - **Impact**: The receiver of the tokenId.
- `tokenId`:
  - **Control**: Full control.
  - **Authorization**: `deposits` contains `tokenId`.
  - **Impact**: The ID of the tokens that will be transferred to the receiver in case of token unstaking.

### Function call analysis

- `nonfungiblePositionManager.safeTransferFrom(address(this), to, tokenId, data)`:
  - **What is controllable?**: `to`, `tokenId`, and `data`.
  - **If return value controllable, how is it used and how can it go wrong?**: There is no return value.
  - **What happens if it reverts, reenters, or does other unusual control flow?**: It can revert if this contract is not the current owner of the token.

## Function: `endIncentive`

Transfers the remaining part of the reward to the minter.

### Preconditions

The end time must have come, and all tokens should be unstaked from this `IncentiveKey`.

### Branches and code coverage

**Intended branches:**

- The minter received the full unclaimed balance.
  - [ ] Test coverage

**Negative behavior:**

- The end time has not come.
  - [ ] Negative test?
- `incentive.numberOfStakes` is nonzero.
  - [ ] Negative test?
- Double call for the same valid `key`.
  - [ ] Negative test?
- Non-existing `key` object.
  - [ ] Negative test?

### Inputs

- `key`:
  - **Control**: Full control.
  - **Authorization**: `incentiveId` must exist for this `key`.
  - **Impact**: The `key` object contains the pool address and start time. Also, the `incentiveId` value is calculated based on the `key`. Only one `incentiveId` value must correspond to each key object.

### Function call analysis

- `hermes.safeTransfer(minter, refund)`:
  - **What is controllable?**: Nothing.
  - **If return value controllable, how is it used and how can it go wrong?**: There is no return value.
  - **What happens if it reverts, reenters, or does other unusual control flow?**: It reverts if this contract does not have enough tokens.

## Function: `createIncentive`

Allows anyone to add the reward.

### Preconditions

`key.pool` must be a registered pool.

### Branches and code coverage

**Intended branches:**

- The Hermes balance of the contract is increased by `reward`.
  - [ ] Test coverage

**Negative behavior:**

- Wrong `key.startTime`.
  - [ ] Negative test?
- Reward is zero.
  - [ ] Negative test?
- `gauges` does not contain the `key.pool` address.
  - [ ] Negative test?

### Inputs

- `key.pool`:
  - **Control**: Full control.
  - **Authorization**: Only a registered pool.
  - **Impact**: The Uniswap V3 pool address.
- `reward`:
  - **Control**: Full control.
  - **Authorization**: `msg.sender` must have enough tokens to transfer to the contract. The reward is not zero.
  - **Impact**: The reward value is used for the staking reward calculation.
- `key.startTime`:
  - **Control**: Full control.
  - **Authorization**: Must be `block.timestamp`, and `startTime - block.timestamp` must be `maxIncentiveStartLeadTime`.
  - **Impact**: The time when the epoch begins.

### Function call analysis

- `hermes.safeTransferFrom(msg.sender, address(this), reward)`:
  - **What is controllable?**: `reward`.
  - **If return value controllable, how is it used and how can it go wrong?**: There is no return value.
  - **What happens if it reverts, reenters, or does other unusual control flow?**: Hermes is a trusted token contract, so there are no problems.

## Function: `createIncentiveFromGauge`

Allows the gauge contract to add the reward. This function is called from the `newEpoch` function of the gauge contract.

### Preconditions

The gauge pool for `msg.sender` must be registered.

### Branches and code coverage

**Intended branches:**

- The Hermes balance of this contract increases by `reward` value.
  - [ ] Test coverage
- Check that reward is increased.
  - [ ] Test coverage

**Negative behavior:**

- Reward is zero.
  - [ ] Negative test?
- Caller is not a registered gauge.
  - [ ] Negative test?

### Inputs

- `reward`:
  - **Control**: Full control. But this function can only be called by a trusted gauge contract, which does not control the reward value and receives it from `flywheelGaugeRewards.getAccruedRewards()`. The gauge does not control the `flywheelGaugeRewards` address.
  - **Authorization**: `msg.sender` must have enough tokens to transfer to the contract. The reward is not zero.
  - **Impact**: The reward value is used for the staking reward calculation.

### Function call analysis

- `hermes.safeTransferFrom(msg.sender, address(this), reward)`:
  - **What is controllable?**: `reward`.
  - **If return value controllable, how is it used and how can it go wrong?**: There is no return value.
  - **What happens if it reverts, reenters, or does other unusual control flow?**: Hermes is a trusted token contract, so there are no problems.

## Function: `onERC721Received`

This function is called from the `nonfungiblePositionManager` contract during the `safeTransferFrom` call. Allows to deposit and stake tokens.

#### Branches and code coverage

**Intended branches:**

- The `tokenId` Staked.
  - [ ] Test coverage
- The new owner of `tokenId` the current contract.
  - [ ] Test coverage

**Negative behavior:**

- Caller is not `nonfungiblePositionManager`.
  - [ ] Negative test?

#### Inputs

- `tokenId`:
  - **Control**: Controlled, but the caller of `safeTransferFrom` must be owner or approved.
  - **Authorization**: No checks.
  - **Impact**: The token that is transferred to contract and staked.
- `from`:
  - **Control**: Controlled, but the caller must have approval for transferring or must be called from the `safeTransferFrom` function.
  - **Authorization**: No checks.
  - **Impact**: The owner of the contract.

#### Function call analysis

- `NFTPositionInfo.getPositionInfo(factory, nonfungiblePositionManager, tokenId)`:
  - **What is controllable?** `tokenId`.
  - **If return value controllable, how is it used and how can it go wrong?** `tickLower` and `tickUpper` can be controlled by the caller, who can call the `mint` function. There are no problems here.
  - **What happens if it reverts, reenters, or does other unusual control flow?** No problems.

## Function: `stakeToken`

The function allows staking a Uniswap V3 LP token.

#### Preconditions

The `tokenId` must be transferred to the contract address, and `tokenId` must not be already staked. The `tokenId` can be staked not only by the original owner of the token.

#### Branches and code coverage

**Intended branches:**

- If `bribeAddress` is nonzero for `key.pool`, check that the fee is collected properly.
  - [ ] Test coverage
- `tokenId` was staked properly.
  - [ ] Test coverage

**Negative behavior:**

- `tokenId` is already staked.
  - [ ] Negative test?

#### Inputs

- `tokenId`:
  - **Control**: controlled
  - **Authorization**: the `tokenId` should be already staked.
  - **Impact**: the ID of the token which will be staked. It should be deposited previously, but there isn't a check.

#### Function call analysis

- `(IUniswapV3Pool pool, int24 tickLower, int24 tickUpper, uint128 liquidity) = NFTPositionInfo.getPositionInfo(factory, nonfungiblePositionManager, tokenId)`:
  - **What is controllable?** `tokenId`
  - **If return value controllable, how is it used and how can it go wrong?** `tickLower` and `tickUpper`, during minting the caller controls these values. There's no problem here.
  - **What happens if it reverts, reenters, or does other unusual control flow?** No problem.
- `gauges[pool].attachUser(tokenOwner)`:
  - **What is controllable?** nothing
  - **If return value controllable, how is it used and how can it go wrong?** There isn't a return value.
  - **What happens if it reverts, reenters, or does other unusual control flow?** It can revert if the gauge is already attached to the `tokenOwner` gauges or if the gauge is untrusted.

## Function: `unstakeToken`

The function allows to unstake a Uniswap LP token. Only the owner of the token can unstake before the endTime, but when endTime has come, anyone can unstake.

#### Preconditions

The `tokenId` must be staked.

#### Branches and code coverage

**Intended branches:**

- Reward calculated properly.
  - [ ] Test coverage

**Negative behavior:**

- `msg.sender` is not an owner and `endTime` has not come.
  - [ ] Negative test?
- `tokenId` is not staked.
  - [ ] Negative test?
- `tokenId` does not exist.
  - [ ] Negative test?
- `tokenId` is already unstaked.
  - [ ] Negative test?

#### Inputs

- `key.pool`:
  - **Control**: Full control.
  - **Authorization**: There is no direct check, but the `incentiveId` is calculated based on `key` object, and if `incentiveId` does not exist, the transaction will revert when trying to get liquidity value.
  - **Impact**: The pool address to get the seconds-per-liquidity value for calculating the reward.
- `deposit.owner`:
  - **Control**: The value from `deposits[tokenId]`; `tokenId` is controlled by the caller.
  - **Authorization**: If `block.timestamp < endTime`, the `msg.sender` should be equal to the owner.
  - **Impact**: The original owner of `tokenId`.
- `deposit.stakedTimestamp`:
  - **Control**: The value from `deposits[tokenId]`; `tokenId` is controlled by the caller.
  - **Authorization**: N/A.
  - **Impact**: Start time of staking. `stakedDuration` is calculated based on `startTime` and this value.
- `key.startTime`:
  - **Control**: Full control.
  - **Authorization**: `endTime` is calculated based on the `startTime` value, and `endTime` should be less than `block.timestamp` in case `msg.sender` is not the caller.
  - **Impact**: The time of the new cycle of staking.

### Function call analysis

- `key.pool.snapshotCumulativesInside(deposit.tickLower, deposit.tickUpper)`:
  - **What is controllable?** `deposit.tickLower`, `deposit.tickUpper` can be controlled indirectly.
  - **If return value controllable, how is it used and how can it go wrong?** Returns a snapshot of the tick cumulative, seconds per liquidity, and seconds inside a tick range.
  - **What happens if it reverts, reenters, or does other unusual control flow?** No problem.
- `gauges[key.pool].detachUser(owner)`:
  - **What is controllable?** `owner` and `key.pool` - but `gauges` should contain this value.
  - **If return value controllable, how is it used and how can it go wrong?** There is no return value.
  - **What happens if it reverts, reenters, or does other unusual control flow?** Can revert if this contract is not the strategy contract of the called gauge contract.
- `hermesGaugeBoost.getUserGaugeBoost(owner, address(gauges[key.pool]))`:
  - **What is controllable?** `owner` and `key.pool` - but `gauges` should contain this value.
  - **If return value controllable, how is it used and how can it go wrong?** Returns the maximum owner's boost token balance and total amount of boost tokens.
  - **What happens if it reverts, reenters, or does other unusual control flow?** No problems.
- `nonfungiblePositionManager.collect(INonfungiblePositionManager.CollectParams({tokenId: tokenId, recipient: bribeAddress, amount0Max: type(uint128).max, amount1Max: type(uint128).max }))`:
  - **What is controllable?** `tokenId`.
  - **If return value controllable, how is it used and how can it go wrong?** Returns the amount of fee that was collected. These values are used only for an emit event.
  - **What happens if it reverts, reenters, or does other unusual control flow?** Can revert in case of calculation errors.

## Function: `updateGauges`

The function can be called by anyone. Allows to add the gauge contract corresponding
to the pool contract. The caller controls the pool address, but the gauge address
can be connected only to the trusted pool. Because the `uniswapV3GaugeFactory.strategyGauges(address(uniswapV3Pool))`
can return only the addresses added by the owner of `UniswapV3GaugeFactory`, the `bribeDepots` value will be updated by `gauge.multiRewardsDepot()`
and `poolsMinimumWidth` by `gauge.minimumWidth()`.

#### Branches and code coverage

**Intended branches:**

**Negative behavior:**

- strategy Gauges does not contain `uniswapV3Pool` address.
  - [ ] Negative test?

#### Inputs

- `uniswapV3Pool`:
  - **Control**: Full control.
  - **Authorization**: There are no checks here, but if the `uniswapV3Pool` address
    is wrong or untrusted, the `strategyGauges` returns a zero address because
    only the owner of the `BaseV2GaugeFactory` contract can call the `createGauge`
    function to add the strategy address to `strategyGauges`.
  - **Impact**: The address of strategy connected with gauge address.

### Function call analysis

- `uniswapV3GaugeFactory.strategyGauges(address(uniswapV3Pool))`:
  - **What is controllable?** `uniswapV3Pool`.
  - **If return value controllable, how is it used and how can it go wrong?** The return
    value is not controllable because it is the value from the `strategyGauges`
    mapping, which can only be filled by the owner of the `BaseV2GaugeFactory`
    contract. If `strategyGauges` does not contain the `uniswapV3Pool` address,
    zero address will be returned.
  - **What happens if it reverts, reenters, or does other unusual controlflow?**
    No problems because this call is reading from a mapping.

## Function: `updateBribeDepot`

Allows to update the `bribeDepots` address for the `uniswapV3Pool` address by `multiRewardsDepot`
from the gauge contract. The `bribeDepots` address is used as the address
of the receiver of the fee owed to a position from the pool.

### Branches and code coverage

**Intended branches:**

- `bribeDepots` is set properly.
  - [ ] Test coverage

**Negative behavior:**

- The `gauges` array does not contain `uniswapV3Pool`.
  - [ ] Negative test?

### Inputs

- `uniswapV3Pool`:
  - **Control**: Full control.
  - **Authorization**: The zero address will be called if the `gauges` array does not
    contain the address.
  - **Impact**: The address of the pool associated with the gauge contract.

### Function call analysis

- `address(gauges[uniswapV3Pool].multiRewardsDepot())`:
  - **What is controllable?** `uniswapV3Pool`.
  - **If return value controllable, how is it used and how can it go wrong?** The
    return value is the address of the `MultiRewardsDepot` contract, which was
    created inside the constructor of the `BaseV2Gauge` contract. And due to
    the gauge contract, which returns this address, being a trusted contract,
    there aren't any problems.
  - **What happens if it reverts, reenters, or does other unusual controlflow?**
    No problems.

## Function: `updatePoolMinimumWidth`

Allows to update the `poolsMinimumWidth` value for the `uniswapV3Pool` address by `minimumWidth` from the gauge contract.

### Branches and code coverage

**Intended branches:**

- `poolsMinimumWidth` is set properly.
  - [ ] Test coverage

**Negative behavior:**

- The `gauges` array does not contain `uniswapV3Pool`.
  - [ ] Negative test?

### Inputs

- `uniswapV3Pool`:
  - **Control**: Full control.
  - **Authorization**: The zero address will be called if the `gauges` array does not
    contain the address.
  - **Impact**: The address of the pool associated with the gauge contract.

### Function call analysis

- `gauges[uniswapV3Pool].minimumWidth()`:
  - **What is controllable?** `uniswapV3Pool`.
  - **If return value controllable, how is it used and how can it go wrong?** The
    return value is the minimum allowed difference between ticks.
  - **What happens if it reverts, reenters, or does other unusual controlflow?**
    No problems.

