// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./urbit/Azimuth.sol";
import "./GalaxyLocker.sol";
import "./GalaxyAsks.sol";
import "./Point.sol";
import "./PointGovernor.sol";
import "./PointTreasury.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/* Deploys entire protocol atomically */
contract Deployer is Ownable {
    GalaxyLocker public galaxyLocker;
    GalaxyAsks public galaxyAsks;
    Point public pointToken;
    PointGovernor public pointGovernor;
    PointTreasury public pointTreasury;
    Azimuth internal azimuth;
    address internal ecliptic;
    address internal multisig;
    address internal weth;
    bool deployed;

    constructor(
        Azimuth _azimuth,
        address _multisig,
        address _weth
    ) {
        azimuth = _azimuth;
        ecliptic = azimuth.owner();
        multisig = _multisig;
        weth = _weth;
    }

    function deploy() public onlyOwner {
        require(!deployed);
        deployed = true;

        // token
        pointToken = new Point();

        // governance
        address[] memory proposers = new address[](1);
        proposers[0] = multisig;
        address[] memory executors = new address[](1);
        executors[0] = multisig;
        pointTreasury = new PointTreasury(86400, proposers, executors, weth);
        pointGovernor = new PointGovernor(pointToken, pointTreasury);

        // galaxy managers
        galaxyLocker = new GalaxyLocker(
            pointToken,
            azimuth,
            address(pointTreasury)
        );
        galaxyAsks = new GalaxyAsks(
            azimuth,
            multisig,
            pointToken,
            galaxyLocker,
            payable(address(pointTreasury))
        );

        // distribute 10% max supply to treasury, renounce ownership
        pointToken.mintTreasuryAndDesignateRoles(
            address(pointTreasury),
            galaxyAsks,
            galaxyLocker
        );
        pointToken.renounceOwnership();
    }
}
