// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {ERC20Boost, ERC20, Ownable, IERC20Boost} from "@ERC20/ERC20Boost.sol";

contract MockERC20Boost is ERC20Boost {
    constructor() ERC20("Token", "TKN", 18) {
        _initializeOwner(msg.sender);
    }

    function mint(address to, uint256 value) public virtual {
        _mint(to, value);
    }

    function burn(address from, uint256 value) public virtual {
        _burn(from, value);
    }
}
