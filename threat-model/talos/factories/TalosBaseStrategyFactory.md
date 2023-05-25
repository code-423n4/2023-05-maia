# TalosBaseStrategyFactory

- [createTalosBaseStrategy(IUniswapV3Pool pool, ITalosOptimizer optimizer, address strategyManager, byte[] data)](#function-createtalosbasestrategyiuniswapv3pool-pool-italosoptimizer-optimizer-address-strategymanager-byte-data)


## Function: `createTalosBaseStrategy(IUniswapV3Pool pool, ITalosOptimizer optimizer, address strategyManager, byte[] data)`

Creates a new strategy and adds it to the list.

### Branches and code coverage

**Intended branches**

- A new strategy is created and added to the list,
  - [ ] Test coverage

**Negative behavior**

- The optimizer was not created by the optimizer factory.
  - [ ] Negative test?

### Inputs

- `pool`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: Will be passed to the child contract to create a new strategy.
- `optimizer`:
  - **Control**: Full control.
  - **Authorization**: Must have been created by the optimizer factory.
  - **Impact**: Will be passed to the child contract to create a new strategy.
- `strategyManager`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: Will be passed to the child contract to create a new strategy.
- `data`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: Will be passed to the child contract to create a new strategy.

### Function call analysis

- `optimizerFactory.optimizerIds(TalosOptimizer(address(optimizer)))`:
  - **What is controllable?** `optimizer` is fully controllable.
  - **If return value controllable, how is it used and how can it go wrong?** If the return value is 0, then the function aborts.
  - **What happens if it reverts, reenters, or does other unusual controlflow?** The strategy is not created.

