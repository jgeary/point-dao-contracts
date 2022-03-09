// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

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
        address azimuth,
        address multisig,
        address weth
    ) {
        // token
        pointToken = new Point();

        // governance
        address[] memory empty = new address[](0);
        pointTreasury = new PointTreasury(86400, empty, empty, weth);
        pointGovernor = new PointGovernor(pointToken, pointTreasury);
        pointTreasury.grantRole(
            pointTreasury.PROPOSER_ROLE(),
            address(pointGovernor)
        );
        pointTreasury.grantRole(
            pointTreasury.EXECUTOR_ROLE(),
            address(pointGovernor)
        );
        pointTreasury.grantRole(
            pointTreasury.CANCELLER_ROLE(),
            address(pointGovernor)
        );
        pointTreasury.grantRole(
            pointTreasury.CANCELLER_ROLE(),
            address(multisig)
        );
        pointTreasury.revokeRole(
            pointTreasury.TIMELOCK_ADMIN_ROLE(),
            address(pointTreasury)
        );
        pointTreasury.revokeRole(
            pointTreasury.TIMELOCK_ADMIN_ROLE(),
            address(this)
        );

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
        vesting = new Vesting(pointTreasury);
        pointToken.init(pointTreasury, vesting, galaxyAsks, galaxyLocker);
    }
}
