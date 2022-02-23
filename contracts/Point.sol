// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "./GalaxyAsks.sol";
import "./GalaxyLocker.sol";

contract Point is ERC20, ERC20Permit, ERC20Votes, Pausable, Ownable {
    uint256 constant MAX_SUPPLY = 284444444444444444444444;
    uint256 constant GOV_SUPPLY = 28444444444444444444444;

    GalaxyAsks public galaxyAsks;
    GalaxyLocker public galaxyLocker;
    bool public mintTreasuryAndDesignateRolesCalled;

    constructor() ERC20("Point", "POINT") ERC20Permit("Point") {}

    modifier onlyMinter() {
        require(_msgSender() == address(galaxyAsks));
        _;
    }

    modifier onlyBurner() {
        require(_msgSender() == address(galaxyLocker));
        _;
    }

    function mintTreasuryAndDesignateRoles(
        address _treasury,
        GalaxyAsks _galaxyAsks,
        GalaxyLocker _galaxyLocker
    ) external onlyOwner {
        require(
            !mintTreasuryAndDesignateRolesCalled,
            "mintTreasuryAndDesignateRoles can only be called one time"
        );
        mintTreasuryAndDesignateRolesCalled = true;
        _doMint(_treasury, GOV_SUPPLY);
        galaxyAsks = _galaxyAsks;
        galaxyLocker = _galaxyLocker;
    }

    function mint(address to, uint256 amount) external onlyMinter {
        _doMint(to, amount);
    }

    function _doMint(address to, uint256 amount) private {
        bool wasPaused = paused();
        if (wasPaused) {
            _unpause();
        }
        _mint(to, amount);
        if (wasPaused) {
            _pause();
        }
    }

    function burn(address account, uint256 amount) external onlyBurner {
        bool wasPaused = paused();
        if (wasPaused) {
            _unpause();
        }
        _burn(account, amount);
        if (wasPaused) {
            _pause();
        }
    }

    function _maxSupply() internal view override returns (uint224) {
        return uint224(MAX_SUPPLY);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
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
