// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {ERC20Gauges, IERC20Gauges} from "@ERC20/ERC20Gauges.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

contract MockERC20Gauges is ERC20Gauges {
    constructor(address _owner, uint32 _cycleLength, uint32 _freezeWindow)
        ERC20("Token", "TKN", 18)
        ERC20Gauges(_cycleLength, _freezeWindow)
    {
        _initializeOwner(_owner);
    }

    function mint(address to, uint256 value) public virtual {
        _mint(to, value);
    }

    function burn(address from, uint256 value) public virtual {
        _burn(from, value);
    }
}
