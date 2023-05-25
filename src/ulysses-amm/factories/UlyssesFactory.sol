// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {UlyssesPool} from "../UlyssesPool.sol";
import {UlyssesToken} from "../UlyssesToken.sol";
import {IUlyssesFactory} from "../interfaces/IUlyssesFactory.sol";

/// @title Ulysses Pool Deployer
library UlyssesPoolDeployer {
    /**
     * @notice Deploys a new Ulysses pool.
     * @param id The id of the Ulysses pool.
     * @param asset The asset of the Ulysses pool.
     * @param name The name of the Ulysses pool.
     * @param symbol The symbol of the Ulysses pool.
     * @param owner The owner of the Ulysses pool.
     * @param factory The factory of the Ulysses pool.
     */
    function deployPool(
        uint256 id,
        address asset,
        string calldata name,
        string calldata symbol,
        address owner,
        address factory
    ) public returns (UlyssesPool) {
        return new UlyssesPool(id, asset, name, symbol, owner, factory);
    }
}

/// @title Factory of new Ulysses instances
contract UlyssesFactory is Ownable, IUlyssesFactory {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    error ParameterLengthError();

    error InvalidPoolId();

    error InvalidAsset();

    ///@notice next poolId
    uint256 public poolId = 1;

    ///@notice next tokenId
    uint256 public tokenId = 1;

    ///@notice Mapping that holds all the Ulysses pools
    mapping(uint256 => UlyssesPool) public pools;

    ///@notice Mapping that holds all the Ulysses tokens
    mapping(uint256 => UlyssesToken) public tokens;

    constructor(address _owner) {
        require(_owner != address(0), "Owner cannot be 0");
        _initializeOwner(_owner);
    }

    function renounceOwnership() public payable override onlyOwner {
        revert("Cannot renounce ownership");
    }

    /*//////////////////////////////////////////////////////////////
                           NEW LP LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IUlyssesFactory
    function createPool(ERC20 asset, address owner) external returns (uint256) {
        return _createPool(asset, owner);
    }

    /**
     * @notice Private function that holds the logic for creating a new Ulysses pool.
     * @param asset represents the asset that we want to create a Ulysses pool for.
     * @return _poolId id of the pool that was created.
     */
    function _createPool(ERC20 asset, address owner) private returns (uint256 _poolId) {
        if (address(asset) == address(0)) revert InvalidAsset();
        _poolId = ++poolId;
        pools[_poolId] =
            UlyssesPoolDeployer.deployPool(_poolId, address(asset), "Ulysses Pool", "ULP", owner, address(this));
    }

    /// @inheritdoc IUlyssesFactory
    function createPools(ERC20[] calldata assets, uint8[][] calldata weights, address owner)
        external
        returns (uint256[] memory poolIds)
    {
        uint256 length = assets.length;

        if (length != weights.length) revert ParameterLengthError();

        for (uint256 i = 0; i < length;) {
            poolIds[i] = _createPool(assets[i], address(this));

            unchecked {
                ++i;
            }
        }

        for (uint256 i = 0; i < length;) {
            if (length != weights[i].length) revert ParameterLengthError();

            for (uint256 j = 0; j < length;) {
                if (j != i && weights[i][j] > 0) pools[poolIds[i]].addNewBandwidth(poolIds[j], weights[i][j]);

                unchecked {
                    ++j;
                }
            }

            unchecked {
                ++i;
            }
        }

        for (uint256 i = 0; i < length;) {
            pools[poolIds[i]].transferOwnership(owner);

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                           NEW TOKEN LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IUlyssesFactory
    function createToken(uint256[] calldata poolIds, uint256[] calldata weights, address owner)
        external
        returns (uint256 _tokenId)
    {
        _tokenId = ++tokenId;

        uint256 length = poolIds.length;
        address[] memory destinations = new address[](length);
        for (uint256 i = 0; i < length;) {
            address destination = address(pools[poolIds[i]]);

            if (destination == address(0)) revert InvalidPoolId();

            destinations[i] = destination;

            unchecked {
                ++i;
            }
        }

        tokens[_tokenId] = new UlyssesToken(
            _tokenId,
            destinations,
            weights,
            "Ulysses Token",
            "ULT",
            owner
        );
    }
}
