# ERC4626MultiToken

- [withdraw(uint256[] assetsAmounts, address receiver, address owner)](#function-withdrawuint256-assetsamounts-address-receiver-address-owner)
- [redeem(uint256 shares, address receiver, address owner)](#function-redeemuint256-shares-address-receiver-address-owner)
- [deposit(uint256[] assetsAmounts, address receiver)](#function-deposituint256-assetsamounts-address-receiver)
- [mint(uint256 shares, address receiver)](#function-mintuint256-shares-address-receiver)

## Function: `withdraw(uint256[] assetsAmounts, address receiver, address owner)`

Allows burn shares from the owner and sends exactly the number of each asset token to the receiver. There is no `assetsAmounts` length check, so callers can receive not all assets tokens.

### Inputs

- `assetsAmounts`
    - **Validation**: no checks
    - **Impact**: the exact number of each assets tokens will transfer to the receiver
- `receiver`
    - **Validation**: there is a check is not zero address inside the `_transfer` function
    - **Impact**: the receiver of assets tokens
- `owner`
    - **Validation**: if msg.sender is not an owner, the msg.sender should have an approve from owner. owner should have enough shares
    - **Impact**: the owner of shares which will be burned.

### Branches and code coverage (including function calls)

**Intended branches**
- the balance of owner decrease by `shares`
  - [ ] Test coverage
- the receiver have got `assets` tokens of each `asset` 
  - [ ] Test coverage
- the `allowance` was decreased by `shares` 
  - [ ] Test coverage

**Negative behaviour**
- msg.sender is not an owner and doesn't have an approve
  - [ ] Negative test
- approve isn't enough
  - [ ] Negative test
- the owner balance of shares less than `shares`
  - [ ] Negative test
- receiver is zero address
  - [ ] Negative test

### Function call analysis

- `previewWithdraw(assets)`
    - **External/Internal?**: Internal
    - **Argument control?**: assets
    - **Impact**: returns the maximum number of shares rounded up
- `_burn(owner, shares);`
    - **External/Internal?**: Internal
    - **Argument control?**: owner
    - **Impact**: burn shares from owner
- `sendAssets(assetsAmounts) -> assets[i].safeTransfer(address(this), assetsAmounts[i]);`
    - **External/Internal?**: External
    - **Argument control?**: assetsAmounts
    - **Impact**: transfer each asset tokens to the receiver


## Function: `redeem(uint256 shares, address receiver, address owner)`

Allows redeems a specific number of shares from owner and send each asset tokens to receiver

### Inputs

- `shares`
    - **Validation**: allowance[owner][msg.sender] >= shares and balance of owner should be more or equal to shares
    - **Impact**: the exact number of shares to be burned
- `receiver`
    - **Validation**: there is a check is not zero address inside the `_transfer` function
    - **Impact**: the receiver of assets tokens
- `owner`
    - **Validation**: if msg.sender is not an owner, the msg.sender should have an approve from owner. owner should have enough shares
    - **Impact**: the owner of shares which will be burned.

### Branches and code coverage (including function calls)

**Intended branches**
- the balance of owner decrease by `shares`
  - [ ] Test coverage
- the receiver have got `assets` number of tokens of each asset tokens.
  - [ ] Test coverage
- the `allowance` was decreased by `shares` 
  - [ ] Test coverage

**Negative behaviour**
- msg.sender is not an owner and doesn't have an approve
  - [ ] Negative test
- approve isn't enough
  - [ ] Negative test
- the owner balance of shares less than `shares`
  - [ ] Negative test
- receiver is zero address
  - [ ] Negative test

### Function call analysis

- `previewRedeem(shares)`
    - **External/Internal?**: Internal
    - **Argument control?**: shares
    - **Impact**: returns the amounts of assets rounded down to be transferred to the recipient. 
- `_burn(owner, shares);`
    - **External/Internal?**: Internal
    - **Argument control?**: owner
    - **Impact**: burn shares from owner
- `sendAssets(assetsAmounts) -> assets[i].safeTransfer(address(this), assetsAmounts[i]);`
    - **External/Internal?**: External
    - **Argument control?**: assetsAmounts
    - **Impact**: transfer each asset tokens to the receiver. The assetsAmounts is calculated inside the `previewRedeem`


## Function: `deposit(uint256[] assetsAmounts, address receiver)`

Allows deposit assets. The caller provide the array with corresponding amount of asset tokens. 
There is no `assetsAmounts` length check, so callers can provide not all assets tokens.

### Inputs

- `assetsAmounts`
    - **Validation**: no checks.
    - **Impact**: contains the number of tokens that the caller will provide in exchange for shares.
- `receiver`
    - **Validation**: there is a check that != address(0) inside the `_mint` function 
    - **Impact**: the owner of minted shares

### Branches and code coverage (including function calls)

**Intended branches**
- assetsAmounts.length == assets.length
  - [ ] Test coverage
- the caller provided assets tokens
  - [ ] Test coverage
- the receiver owns expected amount of shares
  - [ ] Test coverage

**Negative behaviour**
- assetsAmounts.length < assets.length
  - [ ] Negative test
- assetsAmounts.length > assets.length
  - [ ] Negative test
- receiver is zero
  - [ ] Negative test
- assetsAmounts contains zero amounts `L!\ACK`
  - [ ] Negative test

### Function call analysis

- `previewDeposit(assetsAmounts)`
    - **External/Internal?**: Internal
    - **Argument control?**: assetsAmounts
    - **Impact**: calculate the minimum amount of shares for a given assetsAmounts.  
- `receiveAssets(assetsAmounts) -> assets[i].safeTransferFrom(msg.sender, address(this), assetsAmounts[i]);`
    - **External/Internal?**: External
    - **Argument control?**: assetsAmounts
    - **Impact**: transfer the number of tokens provided by the caller according to the addresses specified by the contract owner.
- `_mint(receiver, shares)`
    - **External/Internal?**: Internal
    - **Argument control?**: receiver
    - **Impact**: mint the `shares` amount of tokens for the receiver


## Function: `mint(uint256 shares, address receiver)`

Allows mint exactly shares to receiver by depositing assets. The caller will provide the corresponding amount of each asset token.

### Inputs

- `shares`
    - **Validation**: the caller should have enough amount of asset tokens to get the accordingly amount of shares
    - **Impact**: the expected number of shares to be minted
- `receiver`
    - **Validation**: there is a check that != address(0) inside the `_mint` function 
    - **Impact**: the owner of minted shares

### Branches and code coverage (including function calls)

**Intended branches**
- the expected number of assets of each asset token was transferred from the caller
  - [ ] Test coverage
- the balance of receiver increase by shares number
  - [ ] Test coverage

**Negative behaviour**
- caller doesn't have enough tokens
  - [ ] Negative test

### Function call analysis

- `previewMint(shares)`
    - **External/Internal?**: Internal
    - **Argument control?**: `shares`
    - **Impact**: returns the number of assets rounded up to be transferred from the caller to mint the exact shares
- `receiveAssets(assetsAmounts) -> assets[i].safeTransferFrom(msg.sender, address(this), assetsAmounts[i]);`
    - **External/Internal?**: External
    - **Argument control?**: nothing
    - **Impact**: transfer each ERC20 `asset` tokens from the caller to contract. the `assetsAmounts` calculated inside the `previewMint`
- `_mint(receiver, shares);`
    - **External/Internal?**: Internal
    - **Argument control?**: `receiver`
    - **Impact**: mint the `shares` amount of tokens for the receiver

