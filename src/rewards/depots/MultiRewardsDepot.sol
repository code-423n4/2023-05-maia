// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";

import {RewardsDepot} from "./RewardsDepot.sol";

import {IMultiRewardsDepot} from "../interfaces/IMultiRewardsDepot.sol";

/// @title Multiple Rewards Depot - Contract for multiple reward token storage
contract MultiRewardsDepot is Ownable, RewardsDepot, IMultiRewardsDepot {
    /*///////////////////////////////////////////////////////////////
                        REWARDS DEPOT STATE
    //////////////////////////////////////////////////////////////*/

    /// @dev _assets[rewardsContracts] => asset (reward Token)
    mapping(address => address) private _assets;

    /// @notice _isRewardsContracts[rewardsContracts] => true/false
    mapping(address => bool) private _isRewardsContract;

    /// @notice _isAsset[asset] => true/false
    mapping(address => bool) private _isAsset;

    /**
     * @notice MultiRewardsDepot constructor
     *  @param _owner owner of the contract
     */
    constructor(address _owner) {
        _initializeOwner(_owner);
    }

    /*///////////////////////////////////////////////////////////////
                        GET REWARDS LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IMultiRewardsDepot
    function getRewards() external override(RewardsDepot, IMultiRewardsDepot) onlyFlywheelRewards returns (uint256) {
        return transferRewards(_assets[msg.sender], msg.sender);
    }

    /*///////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IMultiRewardsDepot
    function addAsset(address rewardsContract, address asset) external onlyOwner {
        if (_isAsset[asset] || _isRewardsContract[rewardsContract]) revert ErrorAddingAsset();
        _isAsset[asset] = true;
        _isRewardsContract[rewardsContract] = true;
        _assets[rewardsContract] = asset;

        emit AssetAdded(rewardsContract, asset);
    }

    /// @inheritdoc IMultiRewardsDepot
    function removeAsset(address rewardsContract) external onlyOwner {
        if (!_isRewardsContract[rewardsContract]) revert ErrorRemovingAsset();

        emit AssetRemoved(rewardsContract, _assets[rewardsContract]);

        delete _isAsset[_assets[rewardsContract]];
        delete _isRewardsContract[rewardsContract];
        delete _assets[rewardsContract];
    }

    /*///////////////////////////////////////////////////////////////
                                MODIFIERS   
    //////////////////////////////////////////////////////////////*/

    /// @notice modifier to check if msg.sender is a rewards contract
    modifier onlyFlywheelRewards() override {
        if (!_isRewardsContract[msg.sender]) revert FlywheelRewardsError();
        _;
    }
}
