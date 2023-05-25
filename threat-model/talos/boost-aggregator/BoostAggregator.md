# BoostAggregator

- [addWhitelistedAddress(address user)](#function-addwhitelistedaddressaddress-user)
- [decrementGaugesBoostIndexed(uint256 boost, uint256 offset, uint256 num)](#function-decrementgaugesboostindexeduint256-boost-uint256-offset-uint256-num)
- [depositAndStake(uint256 tokenId)](#function-depositandstakeuint256-tokenid)
- [removeWhitelistedAddress(address user)](#function-removewhitelistedaddressaddress-user)
- [setOwnRewardsDepot(address rewardsDepot)](#function-setownrewardsdepotaddress-rewardsdepot)
- [setProtocolFee(uint256 \_protocolFee)](#function-setprotocolfeeuint256-_protocolfee)
- [unstakeAndWithdraw(uint256 tokenId)](#function-unstakeandwithdrawuint256-tokenid)
- [withdrawAllGaugeBoost(address to)](#function-withdrawallgaugeboostaddress-to)
- [withdrawGaugeBoost(address to, uint256 amount)](#function-withdrawgaugeboostaddress-to-uint256-amount)
- [withdrawProtocolFees(address to)](#function-withdrawprotocolfeesaddress-to)


## Function: `addWhitelistedAddress(address user)`

Add to the whitelist of addresses allowed to stake using this contract.

### Preconditions

Only the owner can call this function.

### Branches and code coverage

**Intended branches**

- The address is added to the whitelist.
  - [ ] Test coverage

**Negative behavior**

- The caller is not the owner.
  - [ ] Negative test?

### Inputs

- `user`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: The address will be added to the whitelist and can now stake.

## Function: `decrementGaugesBoostIndexed(uint256 boost, uint256 offset, uint256 num)`

A wrapper around `ERC20Boost.decrementGaugesBoostIndexed`.

### Branches and code coverage

**Intended branches**

- The page of boost gauges for the contract are decremented.
  - [ ] Test coverage

**Negative behavior**

- The caller is not the owner.
  - [ ] Negative test?

### Inputs

- `boost`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: The amount of boost to decrement.
- `offset`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: Used for paging the gauges.
- `num`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: Used for paging the gauges.

### Function call analysis

- `hermesGaugeBoost.decrementGaugesBoostIndexed(boost, offset, num)`:
  - **What is controllable?** All the arguments are fully controllable.
  - **If return value controllable, how is it used and how can it go wrong?** N/A.
  - **What happens if it reverts, reenters, or does other unusual control flow?**
    The gauges are not decremented.

## Function: `depositAndStake(uint256 tokenId)`

Deposit an NFT and then stake it.

### Preconditions

Requires the user to have approved the transfer and that they be whitelisted.

### Branches and code coverage

**Intended branches**

- The NFT is transferred from the `msg.sender` to this contract and then to the
  Uniswap V3 staker.
  - [x] Test coverage

**Negative behavior**

- The caller is not whitelisted.
  - [ ] Negative test?
- The token is not approved.
  - [ ] Negative test?

### Inputs

- `tokenId`
  - **Control**: Full control.
  - **Authorization**: No checks, but only whitelisted `msg.sender` can call this function.
  - **Impact**: The NFT will be deposited and staked to the Uniswap V3 staker.

### Function call analysis

- `uniswapV3Staker.tokenIdRewards(tokenId)`:
  - **What is controllable?** The `tokenId` is fully controllable.
  - **If return value controllable, how is it used and how can it go wrong?** Not
    controllable.
  - **What happens if it reverts, reenters, or does other unusual controlflow?**
    The token will not be deposited and staked.
- `nonfungiblePositionManager.safeTransferFrom(msg.sender, address(this), tokenId)`:
  - **What is controllable?** The `tokenId` is fully controllable.
  - **If return value controllable, how is it used and how can it go wrong?** Not
    controllable.
  - **What happens if it reverts, reenters, or does other unusual controlflow?**
    The token will not be deposited and staked.
- `nonfungiblePositionManager.safeTransferFrom(address(this), address(uniswapV3Staker), tokenId)`:
  - **What is controllable?** The `tokenId` is fully controllable.
  - **If return value controllable, how is it used and how can it go wrong?** Not
    controllable.
  - **What happens if it reverts, reenters, or does other unusual controlflow?**
    The token will not be deposited and staked.

## Function: `removeWhitelistedAddress(address user)`

Remove from the whitelist of addresses allowed to stake using this contract.

### Preconditions

Only the owner can call this function.

### Branches and code coverage

**Intended branches**

- The address is removed from the whitelist.
  - [ ] Test coverage

**Negative behavior**

- The caller is not the owner.
  - [ ] Negative test?

### Inputs

- `user`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: The address will be removed from the whitelist.

## Function: `setOwnRewardsDepot(address rewardsDepot)`

Set rewards depot for `msg.sender`.

### Branches and code coverage

**Intended branches**

- The rewards depot for a user is set to the supplied address.
  - [x] Test coverage

### Inputs

- `rewardsDepot`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: When unstaking, this will be where the rewards are sent.

## Function: `setProtocolFee(uint256 \_protocolFee)`

Sets the protocol fee to the specified amount.

### Preconditions

Only the owner can call this function.

### Branches and code coverage

**Intended branches**

- The protocol fee is set.
  - [ ] Test coverage

**Negative behavior**

- The caller is not the owner.
  - [ ] Negative test?
- The protocol fee is too high.
  - [ ] Negative test?

### Inputs

- `_protocolFee`
  - **Control**: Must be less than 10,000.
  - **Authorization**: No checks.
  - **Impact**: This value is used when calculating the percentage of rewards the contract will keep.

## Function: `unstakeAndWithdraw(uint256 tokenId)`

Unstake the NFT, claim any rewards, and then withdraw the NFT.

### Branches and code coverage

**Intended branches**

- The token is unstaked, the rewards are paid to the depot, and then it is withdrawn.
  - [x] Test coverage
- The token is unstaked, the rewards are paid to the user, and then it is withdrawn.
  - [x] Test coverage
- The token is unstaked, and there are no rewards so it is withdrawn.
  - [ ] Test coverage

**Negative behavior**

- The `msg.sender` is not the owner.
- [ ] Negative test?

### Inputs

- `tokenId`
  - **Control**: Full control.
  - **Authorization**: The `msg.sender` must be the user that staked the token.
  - **Impact**: The token will be unstaked and withdrawn.

### Function call analysis

- `uniswapV3Staker.unstakeToken(tokenId)`:
  - **What is controllable?** The `tokenId` is fully controllable.
  - **If return value controllable, how is it used and how can it go wrong?** Not controllable.
  - **What happens if it reverts, reenters, or does other unusual controlflow?**
    The token will not be unstaked or withdrawn.
- `uniswapV3Staker.tokenIdRewards(tokenId)`:
  - **What is controllable?** The `tokenId` is fully controllable.
  - **If return value controllable, how is it used and how can it go wrong?** The return value is not controllable, it is the total amount of rewards owed.
  - **What happens if it reverts, reenters, or does other unusual controlflow?**
    The token will not be unstaked or withdrawn.
- `uniswapV3Staker.claimReward(rewardsDepot, userRewards)`:
  - **What is controllable?** The `rewardsDepot` is fully controllable by calling `setOwnRewardsDepot`.
  - **If return value controllable, how is it used and how can it go wrong?** No return.
  - **What happens if it reverts, reenters, or does other unusual controlflow?**
    The token will not be unstaked or withdrawn.

## Function: `withdrawAllGaugeBoost(address to)`

Decrement every gauge boost and transfer them all to the specified address.

### Preconditions

Only callable by the owner.

### Branches and code coverage

**Intended branches**

- The boost gauges are decremented and all of the tokens transferred.
  - [ ] Test coverage

**Negative behavior**

- The caller is not the owner.
  - [ ] Negative test?

### Inputs

- `to`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: This address will receive all of the boost tokens owned by the contract.

### Function call analysis

- `hermesGaugeBoost.decrementAllGaugesAllBoost()`:
  - **What is controllable?** N/A.
  - **If return value controllable, how is it used and how can it go wrong?** N/A.
  - **What happens if it reverts, reenters, or does other unusual controlflow?**
    None of the tokens will be transferred.
- `address(hermesGaugeBoost).safeTransfer(to, hermesGaugeBoost.balanceOf(address(this)))`:
  - **What is controllable?** The `to` address is fully controllable.
  - **If return value controllable, how is it used and how can it go wrong?** N/A.
  - **What happens if it reverts, reenters, or does other unusual controlflow?**
    None of the tokens will be transferred.

## Function: `withdrawGaugeBoost(address to, uint256 amount)`

Withdraws a certain amount of boost tokens. This will currently fail if the contract has attached to a gauge as `hermesGaugeBoost.updateUserBoost` is not called to update the free gauge boost value.

### Preconditions

Only callable by the owner.

### Branches and code coverage

**Intended branches**

- The boost gauges are reduced by `amount` and sent to `to`.
  - [ ] Test coverage

**Negative behavior**

- Only callable by the owner.
  - [ ] Negative test?
- `amount` is greater than the number of tokens owned by the contract.
  - [ ] Negative test?

### Inputs

- `to`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: This address will receive the boost tokens.
- `amount`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: This is the amount of tokens to be received.

### Function call analysis

- `hermesGaugeBoost.decrementAllGaugesBoost(amount)`:
  - **What is controllable?** `amount` is fully controllable.
  - **If return value controllable, how is it used and how can it go wrong?** N/A.
  - **What happens if it reverts, reenters, or does other unusual controlflow?**
    None of the tokens will be transferred.
- `address(hermesGaugeBoost).safeTransfer(to, amount)`:
  - **What is controllable?** `amount` and `to` are fully controllable.
  - **If return value controllable, how is it used and how can it go wrong?** N/A.
  - **What happens if it reverts, reenters, or does other unusual controlflow?**
    None of the tokens will be transferred.

## Function: `withdrawProtocolFees(address to)`

Withdraws any accrued protocol fees.

### Preconditions

Only callable by the owner.

### Branches and code coverage

**Intended branches**

- The protocol rewards are sent to the specified address.
  - [ ] Test coverage

**Negative behavior**

- The caller is not the owner.
  - [ ] Negative test?

### Inputs

- `to`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: This address will have the rewards sent to it.

