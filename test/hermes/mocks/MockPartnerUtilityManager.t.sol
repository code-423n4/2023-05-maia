// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";

import {
    IPartnerUtilityManager,
    PartnerUtilityManager,
    IUtilityManager,
    UtilityManager
} from "@maia/PartnerUtilityManager.sol";

contract MockPartnerUtilityManager is PartnerUtilityManager {
    mapping(address => uint256) public userClaimableWeight;
    mapping(address => uint256) public userClaimableBoost;
    mapping(address => uint256) public userClaimableGovernance;
    mapping(address => uint256) public userClaimablePartnerGovernance;

    constructor(
        address _gaugeWeight,
        address _gaugeBoost,
        address _governance,
        address _partnerGovernance,
        address _partnerVault
    ) PartnerUtilityManager(_gaugeWeight, _gaugeBoost, _governance, _partnerGovernance, _partnerVault) {}

    function setClaimableWeight(address user, uint256 amount) external {
        userClaimableWeight[user] = amount;
    }

    function setClaimableBoost(address user, uint256 amount) external {
        userClaimableBoost[user] = amount;
    }

    function setClaimableGovernance(address user, uint256 amount) external {
        userClaimableGovernance[user] = amount;
    }

    function setClaimablePartnerGovernance(address user, uint256 amount) external {
        userClaimablePartnerGovernance[user] = amount;
    }

    /*///////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Checks available weight allows for call.
    modifier checkWeight(uint256 amount) override {
        if (userClaimableWeight[msg.sender] < amount + userClaimedWeight[msg.sender]) {
            revert InsufficientShares();
        }
        _;
    }

    /// @dev Checks available boost allows for call.
    modifier checkBoost(uint256 amount) override {
        if (userClaimableBoost[msg.sender] < amount + userClaimedBoost[msg.sender]) {
            revert InsufficientShares();
        }
        _;
    }

    /// @dev Checks available governance allows for call.
    modifier checkGovernance(uint256 amount) override {
        if (userClaimableGovernance[msg.sender] < amount + userClaimedGovernance[msg.sender]) {
            revert InsufficientShares();
        }
        _;
    }

    /// @dev Checks available partner governance allows for call.
    modifier checkPartnerGovernance(uint256 amount) override {
        if (userClaimablePartnerGovernance[msg.sender] < amount + userClaimedPartnerGovernance[msg.sender]) {
            revert InsufficientShares();
        }
        _;
    }
}
