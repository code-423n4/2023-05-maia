//SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.16;

//TEST
import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {stdError} from "forge-std/StdError.sol";
import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

//COMPONENTS
import {RootPort} from "@omni/RootPort.sol";
import {ArbitrumBranchPort} from "@omni/ArbitrumBranchPort.sol";

import {MockRootBridgeAgent, RootBridgeAgent, WETH9} from "./mocks/MockRootBridgeAgent.t.sol";
import {BranchBridgeAgent} from "./mocks/MockBranchBridgeAgent.t.sol";
import {ArbitrumBranchBridgeAgent} from "@omni/ArbitrumBranchBridgeAgent.sol";

import {BaseBranchRouter} from "@omni/BaseBranchRouter.sol";
import {MulticallRootRouter} from "@omni/MulticallRootRouter.sol";
import {CoreRootRouter} from "@omni/CoreRootRouter.sol";
import {ArbitrumCoreBranchRouter} from "@omni/ArbitrumCoreBranchRouter.sol";

import {ERC20hTokenRoot} from "@omni/token/ERC20hTokenRoot.sol";
import {ERC20hTokenRootFactory} from "@omni/factories/ERC20hTokenRootFactory.sol";
import {ERC20hTokenBranchFactory} from "@omni/factories/ERC20hTokenBranchFactory.sol";
import {RootBridgeAgentFactory} from "@omni/factories/RootBridgeAgentFactory.sol";
import {BranchBridgeAgentFactory} from "@omni/factories/BranchBridgeAgentFactory.sol";
import {ArbitrumBranchBridgeAgentFactory} from "@omni/factories/ArbitrumBranchBridgeAgentFactory.sol";

//UTILS
import {DepositParams, DepositMultipleParams} from "./mocks/MockRootBridgeAgent.t.sol";
import {Deposit, DepositStatus, DepositMultipleInput, DepositInput} from "@omni/interfaces/IBranchBridgeAgent.sol";

import {WETH9 as WETH} from "./mocks/WETH9.sol";
import {Multicall2} from "./mocks/Multicall2.sol";
contract RootBridgeAgentDecodeTest is DSTestPlus {
    MockRootBridgeAgent mockRootBridgeAgent;

    MockERC20 wAvaxUnderlyingNativeToken;

    MockERC20 rewardToken;

    MockERC20 testToken;

    function setUp() public {
        rewardToken = new MockERC20("hermes token", "HERMES", 18);
        testToken = new MockERC20("A", "AAA", 18);

        mockRootBridgeAgent = new MockRootBridgeAgent(
            WETH9(address(1)),
        0,
        address(1),
        address(1),
        address(1),
        address(1),
        address(1));
    }

    function testFuzzReadDepositData(
        uint32 _nonce,
        uint256 _amount0,
        uint256 _amount1,
        uint256 _deposit0,
        uint256 _deposit1
    ) public {
        // Input restrictions
        hevm.assume(_nonce > 0 && _amount0 > 0 && _deposit0 <= _amount0 && _amount1 > 0 && _deposit1 <= _amount1);

        address[] memory _hTokens = new address[](2);
        address[] memory _tokens = new address[](2);
        uint256[] memory _amounts = new uint256[](2);
        uint256[] memory _deposits = new uint256[](2);

        _hTokens[0] = address(0xF0F0);
        _hTokens[1] = address(0xF1F1);
        _tokens[0] = address(0xF2F2);
        _tokens[1] = address(0xF3F3);
        _amounts[0] = 100 ether;
        _amounts[1] = 250 ether;
        _deposits[0] = 0 ether;
        _deposits[1] = 50 ether;

        bytes memory data = abi.encodePacked(uint8(2), _nonce, _hTokens, _tokens, _amounts, _deposits, uint24(4));

        DepositMultipleParams memory expected = DepositMultipleParams({
            numberOfAssets: uint8(2),
            depositNonce: _nonce,
            hTokens: _hTokens,
            tokens: _tokens,
            amounts: _amounts,
            deposits: _deposits,
            toChain: uint24(4)
        });

        DepositMultipleParams memory actual = mockRootBridgeAgent.bridgeInMultiple(address(this), data, uint24(4));

        console2.log("actual.numberOfAssets");
        require(actual.numberOfAssets == expected.numberOfAssets);
        console2.log("actual.depositNonce");
        require(actual.depositNonce == expected.depositNonce);
        console2.log("actual.hTokens");
        require((actual.hTokens[0]) == (expected.hTokens[0]));
        console2.log("actual.tokens");
        require((actual.tokens[0] == expected.tokens[0]));
        console2.log("actual.amounts");
        require(((actual.amounts[0]) == (expected.amounts[0])));
        console2.log("actual.deposits");
        require(((actual.deposits[0]) == (expected.deposits[0])));
        console2.log("actual.hTokens");
        require((actual.hTokens[1]) == (expected.hTokens[1]));
        console2.log("actual.tokens");
        require((actual.tokens[1] == expected.tokens[1]));
        console2.log("actual.amounts");
        require(((actual.amounts[1]) == (expected.amounts[1])));
        console2.log("actual.deposits");
        require(((actual.deposits[1]) == (expected.deposits[1])));
        console2.log("actual.toChain");
        require(actual.toChain == expected.toChain);
    }

    function compareDynamicArrays(bytes memory a, bytes memory b) public pure returns (bool aEqualsB) {
        assembly {
            aEqualsB := eq(a, b)
        }
    }
}
