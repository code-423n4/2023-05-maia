// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.10;

/// IAnycallConfig interface of the anycall config
interface IAnycallConfig {
    function calcSrcFees(address _app, uint256 _toChainID, uint256 _dataLength) external view returns (uint256);

    function executionBudget(address _app) external view returns (uint256);

    function deposit(address _account) external payable;

    function withdraw(uint256 _amount) external;
}
