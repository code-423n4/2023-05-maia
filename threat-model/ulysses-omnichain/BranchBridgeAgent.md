# BranchBridgeAgent

- [retrySettlement(uint32 _settlementNonce)](#function-retrysettlementuint32-_settlementnonce)
- [callOutSigned(byte[] params, uint128 rootExecutionGas)](#function-calloutsignedbyte-params-uint128-rootexecutiongas)
- [redeemDeposit(uint32 _depositNonce)](#function-redeemdeposituint32-_depositnonce)
- [callOutSignedAndBridge(byte[] params, DepositInput dParams, uint128 rootExecutionGas)](#function-calloutsignedandbridgebyte-params-depositinput-dparams-uint128-rootexecutiongas)
- [callOut(byte[] params, uint128 rootExecutionGas)](#function-calloutbyte-params-uint128-rootexecutiongas)
- [callOutAndBridge(byte[] params, DepositInput dParams, uint128 rootExecutionGas)](#function-calloutandbridgebyte-params-depositinput-dparams-uint128-rootexecutiongas)
- [callOutAndBridgeMultiple(byte[] params, DepositMultipleInput dParams, uint128 rootExecutionGas)](#function-calloutandbridgemultiplebyte-params-depositmultipleinput-dparams-uint128-rootexecutiongas)
- [callOutSignedAndBridgeMultiple(byte[] params, DepositMultipleInput dParams, uint128 rootExecutionGas)](#function-calloutsignedandbridgemultiplebyte-params-depositmultipleinput-dparams-uint128-rootexecutiongas)

## Function: `retrySettlement(uint32 _settlementNonce)`

Send cross-chain request with data with type `bytes1(0x07)` without depositing the tokens.



## Function: `callOutSigned(byte[] params, uint128 rootExecutionGas)`

The same as the `callOut` function, but inside the data will be encoded the `bytes1(0x04)` type.


## Function: `redeemDeposit(uint32 _depositNonce)`

Allows to redeem tokens back to the owner of deposit. The function can be called by any caller, not only by the owner of deposit!!

### Inputs

- `_depositNonce`
    - **Validation**: getDeposit[_depositNonce].status should not be equal DepositStatus.Failed
    - **Impact**: id of an existing deposit

### Branches and code coverage (including function calls)

**Intended branches**
- the `getDeposit[_depositNonce]` data is reset
  - [x] Test coverage
- the owner of deposit received the deposited funds
  - [x] Test coverage

**Negative behaviour**
- _depositNonce is invalid
  - [ ] Negative test
- msg.sender != owner of deposit
  - [ ] Negative test
- repeated redeem of funds without additional deposit is not possible
  - [x] Negative test

### Function call analysis

- `_redeemDeposit(_depositNonce) -> IPort(localPortAddress).bridgeIn(deposit.owner, deposit.hTokens[i], deposit.amounts[i] - deposit.deposits[i])`
    - **External/Internal?**: External
    - **Argument control?**: Nothing
    - **Impact**: mint the value of the difference between `amounts` and `deposits` the `deposit.hTokens[i]` tokens to the `deposit.owner`
- `_redeemDeposit(_depositNonce) -> IPort(localPortAddress).withdraw(deposit.owner, deposit.tokens[i], deposit.deposits[i])`
    - **External/Internal?**: External
    - **Argument control?**: Nothing
    - **Impact**: transfer the `deposits[i]` amount of the `tokens[i]` to the deposit.owner
- `_redeemDeposit(_depositNonce) -> IPort(localPortAddress).withdraw(deposit.owner, address(wrappedNativeToken), deposit.depositedGas)`
    - **External/Internal?**: External
    - **Argument control?**: Nothing
    - **Impact**: transfer the `deposit.depositedGas` amount of the `wrappedNativeToken` to the deposit.owner


## Function: `callOutSignedAndBridge(byte[] params, DepositInput dParams, uint128 rootExecutionGas)`

Deposit tokens and send Cross-Chain request with data with type `bytes1(0x05)`.



## Function: `callOut(byte[] params, uint128 rootExecutionGas)`

Allows to call the Root Omnichain Router without doing deposit, only gas amount will be deposited. The new `Deposit` object will be saved inside the `getDeposit` with incremented nonce key. Function has a lock.
1. Check msg.value
2. call `Port(localPortAddress).bridgeOutMultiple(_user, _hTokens, _tokens, _amounts, _deposits)`
### Inputs

- `params`
    - **Validation**: no checks
    - **Impact**: will encoded inside the data which is used for cross-chain call
- `rootExecutionGas`
    - **Validation**: no checks
    - **Impact**: will encoded inside the data which is used for cross-chain call. the gas allocated for omnichain execution
- `msg.value`
    - **Validation**: `msg.value` should be more than `MIN_FALLBACK_OVERHEAD`
    - **Impact**: fallback gas amount, this value is deposited to the wrappedNativeToken and transferred to the localPortAddress

### Function call analysis

- `_callOut(msg.sender, params, rootExecutionGas) -> _depositAndCall(depositor, data, address(0), address(0), 0, 0) -> _createDepositSingle(_depositor, _hToken, _token, _amount, _deposit) -> _createDepositMultiple(_user, hTokens, tokens, amounts, deposits) -> IPort(localPortAddress).bridgeOutMultiple(_user, _hTokens, _tokens, _amounts, _deposits)`
    - **External/Internal?**: External
    - **Argument control?**: _user = `msg.sender`, hToken = address(0), tokens[0] = address(0), amounts[0] = 0, deposits[0] = 0
    - **Impact**: the function will do nothing with zero amounts in this case
- `_callOut(msg.sender, params, rootExecutionGas) -> _depositAndCall(depositor, data, address(0), address(0), 0, 0) -> _createDepositSingle(_depositor, _hToken, _token, _amount, _deposit) -> _createDepositMultiple(_user, hTokens, tokens, amounts, deposits) -> wrappedNativeToken.deposit{value: msg.value}()`
    - **External/Internal?**: External
    - **Argument control?**: msg.value is controlled but should be more than `MIN_FALLBACK_OVERHEAD`
    - **Impact**: deposit to the wrapped native token contract the gas allocated for omnichain execution
- `_callOut(msg.sender, params, rootExecutionGas) -> _depositAndCall(depositor, data, address(0), address(0), 0, 0) -> _createDepositSingle(_depositor, _hToken, _token, _amount, _deposit) -> _createDepositMultiple(_user, hTokens, tokens, amounts, deposits) -> address(wrappedNativeToken).safeTransfer(localPortAddress, msg.value)`
    - **External/Internal?**: External
    - **Argument control?**: msg.value is controlled but should be more than `MIN_FALLBACK_OVERHEAD`
    - **Impact**: transfer this wrapped gas amount to the `localPortAddress`
- `_callOut(msg.sender, params, rootExecutionGas) -> _depositAndCall(depositor, data, address(0), address(0), 0, 0) -> _performCall(_data)-> IAnycallProxy(localAnyCallAddress).anyCall(
        rootBridgeAgentAddress, _calldata, rootChainId, AnycallFlags.FLAG_ALLOW_FALLBACK, ""
    )`
    - **External/Internal?**: External
    - **Argument control?**: _calldata
    - **Impact**: perform call to `localAnyCallAddress` contract with users `_calldata` for cross-chain messaging


## Function: `callOutAndBridge(byte[] params, DepositInput dParams, uint128 rootExecutionGas)`

Allows to perform a call to the Root Omnichain Router while depositing a single asset. The function has a lock. The arbitrary contracts controlled by user can be called. The new `Deposit` object will be saved inside the `getDeposit` with incremented nonce key. Function has a lock.

### Inputs

- `params`
    - **Validation**: no checks
    - **Impact**: will encoded inside the data which is used for cross-chain call
- `dParams`
    - **Validation**: no checks
    - **Impact**: the data is contains the tokens addresses and amounts are used for `bridgeOutMultiple` call for depositing
- `rootExecutionGas`
    - **Validation**: no checks
    - **Impact**: will encoded inside the data which is used for cross-chain call. the gas allocated for omnichain execution

### Function call analysis

- `_callOutAndBridge(msg.sender, params, dParams, rootExecutionGas) ->  _depositAndCall(depositor, data, dParams.hToken, dParams.token, dParams.amount, dParams.deposit) -> _createDepositSingle(_depositor, _hToken, _token, _amount, _deposit) -> _createDepositMultiple(_user, hTokens, tokens, amounts, deposits) -> IPort(localPortAddress).bridgeOutMultiple(_user, _hTokens, _tokens, _amounts, _deposits)`
    - **External/Internal?**: External
    - **Argument control?**: depositor, data, dParams.hToken, dParams.token, dParams.amount, dParams.deposit
    - **Impact**: deposit tokens into localPortAddress from msg.sender, the token address is provided as `_token` by caller. If the _amount > _deposit, than the difference between _amount and _deposit of `_hToken` will be deposited and burned, so the tokens will be locked 
- `_callOutAndBridge(msg.sender, params, dParams, rootExecutionGas) ->  _depositAndCall(depositor, data, dParams.hToken, dParams.token, dParams.amount, dParams.deposit) -> _createDepositSingle(_depositor, _hToken, _token, _amount, _deposit) -> _createDepositMultiple(_user, hTokens, tokens, amounts, deposits) -> wrappedNativeToken.deposit{value: msg.value}()`
    - **External/Internal?**: External
    - **Argument control?**: msg.value is controlled but should be more than `MIN_FALLBACK_OVERHEAD`
    - **Impact**: deposit to the wrapped native token contract the gas allocated for omnichain execution
- `_callOutAndBridge(msg.sender, params, dParams, rootExecutionGas) ->  _depositAndCall(depositor, data, dParams.hToken, dParams.token, dParams.amount, dParams.deposit) -> _createDepositSingle(_depositor, _hToken, _token, _amount, _deposit) -> _createDepositMultiple(_user, hTokens, tokens, amounts, deposits) -> address(wrappedNativeToken).safeTransfer(localPortAddress, msg.value)`
    - **External/Internal?**: External
    - **Argument control?**: msg.value is controlled but should be more than `MIN_FALLBACK_OVERHEAD`
    - **Impact**: transfer this wrapped gas amount to the `localPortAddress`


## Function: `callOutAndBridgeMultiple(byte[] params, DepositMultipleInput dParams, uint128 rootExecutionGas)`

The same as the `callOutAndBridge` but user provides multiplies addresses of tokens for deposit and lock.


## Function: `callOutSignedAndBridgeMultiple(byte[] params, DepositMultipleInput dParams, uint128 rootExecutionGas)`

Deposit multiple tokens and send cross-chain request with data with type `bytes1(0x06)`.


