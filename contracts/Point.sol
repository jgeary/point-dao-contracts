// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract Point is ERC20, ERC20Permit, ERC20Votes, Ownable {
    constructor() ERC20("Point", "POINT") ERC20Permit("Point") {
        _mint(address(this), 281600 * 10**decimals());
    }

    function distributeTokens(address galaxyAsks, address treasury)
        public
        onlyOwner
    {
        _transfer(address(this), galaxyAsks, 256000 * 10**decimals());
        _transfer(address(this), treasury, 25600 * 10**decimals());
        renounceOwnership();
    }

    // The following functions are overrides required by Solidity.

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }
}
