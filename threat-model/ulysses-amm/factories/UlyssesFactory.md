# UlyssesFactory

- [createPool(ERC20 asset, address owner)](#function-createpoolerc20-asset-address-owner)
- [createToken(uint256[] poolIds, uint256[] weights, address owner)](#function-createtokenuint256-poolids-uint256-weights-address-owner)



## Function: `createPool(ERC20 asset, address owner)`

Allows anyone to create the new pool contract with arbitrary `asset` and `owner`.

### Inputs

- `asset`
    - **Validation**: no checks
    - **Impact**: the underlying asset token that is used for UlyssesERC2426 initialization
- `owner`
    - **Validation**: no checks
    - **Impact**: owner of pool

### Branches and code coverage (including function calls)

**Intended branches**
- new pool created properly 
  - [ ] Test coverage

**Negative behaviour**
- zero asset address
  - [ ] Negative test
- zero owner address
  - [ ] Negative test

### Function call analysis

- `_createPool(ERC20 asset, address owner) -> UlyssesPoolDeployer.deployPool(_poolId, address(asset), "Ulysses Pool", "ULP", owner, address(this));`
    - **External/Internal?**: Internal (library)
    - **Argument control?**: asset, owner
    - **Impact**: deploy a new Ulysses pool


## Function: `createToken(uint256[] poolIds, uint256[] weights, address owner)`

Allows any caller to deploy the `UlyssesToken` contract using the existed `pools` addresses as `_assets` and arbitrary weights. 

### Inputs

- `poolIds`
    - **Validation**: no checks
    - **Impact**: the id's of pools created over `_createPool`
- `weights`
    - **Validation**: no checks
    - **Impact**: weights for the corresponding pools
- `owner`
    - **Validation**: no checks
    - **Impact**: the owner of new UlyssesToken

### Branches and code coverage (including function calls)

**Intended branches**
- owner owns new UlyssesToken address
  - [ ] Test coverage

**Negative behaviour**
- `poolIds` contains non existed pool ids
  - [ ] Negative test
- `weights` contains zero values
  - [ ] Negative test
- `owner` is zero address
  - [ ] Negative test
- the poolIds.length != weights.length
  - [ ] Negative test

### Function call analysis

- `new UlyssesToken(_tokenId,destinations,weights,"Ulysses Token","ULT",owner);`
    - **External/Internal?**: External
    - **Argument control?**: destinations, weights, owner
    - **Impact**: deploy new UlyssesToken contract with arbitrary weights and owner address, the caller can select any of the existing pools created over createPool or createPools functions.

