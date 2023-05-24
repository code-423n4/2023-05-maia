// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";

import {bHermes, bHermesBoost, bHermesGauges} from "@hermes/bHermes.sol";

import {BaseV2GaugeFactory} from "./BaseV2GaugeFactory.sol";

import {IBaseV2GaugeManager} from "../interfaces/IBaseV2GaugeManager.sol";

/// @title Base V2 Gauge Factory Manager - Manages addition/removal of Gauge Factories to bHermes.
contract BaseV2GaugeManager is Ownable, IBaseV2GaugeManager {
    /*///////////////////////////////////////////////////////////////
                        GAUGE MANAGER STATE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBaseV2GaugeManager
    address public admin;

    /// @inheritdoc IBaseV2GaugeManager
    bHermesGauges public immutable bHermesGaugeWeight;

    /// @inheritdoc IBaseV2GaugeManager
    bHermesBoost public immutable bHermesGaugeBoost;

    /// @inheritdoc IBaseV2GaugeManager
    BaseV2GaugeFactory[] public gaugeFactories;

    /// @inheritdoc IBaseV2GaugeManager
    mapping(BaseV2GaugeFactory => uint256) public gaugeFactoryIds;

    /// @inheritdoc IBaseV2GaugeManager
    mapping(BaseV2GaugeFactory => bool) public activeGaugeFactories;

    /**
     * @notice Initializes Base V2 Gauge Factory Manager contract.
     * @param _bHermes bHermes contract
     * @param _owner can add BaseV2GaugeFactories.
     * @param _admin can transfer ownership of bHermesWeight and bHermesBoost.
     */
    constructor(bHermes _bHermes, address _owner, address _admin) {
        admin = _admin;
        _initializeOwner(_owner);
        bHermesGaugeWeight = _bHermes.gaugeWeight();
        bHermesGaugeBoost = _bHermes.gaugeBoost();
    }

    /// @inheritdoc IBaseV2GaugeManager
    function getGaugeFactories() external view returns (BaseV2GaugeFactory[] memory) {
        return gaugeFactories;
    }

    /*//////////////////////////////////////////////////////////////
                            EPOCH LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBaseV2GaugeManager
    function newEpoch() external {
        BaseV2GaugeFactory[] storage _gaugeFactories = gaugeFactories;

        uint256 length = _gaugeFactories.length;
        for (uint256 i = 0; i < length;) {
            if (activeGaugeFactories[_gaugeFactories[i]]) _gaugeFactories[i].newEpoch();

            unchecked {
                i++;
            }
        }
    }

    /// @inheritdoc IBaseV2GaugeManager
    function newEpoch(uint256 start, uint256 end) external {
        BaseV2GaugeFactory[] storage _gaugeFactories = gaugeFactories;

        uint256 length = _gaugeFactories.length;
        if (end > length) end = length;

        for (uint256 i = start; i < end;) {
            if (activeGaugeFactories[_gaugeFactories[i]]) _gaugeFactories[i].newEpoch();

            unchecked {
                i++;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                            GAUGE LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBaseV2GaugeManager
    function addGauge(address gauge) external onlyActiveGaugeFactory {
        bHermesGaugeWeight.addGauge(gauge);
        bHermesGaugeBoost.addGauge(gauge);
    }

    /// @inheritdoc IBaseV2GaugeManager
    function removeGauge(address gauge) external onlyActiveGaugeFactory {
        bHermesGaugeWeight.removeGauge(gauge);
        bHermesGaugeBoost.removeGauge(gauge);
    }

    /*//////////////////////////////////////////////////////////////
                            OWNER LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBaseV2GaugeManager
    function addGaugeFactory(BaseV2GaugeFactory gaugeFactory) external onlyOwner {
        if (activeGaugeFactories[gaugeFactory]) revert GaugeFactoryAlreadyExists();

        gaugeFactoryIds[gaugeFactory] = gaugeFactories.length;
        gaugeFactories.push(gaugeFactory);
        activeGaugeFactories[gaugeFactory] = true;

        emit AddedGaugeFactory(address(gaugeFactory));
    }

    /// @inheritdoc IBaseV2GaugeManager
    function removeGaugeFactory(BaseV2GaugeFactory gaugeFactory) external onlyOwner {
        if (!activeGaugeFactories[gaugeFactory] || gaugeFactories[gaugeFactoryIds[gaugeFactory]] != gaugeFactory) {
            revert NotActiveGaugeFactory();
        }
        delete gaugeFactories[gaugeFactoryIds[gaugeFactory]];
        delete gaugeFactoryIds[gaugeFactory];
        delete activeGaugeFactories[gaugeFactory];

        emit RemovedGaugeFactory(address(gaugeFactory));
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBaseV2GaugeManager
    function changebHermesGaugeOwner(address newOwner) external onlyAdmin {
        bHermesGaugeWeight.transferOwnership(newOwner);
        bHermesGaugeBoost.transferOwnership(newOwner);

        emit ChangedbHermesGaugeOwner(newOwner);
    }

    /// @inheritdoc IBaseV2GaugeManager
    function changeAdmin(address newAdmin) external onlyAdmin {
        admin = newAdmin;

        emit ChangedAdmin(newAdmin);
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyActiveGaugeFactory() {
        if (!activeGaugeFactories[BaseV2GaugeFactory(msg.sender)]) revert NotActiveGaugeFactory();
        _;
    }

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }
}
