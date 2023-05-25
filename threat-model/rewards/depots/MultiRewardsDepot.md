# MultiRewardsDepot

- [addAsset(address rewardsContract, address asset)](#function-addassetaddress-rewardscontract-address-asset)
- [getRewards()](#function-getrewards)
- [removeAsset(address rewardsContract)](#function-removeassetaddress-rewardscontract)


## Function: `addAsset(address rewardsContract, address asset)`

Adds an asset to be distributed by the specified rewards contract.

### Branches and code coverage

**Intended branches**

- A rewards contract with the corresponding asset is added to the allowlist.
  - [x] Test coverage

**Negative behavior**

- The rewards contract or asset already exists.

  - [x] Negative test?

- The caller is not the owner.
  - [ ] Negative test?

### Inputs

- `rewardsContract`:
  - **Control**: Must not already be added.
  - **Authorization**: No checks.
  - **Impact**: Will be able to claim rewards of type `asset`.
- `asset`:
  - **Control**: Must not be already added.
  - **Authorization**: No checks.
  - **Impact**: The balance of this asset will be transferred to the rewards contract when requested.

## Function: `getRewards()`

Returns the available rewards and transfers them to the `msg.sender`.

### Preconditions

Only callable by a flywheel rewards contract.

### Branches and code coverage

**Intended branches**

- The correct asset rewards are transferred to the `msg.sender`.
  - [x] Test coverage

**Negative behavior**

- The caller is not a rewards contract.
  - [ ] Negative test?

## Function: `removeAsset(address rewardsContract)`

Remove a rewards contract and its associated asset.

### Branches and code coverage

**Intended branches**

- The rewards contract and its associated asset will be removed.
  - [ ] Test coverage

**Negative behavior**

- The rewards contract does not exist.
  - [ ] Negative test?
- The caller is not the owner.
  - [ ] Negative test?

### Inputs

- `rewardsContract`:
  - **Control**: Must already be added.
  - **Authorization**: No checks.
  - **Impact**: Rewards contract and its associated asset will be removed.

