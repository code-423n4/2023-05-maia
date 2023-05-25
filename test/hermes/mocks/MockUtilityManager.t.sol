// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";

import {UtilityManager} from "@hermes/UtilityManager.sol";

contract MockUtilityManager is UtilityManager {
    mapping(address => uint256) public userClaimableWeight;
    mapping(address => uint256) public userClaimableBoost;
    mapping(address => uint256) public userClaimableGovernance;

    constructor(address _gaugeWeight, address _gaugeBoost, address _governance)
        UtilityManager(_gaugeWeight, _gaugeBoost, _governance)
    {}

    function setClaimableWeight(address user, uint256 amount) external {
        userClaimableWeight[user] = amount;
    }

    function setClaimableBoost(address user, uint256 amount) external {
        userClaimableBoost[user] = amount;
    }

    function setClaimableGovernance(address user, uint256 amount) external {
        userClaimableGovernance[user] = amount;
    }

    /*///////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Checks available weight allows for call.
    modifier checkWeight(uint256 amount) override {
        if (userClaimableWeight[msg.sender] < amount + userClaimedWeight[msg.sender]) revert InsufficientShares();
        _;
    }

    /// @dev Checks available boost allows for call.
    modifier checkBoost(uint256 amount) override {
        if (userClaimableBoost[msg.sender] < amount + userClaimedBoost[msg.sender]) revert InsufficientShares();
        _;
    }

    /// @dev Checks available governance allows for call.
    modifier checkGovernance(uint256 amount) override {
        if (userClaimableGovernance[msg.sender] < amount + userClaimedGovernance[msg.sender]) {
            revert InsufficientShares();
        }
        _;
    }
}
