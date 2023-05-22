// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {WETH9} from "../interfaces/IWETH9.sol";

import {IAnycallProxy} from "./IAnycallProxy.sol";

import {IRootBridgeAgent} from "../interfaces/IRootBridgeAgent.sol";

/**
 * @title  `RootBridgeAgentFactory`
 * @author MaiaDAO
 * @notice This contract is used to deploy new Root Bridge Agents responsible
 *         for deploying new Bridge Agents which are in charge of managing the
 *         deposit and withdrawal of assets between the branch chains and the
 *         omnichain environment.
 */
interface IRootBridgeAgentFactory {
    /*///////////////////////////////////////////////////////////////
                        BRIDGE AGENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function createBridgeAgent(address newRootRouterAddress) external returns (address newBridgeAgent);
}
