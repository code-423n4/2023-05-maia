# RootPort

- [initializeEcosystemTokenAddresses(address hermesGlobalAddress, address maiaGlobalAddress)](#function-initializeecosystemtokenaddressesaddress-hermesglobaladdress-address-maiaglobaladdress)
- [toggleBridgeAgent(address _bridgeAgent)](#function-togglebridgeagentaddress-_bridgeagent)
- [addEcosystemTokenToChain(address ecoTokenGlobalAddress, address ecoTokenLocalAddress, uint256 toChainId)](#function-addecosystemtokentochainaddress-ecotokenglobaladdress-address-ecotokenlocaladdress-uint256-tochainid)
- [syncBranchBridgeAgentWithRoot(address _newBranchBridgeAgent, address _rootBridgeAgent, uint24 _branchChainId)](#function-syncbranchbridgeagentwithrootaddress-_newbranchbridgeagent-address-_rootbridgeagent-uint24-_branchchainid)
- [addBridgeAgent(address _manager, address _bridgeAgent)](#function-addbridgeagentaddress-_manager-address-_bridgeagent)



## Function: `initializeEcosystemTokenAddresses(address hermesGlobalAddress, address maiaGlobalAddress)`
Allows owner of contract add `hermes` and `maia` global addresses to `getGlobalAddressFromLocal` and `getLocalAddressFromGlobal` mapping. There aren't any checks so it is possible to rewrite existing addresses


## Function: `toggleBridgeAgent(address _bridgeAgent)`

Allows owner of contract activate/deactivate BridgeAgent address.


## Function: `addEcosystemTokenToChain(address ecoTokenGlobalAddress, address ecoTokenLocalAddress, uint256 toChainId)`

Allows owner of contract add addresses to `getGlobalAddressFromLocal` and `getLocalAddressFromGlobal` mapping. There aren't any checks so it is possible to rewrite existing addresses


## Function: `syncBranchBridgeAgentWithRoot(address _newBranchBridgeAgent, address _rootBridgeAgent, uint24 _branchChainId)`

only for requiresCoreBridgeAgent. Allows coreBridgeAgent to set the `_newBranchBridgeAgent` address for `_rootBridgeAgent` contract.

### Inputs

- `_newBranchBridgeAgent`
    - **Validation**: no checks
    - **Impact**: the address of BranchBridgeAgent
- `_rootBridgeAgent`
    - **Validation**: `IBridgeAgent(_rootBridgeAgent).getBranchBridgeAgent(_branchChainId)` should be zero and `_newBranchBridgeAgent` should be allowed by manager of `_rootBridgeAgent`
    - **Impact**: the address of contract _rootBridgeAgent which will be called to set `_newBranchBridgeAgent`
- `_branchChainId`
    - **Validation**: `IBridgeAgent(_rootBridgeAgent).getBranchBridgeAgent(_branchChainId)` should be zero
    - **Impact**: chainId of the chain to set the `_newBranchBridgeAgent` for

### Branches and code coverage (including function calls)

**Intended branches**
- `getBranchBridgeAgent` for `_branchChainId` is set to `_newBranchBridgeAgent` value inside the `_rootBridgeAgent` contract
  - [x] Test coverage

**Negative behaviour**
- caller is not requiresCoreBridgeAgent
  - [ ] Negative test
- getBranchBridgeAgent already set
  - [x] Negative test

### Function call analysis

- `IBridgeAgent(_rootBridgeAgent).getBranchBridgeAgent(_branchChainId)`
    - **External/Internal?**: External
    - **Argument control?**: _branchChainId
    - **Impact**: return the current BranchBridgeAgent contract address
- `IBridgeAgent(_rootBridgeAgent).isBranchBridgeAgentAllowed(_branchChainId, _newBranchBridgeAgent)`
    - **External/Internal?**: External
    - **Argument control?**: _branchChainId, _newBranchBridgeAgent
    - **Impact**: return true, if `_newBranchBridgeAgent` is allowed by manager of `_rootBridgeAgent`
- `IBridgeAgent(_rootBridgeAgent).syncBranchBridgeAgent(_newBranchBridgeAgent, _branchChainId)`
    - **External/Internal?**: External
    - **Argument control?**: 
        - _branchChainId, _newBranchBridgeAgent
    - **Impact**: set `_newBranchBridgeAgent` address for `_rootBridgeAgent` contract


## Function: `addBridgeAgent(address _manager, address _bridgeAgent)`

Allows `BridgeAgentFactory` to add new `_bridgeAgent` address and manager address. Factory deploys the `_bridgeAgent` contract, the manager is address who initiate the `createBridgeAgent` call.

### Inputs

- `_manager`
    - **Validation**: no checks
    - **Impact**: the caller of `createBridgeAgent` function. This address will be able to call function of `_bridgeAgent` available only for manager. But the `_bridgeAgent` doesn't keep this address, so check it over this contract (`getBridgeAgentManager`).  
- `_bridgeAgent`
    - **Validation**: no checks
    - **Impact**: the address of new `RootBridgeAgent` contract. For BridgeAgents contracts available `requiresBridgeAgent` functions. 

### Branches and code coverage (including function calls)

**Intended branches**
- new `_bridgeAgent` added
  - [x] Test coverage
- _manager is manager of `_bridgeAgent`
  - [x] Test coverage

**Negative behaviour**
- _bridgeAgent already added
  - [x] Negative test
- caller is not `requiresBridgeAgentFactory`
  - [ ] Negative test

