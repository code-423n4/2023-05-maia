///SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BranchBridgeAgent, Deposit, DepositParams, DepositMultipleParams} from "@omni/BranchBridgeAgent.sol";
import {IBranchRouter} from "@omni/interfaces/IBranchRouter.sol";
import {IBranchPort as IPort} from "@omni/interfaces/IBranchPort.sol";
import {ERC20hTokenBranch as ERC20hToken} from "@omni/token/ERC20hTokenBranch.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

import {WETH9} from "@omni/interfaces/IWETH9.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {Ownable} from "solady/auth/Ownable.sol";

import {console2} from "forge-std/console2.sol";

contract MockBranchBridgeAgent is BranchBridgeAgent {
    constructor(
        WETH9 _wrappedNativeToken,
        uint256 _rootChainId,
        uint256 _localChainId,
        address _rootBridgeAgentAddress,
        address _localAnyCallAddress,
        address _localAnyCallExecutorAddress,
        address _localRouterAddress,
        address _localPortAddress
    )
        BranchBridgeAgent(
            _wrappedNativeToken,
            _rootChainId,
            _localChainId,
            _rootBridgeAgentAddress,
            _localAnyCallAddress,
            _localAnyCallExecutorAddress,
            _localRouterAddress,
            _localPortAddress
        )
    {}
}
