// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";

import { INonfungiblePositionManager } from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import { bHermesBoost } from "@hermes/tokens/bHermesBoost.sol";


import "../mocks/MockBoostAggregatorFactory.sol";

error Unauthorized();

contract BoostAggregatorFactoryTest is DSTestPlus {

    address uniswapV3Staker = address(0xCAFE);
    address mockERC20 = address(0xBCAA);
    address nonfungiblePositionManager = address(0xBEEF);
    address hermesGaugeBoost = address(0xBEEE);

    MockBoostAggregatorFactory factory;

    function mockHermes() public {
        hevm.mockCall(uniswapV3Staker,
                    abi.encodeWithSignature("hermes()"),
                    abi.encode(mockERC20)
                    );
    }

    function mockUniswapV3Staker() public {
        hevm.mockCall(uniswapV3Staker,
                    abi.encodeWithSignature("hermesGaugeBoost()"),
                    abi.encode(bHermesBoost(hermesGaugeBoost))
                    );
        hevm.mockCall(uniswapV3Staker,
                    abi.encodeWithSignature("nonfungiblePositionManager()"),
                    abi.encode(INonfungiblePositionManager(nonfungiblePositionManager))
                    );
    }

    function setUp() public {
        mockHermes();
        factory = new MockBoostAggregatorFactory(
            UniswapV3Staker(uniswapV3Staker)
        );
    }

    function testConstructor() public {
        assertEq(address(factory.uniswapV3Staker()), uniswapV3Staker);
        assertEq(address(factory.hermes()), mockERC20);
    }

    function testCreateBoostAggregator(address owner) public {
        mockUniswapV3Staker();
        hevm.assume(owner != address(0));

        assertEq(factory.getBoostAggregators().length, 1);

        factory.createBoostAggregator(owner);
        assertEq(factory.getBoostAggregators().length, 2);

        BoostAggregator aggregator = factory.boostAggregators(1);

        assertEq(aggregator.owner(), owner);
        assertEq(address(aggregator.uniswapV3Staker()), uniswapV3Staker);
        assertEq(address(aggregator.hermesGaugeBoost()), hermesGaugeBoost);
        assertEq(address(aggregator.nonfungiblePositionManager()), nonfungiblePositionManager);
        assertEq(address(aggregator.hermes()), mockERC20);
        
        assertEq(factory.boostAggregators(1).owner(), owner);
    }

    function testCreateBoostAggregatorSameOwner(address owner) public {
        mockUniswapV3Staker();
        hevm.assume(owner != address(0));

        assertEq(factory.getBoostAggregators().length, 1);

        factory.createBoostAggregator(owner);
        factory.createBoostAggregator(owner);

        assertEq(factory.getBoostAggregators().length, 3);
    }

    function testCreateBoostAggregatorIds(address owner, address owner2) public {
        mockUniswapV3Staker();
        hevm.assume(owner != address(0) && owner2 != address(0) && owner != owner2);

        assertEq(factory.getBoostAggregators().length, 1);

        factory.createBoostAggregator(owner);
        factory.createBoostAggregator(owner2);

        BoostAggregator aggregator = factory.boostAggregators(1);
        assertEq(factory.boostAggregatorIds(aggregator), 1);
        assertEq(aggregator.owner(), owner);
        BoostAggregator aggregator2 = factory.boostAggregators(2);
        assertEq(factory.boostAggregatorIds(aggregator2), 2);
        assertEq(aggregator2.owner(), owner2);
    }

    function testGetBoostAggregators(address owner, address owner2) public {
        mockUniswapV3Staker();
        hevm.assume(owner != address(0) && owner2 != address(0) && owner != owner2);

        assertEq(factory.getBoostAggregators().length, 1);

        factory.createBoostAggregator(owner);
        assertEq(factory.getBoostAggregators().length, 2);
        factory.createBoostAggregator(owner2);
        assertEq(factory.getBoostAggregators().length, 3);
    }

    function testCreateBoostAggregatorInvalidOwner() public {
        hevm.expectRevert(IBoostAggregatorFactory.InvalidOwner.selector);
        factory.createBoostAggregator(address(0));
    }
}