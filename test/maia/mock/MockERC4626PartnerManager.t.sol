// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {ERC4626PartnerManager, PartnerManagerFactory, ERC20} from "@maia/tokens/ERC4626PartnerManager.sol";

contract MockERC4626PartnerManager is ERC4626PartnerManager {
    constructor(
        PartnerManagerFactory _factory,
        uint256 _bHermesRate,
        ERC20 _partnerAsset,
        string memory _name,
        string memory _symbol,
        address _bhermes,
        address _partnerVault,
        address _owner
    ) ERC4626PartnerManager(_factory, _bHermesRate, _partnerAsset, _name, _symbol, _bhermes, _partnerVault, _owner) {}
}
