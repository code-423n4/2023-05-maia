# ArbitrumBranchBridgeAgent

- [depositToPort(address underlyingAddress, uint256 amount)](#function-deposittoportaddress-underlyingaddress-uint256-amount)
- [withdrawFromPort(address localAddress, uint256 amount)](#function-withdrawfromportaddress-localaddress-uint256-amount)

## Function: `depositToPort(address underlyingAddress, uint256 amount)`

Allows any caller to deposit asset `amount` to `localPortAddress`. Function has a lock. Caller can provide an arbitrary `underlyingAddress` contract address which will be called.

### Inputs

- `underlyingAddress`
    - **Validation**: no checks here, but corresponding globalToken address should exists inside the `IRootPort(rootPortAddress).getLocalTokenFromUnder(_underlyingAddress, localChainId)`.
    - **Impact**: the address of deposited token
- `amount`
    - **Validation**: no checks
    - **Impact**: the amount of tokens

### Branches and code coverage (including function calls)

**Intended branches**
- the caller deposited the amount of `underlyingAddress` tokens
  - [x] Test coverage
- `globalToken` associated with `underlyingAddress` will be minted for `msg.sender`
  - [x] Test coverage

**Negative behaviour**
- revert if `underlyingAddress` token address is unknown
  - [x] Negative test
- revert if caller doesn't have enough `underlyingAddress` tokens
  - [ ] Negative test

### Function call analysis

- `IArbPort(localPortAddress).depositToPort(msg.sender, msg.sender, underlyingAddress, amount)`
    - **External/Internal?**: External
    - **Argument control?**: underlyingAddress, amount
    - **Impact**: check that the `globalToken` exists for `underlyingAddress` and mint `globalToken` `amount` tokens for the caller.


## Function: `withdrawFromPort(address localAddress, uint256 amount)`

Allows withdraw asset tokens from the `localPortAddress` contract. Function has a lock.

### Inputs

- `localAddress`
    - **Validation**: the `rootPort.getLocalAddressFromGlobal` array should contain this address as global token address
    - **Impact**: this tokens will be burned to exchange the `underlyingAddress` tokens
- `amount`
    - **Validation**: the caller should have more or equal amount of `localAddress` tokens
    - **Impact**: the amount of `localAddress` tokens will be burned and `underlyingAddress` will be received by the caller

### Branches and code coverage (including function calls)

**Intended branches**
- the balance of `localAddress` of msg.sender was decreased by `amount`
  - [x] Test coverage
- the caller receive the `amount` of `underlyingAddress` tokens
  - [x] Test coverage

**Negative behaviour**
- `localAddress` token address is unknown
  - [x] Negative test
- the caller doesn't have enough `localAddress` tokens
  - [ ] Negative test

### Function call analysis

- `IArbPort(localPortAddress).withdrawFromPort(msg.sender, msg.sender, localAddress, amount) -> IRootPort(rootPortAddress).getUnderlyingTokenFromLocal(_globalAddress, localChainId)`
    - **External/Internal?**: External
    - **Argument control?**: _globalAddress
    - **Impact**: return the `underlyingAddress` associated with `localAddress`. if `underlyingAddress` is zero, transaction will be reverted

