# UlyssesPool

- [claimProtocolFees()](#function-claimprotocolfees)

## Function: `claimProtocolFees()`

Calculate the amount of tokens which can be redeemed by owner of contract (protocol fee). 

### Branches and code coverage (including function calls)

**Intended branches**
- the expected amount of tokens was transferred to the owner
  - [ ] Test coverage

**Negative behaviour**
- caller is not an owner
  - [ ] Negative test


### Function call analysis

- `asset.safeTransfer(factory.owner(), claimed)`
    - **External/Internal?**: External
    - **Argument control?**: nothing
    - **Impact**: transfer of the full available fee to the owner of the factory contract

