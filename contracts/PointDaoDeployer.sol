// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./GalaxyAsks.sol";
import "./Point.sol";
import "./PointGovernor.sol";
import "./PointTreasury.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/* Deploys entire protocol atomically */
contract PointDaoDeployer is Ownable {
    GalaxyAsks internal galaxyAsks;
    Point internal pointToken;
    PointGovernor internal pointGovernor;
    PointTreasury internal pointTreasury;
    address internal azimuth;
    address internal ecliptic;
    address internal multisig;
    address internal weth;
    uint256 constant TEN_PERCENT_MAX_SUPPLY = 28444444444444444444444;

    event Deployed(
        address galaxyAsks,
        address pointToken,
        address pointGovernor,
        address pointTreasury
    );

    constructor(
        address _azimuth,
        address _ecliptic,
        address _multisig,
        address _weth
    ) {
        azimuth = _azimuth;
        ecliptic = _ecliptic;
        multisig = _multisig;
        weth = _weth;
    }

    function deploy() public onlyOwner {
        // token
        pointToken = new Point();

        // governance
        address[] memory proposers = new address[](1);
        proposers[0] = address(multisig);
        address[] memory executors = new address[](1);
        executors[0] = address(multisig);
        pointTreasury = new PointTreasury(86400, proposers, executors, weth);
        pointGovernor = new PointGovernor(pointToken, pointTreasury);

        // galaxy asks
        galaxyAsks = new GalaxyAsks(
            address(azimuth),
            address(ecliptic),
            address(multisig),
            address(pointToken),
            payable(address(pointTreasury))
        );

        // distribute 10% max supply to treasury
        pointToken.mint(address(pointTreasury), TEN_PERCENT_MAX_SUPPLY);

        // give galaxy asks permission to mint remainder of supply
        pointToken.setMinter(address(galaxyAsks));

        pointToken.transferOwnership(address(pointTreasury));

        emit Deployed(
            address(galaxyAsks),
            address(pointToken),
            address(pointGovernor),
            address(pointTreasury)
        );
    }
}
