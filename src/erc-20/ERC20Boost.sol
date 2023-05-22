// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {EnumerableSet} from "@lib/EnumerableSet.sol";

import {IBaseV2Gauge} from "@gauges/interfaces/IBaseV2Gauge.sol";

import {Errors} from "./interfaces/Errors.sol";
import {IERC20Boost} from "./interfaces/IERC20Boost.sol";

/// @title An ERC20 with an embedded attachment mechanism to keep track of boost
///        allocations to gauges.
abstract contract ERC20Boost is ERC20, Ownable, IERC20Boost {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeCastLib for *;

    /*///////////////////////////////////////////////////////////////
                            GAUGE STATE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC20Boost
    mapping(address => mapping(address => GaugeState)) public override getUserGaugeBoost;

    /// @inheritdoc IERC20Boost
    mapping(address => uint256) public override getUserBoost;

    mapping(address => EnumerableSet.AddressSet) internal _userGauges;

    EnumerableSet.AddressSet internal _gauges;

    // Store deprecated gauges in case a user needs to free dead boost
    EnumerableSet.AddressSet internal _deprecatedGauges;

    /*///////////////////////////////////////////////////////////////
                            VIEW HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC20Boost
    function gauges() external view returns (address[] memory) {
        return _gauges.values();
    }

    /// @inheritdoc IERC20Boost
    function gauges(uint256 offset, uint256 num) external view returns (address[] memory values) {
        values = new address[](num);
        for (uint256 i = 0; i < num;) {
            unchecked {
                values[i] = _gauges.at(offset + i); // will revert if out of bounds
                i++;
            }
        }
    }

    /// @inheritdoc IERC20Boost
    function isGauge(address gauge) external view returns (bool) {
        return _gauges.contains(gauge) && !_deprecatedGauges.contains(gauge);
    }

    /// @inheritdoc IERC20Boost
    function numGauges() external view returns (uint256) {
        return _gauges.length();
    }

    /// @inheritdoc IERC20Boost
    function deprecatedGauges() external view returns (address[] memory) {
        return _deprecatedGauges.values();
    }

    /// @inheritdoc IERC20Boost
    function numDeprecatedGauges() external view returns (uint256) {
        return _deprecatedGauges.length();
    }

    /// @inheritdoc IERC20Boost
    function freeGaugeBoost(address user) public view returns (uint256) {
        return balanceOf[user] - getUserBoost[user];
    }

    /// @inheritdoc IERC20Boost
    function userGauges(address user) external view returns (address[] memory) {
        return _userGauges[user].values();
    }

    /// @inheritdoc IERC20Boost
    function isUserGauge(address user, address gauge) external view returns (bool) {
        return _userGauges[user].contains(gauge);
    }

    /// @inheritdoc IERC20Boost
    function userGauges(address user, uint256 offset, uint256 num) external view returns (address[] memory values) {
        values = new address[](num);
        for (uint256 i = 0; i < num;) {
            unchecked {
                values[i] = _userGauges[user].at(offset + i); // will revert if out of bounds
                i++;
            }
        }
    }

    /// @inheritdoc IERC20Boost
    function numUserGauges(address user) external view returns (uint256) {
        return _userGauges[user].length();
    }

    /*///////////////////////////////////////////////////////////////
                        GAUGE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC20Boost
    function attach(address user) external {
        if (!_gauges.contains(msg.sender) || _deprecatedGauges.contains(msg.sender)) {
            revert InvalidGauge();
        }

        // idempotent add
        if (!_userGauges[user].add(msg.sender)) revert GaugeAlreadyAttached();

        uint128 userGaugeBoost = balanceOf[user].toUint128();

        if (getUserBoost[user] < userGaugeBoost) {
            getUserBoost[user] = userGaugeBoost;
            emit UpdateUserBoost(user, userGaugeBoost);
        }

        getUserGaugeBoost[user][msg.sender] =
            GaugeState({userGaugeBoost: userGaugeBoost, totalGaugeBoost: totalSupply.toUint128()});

        emit Attach(user, msg.sender, userGaugeBoost);
    }

    /// @inheritdoc IERC20Boost
    function detach(address user) external {
        require(_userGauges[user].remove(msg.sender));
        delete getUserGaugeBoost[user][msg.sender];

        emit Detach(user, msg.sender);
    }

    /*///////////////////////////////////////////////////////////////
                        USER GAUGE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC20Boost
    function updateUserBoost(address user) external {
        uint256 userBoost = 0;

        address[] memory gaugeList = _userGauges[user].values();

        uint256 length = gaugeList.length;
        for (uint256 i = 0; i < length;) {
            address gauge = gaugeList[i];

            if (!_deprecatedGauges.contains(gauge)) {
                uint256 gaugeBoost = getUserGaugeBoost[user][gauge].userGaugeBoost;

                if (userBoost < gaugeBoost) userBoost = gaugeBoost;
            }

            unchecked {
                i++;
            }
        }
        getUserBoost[user] = userBoost;

        emit UpdateUserBoost(user, userBoost);
    }

    /// @inheritdoc IERC20Boost
    function decrementGaugeBoost(address gauge, uint256 boost) public {
        GaugeState storage gaugeState = getUserGaugeBoost[msg.sender][gauge];
        if (boost >= gaugeState.userGaugeBoost) {
            _userGauges[msg.sender].remove(gauge);
            delete getUserGaugeBoost[msg.sender][gauge];

            emit Detach(msg.sender, gauge);
        } else {
            gaugeState.userGaugeBoost -= boost.toUint128();

            emit DecrementUserGaugeBoost(msg.sender, gauge, gaugeState.userGaugeBoost);
        }
    }

    /// @inheritdoc IERC20Boost
    function decrementGaugeAllBoost(address gauge) external {
        require(_userGauges[msg.sender].remove(gauge));
        delete getUserGaugeBoost[msg.sender][gauge];

        emit Detach(msg.sender, gauge);
    }

    /// @inheritdoc IERC20Boost
    function decrementAllGaugesBoost(uint256 boost) external {
        decrementGaugesBoostIndexed(boost, 0, _userGauges[msg.sender].length());
    }

    /// @inheritdoc IERC20Boost
    function decrementGaugesBoostIndexed(uint256 boost, uint256 offset, uint256 num) public {
        address[] memory gaugeList = _userGauges[msg.sender].values();

        uint256 length = gaugeList.length;
        for (uint256 i = 0; i < num && i < length;) {
            address gauge = gaugeList[offset + i];

            GaugeState storage gaugeState = getUserGaugeBoost[msg.sender][gauge];

            if (_deprecatedGauges.contains(gauge) || boost >= gaugeState.userGaugeBoost) {
                require(_userGauges[msg.sender].remove(gauge)); // Remove from set. Should never fail.
                delete getUserGaugeBoost[msg.sender][gauge];

                emit Detach(msg.sender, gauge);
            } else {
                gaugeState.userGaugeBoost -= boost.toUint128();

                emit DecrementUserGaugeBoost(msg.sender, gauge, gaugeState.userGaugeBoost);
            }

            unchecked {
                i++;
            }
        }
    }

    /// @inheritdoc IERC20Boost
    function decrementAllGaugesAllBoost() external {
        // Loop through all user gauges, live and deprecated
        address[] memory gaugeList = _userGauges[msg.sender].values();

        // Free gauges until through the entire list
        uint256 size = gaugeList.length;
        for (uint256 i = 0; i < size;) {
            address gauge = gaugeList[i];

            require(_userGauges[msg.sender].remove(gauge)); // Remove from set. Should never fail.
            delete getUserGaugeBoost[msg.sender][gauge];

            emit Detach(msg.sender, gauge);

            unchecked {
                i++;
            }
        }

        getUserBoost[msg.sender] = 0;

        emit UpdateUserBoost(msg.sender, 0);
    }

    /*///////////////////////////////////////////////////////////////
                        ADMIN GAUGE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC20Boost
    function addGauge(address gauge) external onlyOwner {
        _addGauge(gauge);
    }

    function _addGauge(address gauge) internal {
        bool newAdd = _gauges.add(gauge);
        bool previouslyDeprecated = _deprecatedGauges.remove(gauge);
        // add and fail loud if zero address or already present and not deprecated
        if (gauge == address(0) || !(newAdd || previouslyDeprecated)) revert InvalidGauge();

        emit AddGauge(gauge);
    }

    /// @inheritdoc IERC20Boost
    function removeGauge(address gauge) external onlyOwner {
        _removeGauge(gauge);
    }

    function _removeGauge(address gauge) internal {
        // add to deprecated and fail loud if not present
        if (!_deprecatedGauges.add(gauge)) revert InvalidGauge();

        emit RemoveGauge(gauge);
    }

    /// @inheritdoc IERC20Boost
    function replaceGauge(address oldGauge, address newGauge) external onlyOwner {
        _removeGauge(oldGauge);
        _addGauge(newGauge);
    }

    /*///////////////////////////////////////////////////////////////
                             ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    /// NOTE: any "removal" of tokens from a user requires notAttached < amount.

    /**
     * @notice Burns `amount` of tokens from `from` address.
     * @dev User must have enough free boost.
     * @param from The address to burn tokens from.
     * @param amount The amount of tokens to burn.
     */
    function _burn(address from, uint256 amount) internal override notAttached(from, amount) {
        super._burn(from, amount);
    }

    /**
     * @notice Transfers `amount` of tokens from `msg.sender` to `to` address.
     * @dev User must have enough free boost.
     * @param to the address to transfer to.
     * @param amount the amount to transfer.
     */
    function transfer(address to, uint256 amount) public override notAttached(msg.sender, amount) returns (bool) {
        return super.transfer(to, amount);
    }

    /**
     * @notice Transfers `amount` of tokens from `from` address to `to` address.
     * @dev User must have enough free boost.
     * @param from the address to transfer from.
     * @param to the address to transfer to.
     * @param amount the amount to transfer.
     */
    function transferFrom(address from, address to, uint256 amount)
        public
        override
        notAttached(from, amount)
        returns (bool)
    {
        return super.transferFrom(from, to, amount);
    }

    /*///////////////////////////////////////////////////////////////
                             MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Reverts if the user does not have enough free boost.
     * @param user The user address.
     * @param amount The amount of boost.
     */
    modifier notAttached(address user, uint256 amount) {
        if (freeGaugeBoost(user) < amount) revert AttachedBoost();
        _;
    }
}
