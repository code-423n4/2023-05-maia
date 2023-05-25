# ERC4626PartnerManager

- [claimOutstanding()](#function-claimoutstanding)
- [increaseConversionRate(uint256 newRate)](#function-increaseconversionrateuint256-newrate)
- [migratePartnerVault(address newPartnerVault)](#function-migratepartnervaultaddress-newpartnervault)
- [transferFrom(address from, address to, uint256 amount)](#function-transferfromaddress-from-address-to-uint256-amount)
- [transfer(address to, uint256 amount)](#function-transferaddress-to-uint256-amount)
- [updateUnderlyingBalance()](#function-updateunderlyingbalance)


## Function: `claimOutstanding()`

Claims all outstanding underlying bHermes utility tokens for `msg.sender`.

#### Branches and code coverage

**Intended branches**

- The `msg.sender` is sent all of their outstanding tokens.
  - [x] Test coverage

## Function: `increaseConversionRate(uint256 newRate)`

Allows the owner to raise the conversion rate used for deposits. The conversion rate can only be increased. This function sets the ratio between pbHermes<>bHermes. If the ratio is 1, it means that 1 $pbHermes has 1 $bHermes worth of voting power.

#### Branches and code coverage

**Intended branches**

- The new rate is updated, and the partner governance tokens are minted.
  - [ ] Test coverage

**Negative behavior**

- The new rate is less than the current rate.
  - [ ] Negative test?
- The caller is not the owner.
  - [ ] Negative test?
- The new rate is greater than the ratio of bHermesToken balance to the totalSupply.
  - [ ] Negative test?

#### Inputs

- newRate:
  - **Control**: The new rate must be greater than the existing rate.
  - **Authorization**: The new rate must be less than `bHermes.balanceOf(address(this)) / totalSupply()`.
  - **Impact**: This will be the new ratio between pbHermes <> bHermes.

#### Function call analysis

- `address(bHermesToken).balanceOf(address(this))`:

  - **What is controllable?** N/A.
  - **If return value controllable, how is it used and how can it go wrong?** N/A.
  - **What happens if it reverts, reenters, or does other unusual control flow?** The increase will be reverted.

- `address(partnerGovernance).balanceOf(address(this))`:

  - **What is controllable?** N/A.
  - **If return value controllable, how is it used and how can it go wrong?** N/A.
  - **What happens if it reverts, reenters, or does other unusual control flow?** The increase will be reverted.

- `partnerGovernance.mint`:
  - **What is controllable?** The `newRate` is controllable but is restricted, as mentioned above.
  - **If return value controllable, how is it used and how can it go wrong?** N/A.
  - **What happens if it reverts, reenters, or does other unusual control flow?** The increase will be reverted.

## Function: `migratePartnerVault(address newPartnerVault)`

Migrates assets to a new partner vault.

### Preconditions

Only callable by the owner.

### Branches and code coverage

**Intended branches**

- All of the bHermes tokens are withdrawn from the old vault and transferred to the new vault. The old vault is no longer approved to manage the utility tokens, and the new vault is approved to manage the utility tokens.
  - [ ] Test coverage

**Negative behavior**

- The vault is not on the factory allowlist.
  - [ ] Negative test?

### Inputs

- newPartnerVault:
  - **Control**: The new vault must be known to the partner manager factory.
  - **Authorization**: No checks.
  - **Impact**: All of the existing assets will be sent to the new vault.

### Function call analysis

- `factory.vaultIds(IBaseVault(newPartnerVault))`:

  - **What is controllable?** The new vault address is controllable.
  - **If return value controllable, how is it used and how can it go wrong?** The return value must be true, or it will revert if the vault is unknown.
  - **What happens if it reverts, reenters, or does other unusual control flow?** The existing assets and vault will not be changed if it reverts.

- `IBaseVault(oldPartnerVault).clearAll()`:

  - **What is controllable?** N/A.
  - **If return value controllable, how is it used and how can it go wrong?** N/A.
  - **What happens if it reverts, reenters, or does other unusual control flow?** The existing assets and vault will not be changed if it reverts.

- `bHermesToken.claimOutstanding()`:

  - **What is controllable?** N/A.
  - **If return value controllable, how is it used and how can it go wrong?** N/A.
  - **What happens if it reverts, reenters, or does other unusual control flow?** The existing assets and vault will not be changed if it reverts.

- `address(gaugeWeight).safeApprove(oldPartnerVault, 0)`:

  - **What is controllable?** N/A.
  - **If return value controllable, how is it used and how can it go wrong?** N/A.
  - **What happens if it reverts, reenters, or does other unusual control flow?** The existing assets and vault will not be changed if it reverts.

- `address(gaugeBoost).safeApprove(oldPartnerVault, 0)`:

  - **What is controllable?** N/A.
  - **If return value controllable, how is it used and how can it go wrong?** N/A.
  - **What happens if it reverts, reenters, or does other unusual control flow?** The existing assets and vault will not be changed if it reverts.

- `address(governance).safeApprove(oldPartnerVault, 0)`:

  - **What is controllable?** N/A.
  - **If return value controllable, how is it used and how can it go wrong?** N/A.
  - **What happens if it reverts, reenters, or does other unusual control flow?** The existing assets and vault will not be changed if it reverts.

- `address(partnerGovernance).safeApprove(oldPartnerVault, 0)`:
  - **What is controllable?**

## Function: `transferFrom(address from, address to, uint256 amount)`

Hooks `ERC20.transferFrom` ensures that the user has enough unclaimed balances of each of the utility tokens that can be transferred.

### Branches and code coverage

**Intended branches**

- The `from` account has enough unclaimed tokens, and they are transferred.
  - [ ] Test coverage

**Negative behavior**

- The `from` account does not have enough unclaimed tokens.
  - [ ] Negative test?

### Inputs

- `from`:
  - **Control**: Full control.
  - **Authorization**: Checked by `checkTransfer` to ensure the account has enough unclaimed tokens.
  - **Impact**: The address from which the tokens are sent.
- `to`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: The address that will receive the tokens.
- `amount`:
  - **Control**: Full control.
  - **Authorization**: Checked by `checkTransfer` to ensure `from` has enough unclaimed tokens.
  - **Impact**: The amount of tokens to transfer.

## Function: `transfer(address to, uint256 amount)`

Hooks `ERC20.transfer`to ensure that the user has enough unclaimed balances of each
of the utility tokens that can be transferred.

### Branches and code coverage

**Intended branches**

- The sender has enough unclaimed tokens, and they are transferred.
  - [x] Test coverage

**Negative behavior**

- The sender does not have enough unclaimed tokens.
  - [ ] Negative test?

### Inputs

- `to`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: The address that will receive the tokens.
- `amount`:
  - **Control**: Full control.
  - **Authorization**: Checked by `checkTransfer` to ensure `msg.sender` has enough unclaimed tokens.
  - **Impact**: The amount of tokens to transfer.

## Function: `updateUnderlyingBalance()`

Updates the bHermes underlying balance by calling `claimOutstanding`.

### Branches and code coverage

**Intended branches**

- The underlying balances are updated.
  - [ ] Test coverage

### Function call analysis

- `bHermesToken.claimOutstanding()`:
  - **What is controllable?** N/A.
  - **If return value controllable, how is it used and how can it go wrong?** N/A.
  - **What happens if it reverts, reenters, or does other unusual controlflow?**
    The underlying balances will not be updated.

