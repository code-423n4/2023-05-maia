// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {IERC20hTokenRoot} from "../interfaces/IERC20hTokenRoot.sol";

/// @title ERC20 hToken Contract
contract ERC20hTokenRoot is ERC20, IERC20hTokenRoot {
    using SafeTransferLib for address;

    /// @inheritdoc IERC20hTokenRoot
    uint256 public localChainId;

    /// @inheritdoc IERC20hTokenRoot
    address public rootPortAddress;

    /// @inheritdoc IERC20hTokenRoot
    address public localBranchPortAddress;

    /// @inheritdoc IERC20hTokenRoot
    address public factoryAddress;

    /// @inheritdoc IERC20hTokenRoot
    mapping(uint256 => uint256) public getTokenBalance;

    /**
     * @notice Constructor for the ERC20hTokenRoot Contract.
     *     @param _localChainId Local Network Identifier.
     *     @param _factoryAddress Address of the Factory Contract.
     *     @param _rootPortAddress Address of the Root Port Contract.
     *     @param _name Name of the Token.
     *     @param _symbol Symbol of the Token.
     */
    constructor(
        uint256 _localChainId,
        address _factoryAddress,
        address _rootPortAddress,
        string memory _name,
        string memory _symbol
    ) ERC20(string(string.concat("Hermes ", _name)), string(string.concat("h-", _symbol)), 18) {
        require(_rootPortAddress != address(0), "Root Port Address cannot be 0");
        require(_factoryAddress != address(0), "Factory Address cannot be 0");
        localChainId = _localChainId;
        factoryAddress = _factoryAddress;
        rootPortAddress = _rootPortAddress;
    }

    /*///////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Modifier that verifies msg sender is the RootInterface Contract from Root Chain.
    modifier requiresPort() {
        if (msg.sender != rootPortAddress) revert UnrecognizedPort();
        _;
    }

    /*///////////////////////////////////////////////////////////////
                        ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mints new tokens and updates the total supply for the given chain.
     * @param to Address to mint tokens to.
     * @param amount Amount of tokens to mint.
     * @param chainId Chain Id of the chain to mint tokens to.
     */
    function mint(address to, uint256 amount, uint256 chainId) external requiresPort returns (bool) {
        getTokenBalance[chainId] += amount;
        _mint(to, amount);
        return true;
    }

    /**
     * @notice Burns new tokens and updates the total supply for the given chain.
     * @param from Address to burn tokens from.
     * @param value Amount of tokens to burn.
     * @param chainId Chain Id of the chain to burn tokens to.
     */
    function burn(address from, uint256 value, uint256 chainId) external requiresPort {
        getTokenBalance[chainId] -= value;
        _burn(from, value);
    }
}
