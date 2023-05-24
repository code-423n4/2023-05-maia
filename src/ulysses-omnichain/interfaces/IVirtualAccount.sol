// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

/// @notice Interface for the `Multicall2` contract.
struct Call {
    address target;
    bytes callData;
}

/**
 * @title  Virtual Account Contract
 * @notice A Virtual Account allows users to manage assets and perform interactions remotely while allowing dApps to keep encapsulated user balance for accounting purposes.
 * @dev    This contract is based off Maker's `Multicall2` contract, executes a set of `Call` objects if any of the perfomed call is invalid the whole batch should revert.
 */
interface IVirtualAccount is IERC721Receiver {
    /**
     * @notice Returns the address of the user that owns the VirtualAccount.
     * @return The address of the user that owns the VirtualAccount.
     */
    function userAddress() external view returns (address);

    /**
     * @notice Returns the address of the local port.
     * @return The address of the local port.
     */
    function localPortAddress() external view returns (address);

    /**
     * @notice Withdraws ERC20 tokens from the VirtualAccount.
     * @param _token The address of the ERC20 token to withdraw.
     * @param _amount The amount of tokens to withdraw.
     */
    function withdrawERC20(address _token, uint256 _amount) external;

    /**
     * @notice Withdraws ERC721 tokens from the VirtualAccount.
     * @param _token The address of the ERC721 token to withdraw.
     * @param _tokenId The id of the token to withdraw.
     */
    function withdrawERC721(address _token, uint256 _tokenId) external;

    /**
     * @notice
     * @param callInput The call to make.
     */
    function call(Call[] calldata callInput) external returns (uint256 blockNumber, bytes[] memory);

    /*///////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error CallFailed();

    error UnauthorizedCaller();
}
