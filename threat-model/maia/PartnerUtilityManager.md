# PartnerUtilityManager

- [claimBoost(uint256 amount)](#function-claimboostuint256-amount)
- [claimGovernance(uint256 amount)](#function-claimgovernanceuint256-amount)
- [claimPartnerGovernance(uint256 amount)](#function-claimpartnergovernanceuint256-amount)
- [claimWeight(uint256 amount)](#function-claimweightuint256-amount)
- [forfeitBoost(uint256 amount)](#function-forfeitboostuint256-amount)
- [forfeitGovernance(uint256 amount)](#function-forfeitgovernanceuint256-amount)
- [forfeitPartnerGovernance(uint256 amount)](#function-forfeitpartnergovernanceuint256-amount)
- [forfeitWeight(uint256 amount)](#function-forfeitweightuint256-amount)


## Function: `claimBoost(uint256 amount)`

Calls `ExtendsUtilityManager.claimBoost` to withdraw the required number of tokens from the partner vault.

#### Intended branches

- The required number of tokens are transferred from the vault and then to the user.
  - [x] Test coverage

#### Negative behavior

- The `checkBoost` modifier reverts.
  - [ ] Negative test?

#### Inputs

- amount:
  - **Control**: Full control.
  - **Authorization**: The `checkBoost` modifier is implemented in the parent class to check the amount.
  - **Impact**: This will be the amount of tokens claimed.

#### Function call analysis

- `address(gaugeBoost).balanceOf(address(this))`:
  - **What is controllable?** N/A.
  - **If return value controllable, how is it used and how can it go wrong?** The return value is not controllable; it is used to ensure the contract has enough tokens to send to the user.
  - **What happens if it reverts, reenters, or does other unusual controlflow?** None of the tokens will be transferred.
- `IBaseVault(partnerVault).clearBoost(amount - boostAvailable)`:
  - **What is controllable?** The `amount` is controllable.
  - **If return value controllable, how is it used and how can it go wrong?** N/A.
  - **What happens if it reverts, reenters, or does other unusual controlflow?** None of the tokens will be transferred.

## Function: `claimGovernance(uint256 amount)`

Calls `ExtendsUtilityManager.claimGovernance` to withdraw the required number of tokens from the partner vault.

#### Intended branches

- The required number of tokens are transferred from the vault and then to the user.
  - [x] Test coverage

#### Negative behavior

- The `checkGovernance` modifier reverts.
  - [ ] Negative test?

#### Inputs

- amount:
  - **Control**: Full control.
  - **Authorization**: The `checkGovernance` is implemented in the parent class to check the amount.
  - **Impact**: This will be the amount of tokens claimed.

#### Function call analysis

- `address(governance).balanceOf(address(this))`:
  - **What is controllable?** N/A.
  - **If return value controllable, how is it used and how can it go wrong?** The return value is not controllable; it is used to ensure the contract has enough tokens to send to the user.
  - **What happens if it reverts, reenters, or does other unusual controlflow?** None of the tokens will be transferred.
- `IBaseVault(partnerVault).clearGovernance(amount - governanceAvailable)`:
  - **What is controllable?** The `amount` is controllable.
  - **If return value controllable, how is it used and how can it go wrong?** N/A.
  - **What happens if it reverts, reenters, or does other unusual controlflow?** None of the tokens will be transferred.

## Function: `claimPartnerGovernance(uint256 amount)`

Claims `amount` of partner governance utility tokens.

#### Intended branches

- The `amount` is 0, and the function returns.
  - [x] Test coverage
- The user is sent `amount` number of tokens, and their claimed balance is updated.
  - [x] Test coverage

#### Negative behavior

- The `checkPartnerGovernance` modifier fails.
  - [ ] Negative test?

#### Inputs

- amount:
  - **Control**: Full control.
  - **Authorization**: Is checked by `checkPartnerGovernance`, which the parent contract needs to implement.
  - **Impact**: The user will be sent this number of tokens.

#### Function call analysis

- `address(partnerGovernance).safeTransfer(msg.sender, amount)`:
  - **What is controllable?** `amount` is fully controllable.
  - **If return value controllable, how is it used and how can it go wrong?** N/A.
  - **What happens if it reverts, reenters, or does other unusual controlflow?** None of the tokens will be claimed.

## Function: `claimWeight(uint256 amount)`

Extends `UtilityManager.claimWeight` to withdraw the required number of tokens from the partner vault.

#### Branches and code coverage

**Intended branches**

- The required number of tokens are transferred from the vault and then to the user.
  - [x] Test coverage

**Negative behavior**

- The `checkWeight` modifier reverts.
  - [ ] Negative test?

#### Inputs

- amount:
  - **Control**: Full control.
  - **Authorization**: The `checkWeight` is implemented in the parent class to check the amount.
  - **Impact**: This will be the amount of tokens claimed.

#### Function call analysis

- `address(gaugeWeight).balanceOf(address(this))`:
  - **What is controllable?** N/A.
  - **If return value controllable, how is it used and how can it go wrong?** The return value is not controllable; it is used to ensure the contract has enough tokens to send to the user.
  - **What happens if it reverts, reenters, or does other unusual controlflow?** None of the tokens will be transferred.
- `IBaseVault(partnerVault).clearWeight(amount - weightAvailable)`:
  - **What is controllable?** The `amount` is controllable.
  - **If return value controllable, how is it used and how can it go wrong?** N/A.
  - **What happens if it reverts, reenters, or does other unusual controlflow?** None of the tokens will be transferred.

## Function: `forfeitBoost(uint256 amount)`

Extends `UtilityManager.forfeitBoost` to send any outstanding tokens to the partner vault.

#### Branches and code coverage

**Intended branches**

- Any outstanding tokens will be sent to the vault.
  - [ ] Test coverage

#### Inputs

- amount:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: Will be the amount of tokens forfeit.

#### Function call analysis

- `IBaseVault(partnerVault).applyBoost()`:
  - **What is controllable?** N/A.
  - **If return value controllable, how is it used and how can it go wrong?** N/A.
  - **What happens if it reverts, reenters, or does other unusual controlflow?**
    None of the tokens will be forfeit.

## Function: `forfeitGovernance(uint256 amount)`

Extends `UtilityManager.forfeitGovernance` to send any outstanding tokens to the partner vault.

#### Branches and code coverage

**Intended branches**

- Any outstanding tokens will be sent to the vault.
  - [ ] Test coverage

#### Inputs

- amount:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: Will be the amount of tokens forfeit.

#### Function call analysis

- `IBaseVault(partnerVault).applyGovernance()`:
  - **What is controllable?** N/A.
  - **If return value controllable, how is it used and how can it go wrong?** N/A.
  - **What happens if it reverts, reenters, or does other unusual controlflow?**
    None of the tokens will be forfeit.

## Function: `forfeitPartnerGovernance(uint256 amount)`

Forfeits amount of partner governance tokens.

#### Branches and code coverage

**Intended branches**

- The amount is 0, and nothing happens.
  - [x] Test coverage
- The user’s partner governance balance is reduced by amount, and the tokens are transferred from the user to the contract.
  - [x] Test coverage

**Negative behavior**

- The user has not claimed enough partner governance.
  - [ ] Negative test?

#### Inputs

- amount:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: Will be the amount of partner governance tokens forfeited.

#### Function call analysis

- `address(partnerGovernance).safeTransferFrom(msg.sender, address(this), amount)`:
  - **What is controllable?** The amount is fully controllable.
  - **If return value controllable, how is it used and how can it go wrong?** N/A.
  - **What happens if it reverts, reenters, or does other unusual controlflow?** The partner governance will not be forfeit.

## Function: `forfeitWeight(uint256 amount)`

Extends `UtilityManager.forfeitWeight` to send any outstanding tokens to the partner vault.

#### Branches and code coverage

**Intended branches**

- Any outstanding tokens will be sent to the vault.
  - [ ] Test coverage

#### Inputs

- amount:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: Will be the amount of tokens forfeit.

#### Function call analysis

- `IBaseVault(partnerVault).applyWeight()`:
  - **What is controllable?** N/A.
  - **If return value controllable, how is it used and how can it go wrong?** N/A.
  - **What happens if it reverts, reenters, or does other unusual controlflow?** None of the tokens will be forfeit.

