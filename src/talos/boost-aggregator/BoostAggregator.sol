// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

import {bHermesBoost} from "@hermes/tokens/bHermesBoost.sol";
import {UniswapV3Staker} from "@v3-staker/UniswapV3Staker.sol";

import {IBoostAggregator} from "../interfaces/IBoostAggregator.sol";

/// @title Boost Aggregator for Uniswap V3 NFTs
contract BoostAggregator is Ownable, IBoostAggregator {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                        BOOST AGGREGATOR STATE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBoostAggregator
    INonfungiblePositionManager public immutable nonfungiblePositionManager;

    /// @inheritdoc IBoostAggregator
    UniswapV3Staker public immutable uniswapV3Staker;

    /// @inheritdoc IBoostAggregator
    bHermesBoost public immutable hermesGaugeBoost;

    /// @inheritdoc IBoostAggregator
    ERC20 public immutable hermes;

    /// @inheritdoc IBoostAggregator
    mapping(address => address) public userToRewardsDepot;

    /// @inheritdoc IBoostAggregator
    mapping(uint256 => address) public tokenIdToUser;

    /// @inheritdoc IBoostAggregator
    mapping(uint256 => uint256) public tokenIdRewards;

    /// @inheritdoc IBoostAggregator
    mapping(address => bool) public whitelistedAddresses;

    /// @inheritdoc IBoostAggregator
    uint256 public protocolRewards;

    /// @inheritdoc IBoostAggregator
    uint256 public protocolFee = 2000; // 20%
    // divisioner for protocol fee
    uint256 private constant DIVISIONER = 10000;

    /**
     * @notice Creates a new BoostAggregator
     * @param _uniswapV3Staker The UniswapV3Staker contract
     * @param _hermes The hermes token contract
     * @param _owner The owner of this contract
     */
    constructor(UniswapV3Staker _uniswapV3Staker, ERC20 _hermes, address _owner) {
        _initializeOwner(_owner);
        uniswapV3Staker = _uniswapV3Staker;
        hermesGaugeBoost = uniswapV3Staker.hermesGaugeBoost();
        nonfungiblePositionManager = uniswapV3Staker.nonfungiblePositionManager();
        hermes = _hermes;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL HOOKS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC721Receiver
    /// @dev msg.sender not validated to be nonfungiblePositionManager in order to allow
    ///      whitelisted addresses to retrieve NFTs incorrectly sent to this contract
    function onERC721Received(address, address from, uint256 tokenId, bytes calldata)
        external
        override
        onlyWhitelisted(from)
        returns (bytes4)
    {
        // update tokenIdRewards prior to staking
        tokenIdRewards[tokenId] = uniswapV3Staker.tokenIdRewards(tokenId);
        // map tokenId to user
        tokenIdToUser[tokenId] = from;
        // stake NFT to Uniswap V3 Staker
        nonfungiblePositionManager.safeTransferFrom(address(this), address(uniswapV3Staker), tokenId);

        return this.onERC721Received.selector;
    }

    /*//////////////////////////////////////////////////////////////
                        REWARD DEPOTS LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBoostAggregator
    function setOwnRewardsDepot(address rewardsDepot) external {
        userToRewardsDepot[msg.sender] = rewardsDepot;
    }

    /*//////////////////////////////////////////////////////////////
                            UNSTAKE LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBoostAggregator
    function unstakeAndWithdraw(uint256 tokenId) external {
        address user = tokenIdToUser[tokenId];
        if (user != msg.sender) revert NotTokenIdOwner();

        // unstake NFT from Uniswap V3 Staker
        uniswapV3Staker.unstakeToken(tokenId);

        uint256 pendingRewards = uniswapV3Staker.tokenIdRewards(tokenId) - tokenIdRewards[tokenId];

        if (pendingRewards > DIVISIONER) {
            uint256 newProtocolRewards = (pendingRewards * protocolFee) / DIVISIONER;
            /// @dev protocol rewards stay in stake contract
            protocolRewards += newProtocolRewards;
            pendingRewards -= newProtocolRewards;

            address rewardsDepot = userToRewardsDepot[user];
            if (rewardsDepot != address(0)) {
                // claim rewards to user's rewardsDepot
                uniswapV3Staker.claimReward(rewardsDepot, pendingRewards);
            } else {
                // claim rewards to user
                uniswapV3Staker.claimReward(user, pendingRewards);
            }
        }

        // withdraw rewards from Uniswap V3 Staker
        uniswapV3Staker.withdrawToken(tokenId, user, "");
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBoostAggregator
    function addWhitelistedAddress(address user) external onlyOwner {
        whitelistedAddresses[user] = true;
    }

    /// @inheritdoc IBoostAggregator
    function removeWhitelistedAddress(address user) external onlyOwner {
        delete whitelistedAddresses[user];
    }

    /// @inheritdoc IBoostAggregator
    function setProtocolFee(uint256 _protocolFee) external onlyOwner {
        if (_protocolFee > DIVISIONER) revert FeeTooHigh();
        protocolFee = _protocolFee;
    }

    /// @inheritdoc IBoostAggregator
    function withdrawProtocolFees(address to) external onlyOwner {
        uniswapV3Staker.claimReward(to, protocolRewards);
        delete protocolRewards;
    }

    /// @inheritdoc IBoostAggregator
    function withdrawAllGaugeBoost(address to) external onlyOwner {
        /// @dev May run out of gas.
        hermesGaugeBoost.decrementAllGaugesAllBoost();
        address(hermesGaugeBoost).safeTransfer(to, hermesGaugeBoost.balanceOf(address(this)));
    }

    /// @inheritdoc IBoostAggregator
    function withdrawGaugeBoost(address to, uint256 amount) external onlyOwner {
        /// @dev May run out of gas.
        hermesGaugeBoost.decrementAllGaugesBoost(amount);
        hermesGaugeBoost.updateUserBoost(address(this));
        address(hermesGaugeBoost).safeTransfer(to, amount);
    }

    /// @inheritdoc IBoostAggregator
    function decrementGaugesBoostIndexed(uint256 boost, uint256 offset, uint256 num) external onlyOwner {
        hermesGaugeBoost.decrementGaugesBoostIndexed(boost, offset, num);
    }

    /*///////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Only whitelisted addresses
    /// @param from The address who the NFT is being transferred from
    modifier onlyWhitelisted(address from) {
        if (!whitelistedAddresses[from]) revert Unauthorized();
        _;
    }
}
