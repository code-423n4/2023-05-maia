// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {UlyssesToken} from "@ulysses-amm/UlyssesToken.sol";

import {UlyssesTokenHandler} from "@test/test-utils/invariant/handlers/UlyssesTokenHandler.t.sol";

contract InvariantUlyssesToken is UlyssesTokenHandler {
    function setUp() public override {
        for (uint256 i = 0; i < NUM_ASSETS; i++) {
            _underlyings_.push(address(new MockERC20("Mock ERC20", "MERC20", 18)));
        }

        address[] memory assets = new address[](NUM_ASSETS);
        for (uint256 i = 0; i < NUM_ASSETS; i++) {
            assets[i] = _underlyings_[i];
        }

        uint8[10] memory exampleWeights = [10, 10, 20, 5, 13, 21, 64, 17, 15, 50];

        uint256[] memory weights = new uint256[](NUM_ASSETS);
        for (uint256 i = 0; i < NUM_ASSETS; i++) {
            weights[i] = exampleWeights[i];
        }

        _vault_ = address(new UlyssesToken(1, assets, weights, "Mock ERC4626", "MERC4626", address(this)));
        _delta_ = 1;
        _vaultMayBeEmpty = true;
        _unlimitedAmount = false;
    }
}
