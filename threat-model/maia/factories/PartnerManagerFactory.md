# PartnerManagerFactory

- [addPartner(PartnerManager newPartnerManager)](#function-addpartnerpartnermanager-newpartnermanager)
- [addVault(IBaseVault newVault)](#function-addvaultibasevault-newvault)
- [removePartner(PartnerManager partnerManager)](#function-removepartnerpartnermanager-partnermanager)
- [removeVault(IBaseVault vault)](#function-removevaultibasevault-vault)


## Function: `addPartner(PartnerManager newPartnerManager)`

Used to add a new partner manager to the list of partners.

### Preconditions

Only callable by the owner.

### Branches and code coverage

**Intended branches**

- The new partner is added to the list.
  - [ ] Test coverage

**Negative behavior**

- The caller is not the owner.
  - [x] Negative test?

### Inputs

- `newPartnerManager`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: Will be added as a new partner.

## Function: `addVault(IBaseVault newVault)`

Used to add a new vault to the list of vaults.

### Preconditions

Only callable by the owner.

### Branches and code coverage

**Intended branches**

- The vault is added to the list of vaults.
  - [ ] Test coverage

**Negative behavior**

- The caller is not the owner.
  - [ ] Negative test?

### Inputs

- `newVault`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: Will be added to the list of vaults.

## Function: `removePartner(PartnerManager partnerManager)`

Used to remove a partner manager from the list of partners.

### Preconditions

Only callable by the owner.

Note: If the `partnerManager` does not exist, then the first partner in the list will be removed instead.

### Branches and code coverage

**Intended branches**

- The partner is removed from the list.
  - [x] Test coverage

**Negative behavior**

- Partner is not in the list.
  - [ ] Negative test?
- Caller is not the owner.
  - [ ] Negative test?

### Inputs

- `partnerManager`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: The partner will be removed from the list.

## Function: `removeVault(IBaseVault vault)`

Used to remove a partner manager from the list of partners.

### Preconditions

Only callable by the owner.

Note: If the vault does not exist, then the first vault in the list will be removed instead.

### Branches and code coverage

**Intended branches**

- The vault is removed from the list.
  - [x] Test coverage

**Negative behavior**

- The vault is not in the list.
  - [ ] Negative test?
- Caller is not the owner.
  - [ ] Negative test?

### Inputs

- `vault`:
  - **Control**: Full control.
  - **Authorization**: No checks.
  - **Impact**: The vault will be removed from the list.

