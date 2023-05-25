# bHermesGauges

- [constructor()](#function-constructor)
- [mint()](#function-mint)
- [mint](#function-mint)


This contract is inherited from the `ERC20Gauges` contract.

## Function: `constructor()`

**Intended behavior**

Allows to initialize the `ERC20Gauges` and the `ERC20` contracts.

It also allows initializing the `owner` address and the `bHermes` contract address (the `mint` function is available only for `bHermes`).

## Function: `mint()`

## Function: `mint`

**Intended behavior**

Allows the `bHermes` contract to mint new tokens.

### Branches and code coverage

**Intended branches:**

- Check the balance of `to`.
  - [ ] Test coverage

**Negative behavior:**

- The caller is not `bHermes`.
  - [ ] Negative test?

### Inputs

- `amount`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: The number of tokens to be minted.
- `to`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: The receiver of the tokens.

