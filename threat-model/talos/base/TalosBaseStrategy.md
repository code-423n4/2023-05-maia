# TalosBaseStrategy

- [init](#function-init)
- [deposit](#function-deposit)
- [redeem](#function-redeem)
- [rerange](#function-rerange)
- [rebalance](#function-rebalance)
- [uniswapV3SwapCallback](#function-uniswapv3swapcallback)


## Function: `init`

Allows to initialize the optimizer with the given parameters. Can be called only one time.

### Inputs

- `amount0Desired`:
  - **Control**: Controlled.
  - **Authorization**: The `msg.sender` should have more or an equal amount of `_token0`.
  - **Impact**: Amount of tokens will be transferred to the current contract from `msg.sender`.
- `amount1Desired`:
  - **Control**: Controlled.
  - **Authorization**: The `msg.sender` should have more or an equal amount of `_token1`.
  - **Impact**: Amount of tokens will be transferred to the current contract from `msg.sender`.
- `receiver`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: The receiver of shares.

### Function call analysis

- `pool.slot0()`:
  - **What is controllable?** `pool`.
  - **If return value controllable, how is it used and how can it go wrong?** Returns the current tick for `_tickLower` and `_tickUpper` calculations.
  - **What happens if it reverts, reenters, or does other unusual control flow?** No problem.
- `address(_token).safeTransferFrom(msg.sender, address(this), amount0Desired);`
  - **What is controllable?** `_token`, `amount0Desired`.
  - **If return value controllable, how is it used and how can it go wrong?** There is no return value.
  - **What happens if it reverts, reenters, or does other unusual control flow?** Will revert if `msg.sender` does not have enough tokens.
- `address(_token).safeApprove(address(_nonfungiblePositionManager), type(uint256).max);`
  - **What is controllable?** `_token`.
  - **If return value controllable, how is it used and how can it go wrong?** There is no return value.
  - **What happens if it reverts, reenters, or does other unusual control flow?** N/A.
- `_nonfungiblePositionManager.mint`:
  - **What is controllable?** N/A.
  - **If return value controllable, how is it used and how can it go wrong?** There is no return value.
  - **What happens if it reverts, reenters, or does other unusual control flow?** N/A.
- `optimizer.maxTotalSupply()`:
  - **What is controllable?** Nothing.
  - **If return value controllable, how is it used and how can it go wrong?** Returns the maximum amount of `totalSupply`.
  - **What happens if it reverts, reenters, or does other unusual control flow?** No problem.
- `TalosStrategyStaked:nonfungiblePositionManager.approve(address(boostAggregator), _tokenId)`:
  - **What is controllable?** Nothing.
  - **If return value controllable, how is it used and how can it go wrong?** There is no return value.
  - **What happens if it reverts, reenters, or does other unusual control flow?** Give an approval for the created position `tokenId`.

## Function: `deposit`

Allows depositing tokens to the `tokenId` position. If the `tokenId` does not exist, the `init` function should be called.

### Inputs

- `amount0Desired`:
  - **Control**: Controlled.
  - **Authorization**: The `msg.sender` should have more or an equal amount of `_token0`.
  - **Impact**: Amount of tokens will be transferred to the current contract from `msg.sender`.
- `amount1Desired`:
  - **Control**: Controlled.
  - **Authorization**: The `msg.sender` should have more or an equal amount of `_token1`.
  - **Impact**: Amount of tokens will be transferred to the current contract from `msg.sender`.
- `receiver`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: The receiver of shares.

### Function call analysis

- `beforeDeposit:_earnFees:nonfungiblePositionManager.collect()`:
  - **What is controllable?** Nothing.
  - **If return value controllable, how is it used and how can it go wrong?** The return collected fee values.
  - **What happens if it reverts, reenters, or does other unusual control flow?** N/A.
- `TalosStrategyVanilla:beforeDeposit:_compoundFees`:
  - **What is controllable?** Nothing.
  - **If return value controllable, how is it used and how can it go wrong?** The return collected fee values.
  - **What happens if it reverts, reenters, or does other unusual control flow?** No problem.
- `TalosStrategyStaked:beforeDeposit:flywheel.accrue(_receiver)`:
  - **What is controllable?** Nothing.
  - **If return value controllable, how is it used and how can it go wrong?** The return collected fee values.
  - **What happens if it reverts, reenters, or does other unusual control flow?** No problem.

## Function: `redeem`

Withdraws tokens from liquidity position.

## Function: `rerange`

Finds base position and limit position for imbalanced token and mints all amounts to this position, including earned fees.

### Preconditions

Can only be called by the strategy manager.

### Branches and code coverage

**Intended branches**

- All liquidity is withdrawn, and the position is reranged.
  - [x] Test coverage

**Negative behavior**

- The caller is not the strategy manager.
  - [ ] Negative test?

## Function: `rebalance`

Swaps imbalanced token.

### Preconditions

Can only be called by the strategy manager.

### Branches and code coverage

**Intended branches**

- All liquidity is withdrawn, and the position is rebalanced.
  - [x] Test coverage

**Negative behavior**

- The caller is not the strategy manager.
  - [ ] Negative test?

## Function: `uniswapV3SwapCallback`

Can be called only by pool contract. Will be triggered during### Function: `constructor`

This contract is used for the `TalosStrategyVanilla` and `TalosStrategyStaked` contracts. They override some internal functions of this contract. Therefore, the behavior of the functions may change.

The contract is initialized over the `TalosBaseStrategyFactory` contract. The optimizer contract should be created over `optimizerFactory`. There is a check inside the `createTalosBaseStrategy` function. The `_nonfungiblePositionManager` is not controlled for `TalosStrategyVanilla`. But for `TalosStrategyStaked`, the user controls this address (add a check that `BoostAggregator` is a trusted contract). Also, `_boostAggregator` receives the `_nonfungiblePositionManager` address from the `UniswapV3Staker` contract. The `_owner` is not controlled - it belongs to the owner of the factory.

The pool is controlled by the caller, but inside the `UniswapV3Staker`, only a pool address from `uniswapV3GaugeFactory.strategyGauges` can be used, and only the owner can add this pool address. The `_strategyManager` is fully controlled. Only this address can call the `rebalance` and `range` functions.
