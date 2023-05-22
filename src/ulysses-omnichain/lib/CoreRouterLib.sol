// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

struct route {
    address from;
    address to;
    bool stable;
}

struct DepositToPortRemoteInput {
    address nativeToken;
    uint256 deposit;
    uint256 toChain;
    address depositor;
    uint256 timestamp;
}

struct WithdrawFromPortRemoteInput {
    address recipient;
    address localToken;
    uint256 amount;
    address depositor;
    uint256 timestamp;
    uint256 fromChain;
}
