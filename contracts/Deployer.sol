// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./GalaxyLocker.sol";
import "./GalaxyAsks.sol";
import "./Point.sol";
import "./PointGovernor.sol";
import "./PointTreasury.sol";
import "./Vesting.sol";

/* Deploys entire protocol atomically */
contract Deployer {
    GalaxyLocker public galaxyLocker;
    GalaxyAsks public galaxyAsks;
    Point public pointToken;
    PointGovernor public pointGovernor;
    PointTreasury public pointTreasury;
    Vesting public vesting;

    constructor(
        Ownable azimuth,
        address multisig,
        address weth
    ) {
        // token
        pointToken = new Point();

        // governance
        address[] memory proposers = new address[](1);
        proposers[0] = multisig;
        address[] memory executors = new address[](1);
        executors[0] = multisig;
        pointTreasury = new PointTreasury(86400, proposers, executors, weth);
        vesting = new Vesting(pointTreasury);
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

        // initialize token
        pointToken.init(pointTreasury, vesting, galaxyAsks, galaxyLocker);
    }
}
