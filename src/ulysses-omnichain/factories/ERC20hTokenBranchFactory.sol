// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";

import {ERC20} from "../token/ERC20hTokenBranch.sol";

import {IERC20hTokenBranchFactory, ERC20hTokenBranch} from "../interfaces/IERC20hTokenBranchFactory.sol";

/// @title ERC20hTokenBranch Factory Contract
contract ERC20hTokenBranchFactory is Ownable, IERC20hTokenBranchFactory {
    /// @notice Local Network Identifier.
    uint24 public immutable localChainId;

    /// @notice Local Port Address
    address immutable localPortAddress;

    /// @notice Local Branch Core Router Address responsible for the addition of new tokens to the system.
    address localCoreRouterAddress;

    /// @notice Local hTokens deployed in current chain.
    ERC20hTokenBranch[] public hTokens;

    /// @notice Number of hTokens deployed in current chain.
    uint256 public hTokensLenght;

    constructor(uint24 _localChainId, address _localPortAddress) {
        require(_localPortAddress != address(0), "Port address cannot be 0");

        localChainId = _localChainId;
        localPortAddress = _localPortAddress;
        _initializeOwner(msg.sender);
    }

    function initialize(address _wrappedNativeTokenAddress, address _coreRouter) external onlyOwner {
        require(_coreRouter != address(0), "CoreRouter address cannot be 0");

        ERC20hTokenBranch newToken = new ERC20hTokenBranch(
            ERC20(_wrappedNativeTokenAddress).name(),
            ERC20(_wrappedNativeTokenAddress).symbol(),
            localPortAddress
        );

        hTokens.push(newToken);
        hTokensLenght++;

        localCoreRouterAddress = _coreRouter;

        renounceOwnership();
    }

    /*///////////////////////////////////////////////////////////////
                            hTOKEN FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Function to create a new hToken.
     * @param _name Name of the Token.
     * @param _symbol Symbol of the Token.
     */
    function createToken(string memory _name, string memory _symbol)
        external
        requiresCoreRouter
        returns (ERC20hTokenBranch newToken)
    {
        newToken = new ERC20hTokenBranch(_name, _symbol, localPortAddress);
        hTokens.push(newToken);
        hTokensLenght++;
    }

    /*///////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Modifier that verifies msg sender is the RootInterface Contract from Root Chain.
    modifier requiresCoreRouter() {
        if (msg.sender != localCoreRouterAddress) revert UnrecognizedCoreRouter();
        _;
    }

    /// @notice Modifier that verifies msg sender is the Branch Port Contract from Local Chain.
    modifier requiresPort() {
        if (msg.sender != localPortAddress) revert UnrecognizedPort();
        _;
    }
}
