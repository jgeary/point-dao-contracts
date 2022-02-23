// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract Point is ERC20, ERC20Permit, ERC20Votes, Pausable, Ownable {
    address public minter;

    event MinterSet(address previous, address minter);

    constructor() ERC20("Point", "POINT") ERC20Permit("Point") {
        minter = _msgSender();
    }

    modifier onlyMinter() {
        require(minter != address(0));
        require(_msgSender() == minter);
        _;
    }

    function setMinter(address _minter) public onlyOwner {
        emit MinterSet(minter, _minter);
        minter = _minter;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address to, uint256 amount) external onlyMinter {
        bool wasPaused = paused();
        if (wasPaused) {
            _unpause();
        }
        _mint(to, amount);
        if (wasPaused) {
            _pause();
        }
    }

    function _maxSupply() internal view override returns (uint224) {
        return 284444444444444444444444;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
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
