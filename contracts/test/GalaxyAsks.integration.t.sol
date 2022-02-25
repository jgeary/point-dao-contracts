// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "ds-test/test.sol";

import "../GalaxyAsks.sol";
import "../GalaxyLocker.sol";
import "../Point.sol";
import "../PointGovernor.sol";
import "../PointTreasury.sol";
import "../Vesting.sol";
import "../urbit/Azimuth.sol";
import "../urbit/Claims.sol";
import "../urbit/Ecliptic.sol";
import "../urbit/Polls.sol";
import "../urbit/TreasuryProxy.sol";
import "./utils/MockWallet.sol";
import "./utils/VM.sol";
import "./utils/WETH.sol";
import "../Deployer.sol";

contract GalaxyAsksTest is DSTest {
    // testing tools
    VM internal vm;
    MockWallet internal contributor;
    MockWallet internal galaxyOwner;
    MockWallet internal multisig;
    WETH internal weth;

    // urbit
    Azimuth internal azimuth;
    Polls internal polls;
    Claims internal claims;
    TreasuryProxy internal treasuryProxy;
    Ecliptic internal ecliptic;

    // point dao
    Point internal pointToken;
    PointGovernor internal pointGovernor;
    PointTreasury internal pointTreasury;
    GalaxyAsks internal galaxyAsks;
    GalaxyLocker internal galaxyLocker;
    Vesting internal vesting;

    uint256 constant GOV_SUPPLY = 28444444444444444444440;

    event AskCreated(
        uint256 askId,
        address owner,
        uint8 point,
        uint256 amount,
        uint256 pointAmount
    );

    event AskCanceled(uint256 askId);

    event GalaxySwapped(uint8 point, address owner, address treasury);

    event Contributed(
        address indexed contributor,
        uint256 askId,
        uint256 amount,
        uint256 remainingUnallocatedEth
    );

    event AskSettled(
        uint256 askId,
        address owner,
        uint8 point,
        uint256 amount,
        uint256 pointAmount
    );

    function setUp() public {
        // setup testing tools
        vm = VM(HEVM_ADDRESS);
        weth = new WETH();
        contributor = new MockWallet();
        galaxyOwner = new MockWallet();
        multisig = new MockWallet();

        // setup urbit
        azimuth = new Azimuth();
        polls = new Polls(2592000, 2592000); // these are the current values on mainnet
        claims = new Claims(azimuth);
        treasuryProxy = new TreasuryProxy();
        ecliptic = new Ecliptic(
            address(0),
            azimuth,
            polls,
            claims,
            treasuryProxy
        );
        azimuth.transferOwnership(address(ecliptic));
        polls.transferOwnership(address(ecliptic));
        ecliptic.createGalaxy(0, address(this));
        ecliptic.createGalaxy(1, address(this));
        ecliptic.createGalaxy(2, address(this));
        ecliptic.transferPoint(0, address(galaxyOwner), true);
        ecliptic.transferPoint(1, address(galaxyOwner), true);
        ecliptic.transferPoint(2, address(galaxyOwner), true);

        // deploy point dao
        Deployer d = new Deployer(azimuth, address(multisig), address(weth));
        galaxyLocker = d.galaxyLocker();
        galaxyAsks = d.galaxyAsks();
        pointToken = d.pointToken();
        pointGovernor = d.pointGovernor();
        pointTreasury = d.pointTreasury();
        vesting = d.vesting();
    }

    function test_SwapGalaxy() public {
        assert(pointToken.totalSupply() == GOV_SUPPLY);
        assertEq(pointToken.balanceOf(address(galaxyOwner)), 0);
        vm.startPrank(address(galaxyOwner));
        ecliptic.approve(address(galaxyAsks), 0);
        vm.expectEmit(false, false, false, true);
        emit GalaxySwapped(
            uint8(0),
            address(galaxyOwner),
            address(pointTreasury)
        );
        galaxyAsks.swapGalaxy(0);
        vm.stopPrank();
        assert(pointToken.totalSupply() == GOV_SUPPLY + 1000 * 10**18);
        assertEq(pointToken.balanceOf(address(galaxyOwner)), 1000 * 10**18);
        assertEq(ecliptic.ownerOf(0), address(galaxyLocker));
    }

    function test_SuccessfulAskFlow() public {
        assert(pointToken.totalSupply() == GOV_SUPPLY);
        assertEq(pointToken.balanceOf(address(galaxyOwner)), 0);

        // approve ERC721 transfer and create GalaxyAsk
        vm.startPrank(address(galaxyOwner));
        ecliptic.setApprovalForAll(address(galaxyAsks), true);
        vm.expectEmit(true, true, false, false);
        emit AskCreated(1, address(galaxyOwner), 0, 1 * 10**18, 1 * 10**18);
        galaxyAsks.createAsk(0, 1 * 10**18, 1 * 10**18); // create ask valuing galaxy at 1000 ETH and asking for 1 POINT, leaving 999 ETH unallocated
        vm.stopPrank();

        // governance approves ask
        vm.prank(address(pointTreasury));
        galaxyAsks.approveAsk(1);

        // contributor contributes ETH to ask (full remaining amount so ask is settled)
        vm.deal(address(contributor), 999 * 10**18);
        vm.startPrank(address(contributor));
        vm.expectEmit(true, false, false, true);
        emit Contributed(address(contributor), 1, 999 * 10**18, 0);
        vm.expectEmit(false, false, false, true);
        emit AskSettled(1, address(galaxyOwner), 0, 999 * 10**18, 1 * 10**18);
        galaxyAsks.contribute{value: 999 * 10**18}(1, 999 * 10**18);
        assertEq(ecliptic.ownerOf(0), address(galaxyLocker)); // make sure point treasury gets galaxy
        assertEq(address(galaxyOwner).balance, 999 * 10**18); // galaxy owner gets ETH
        assert(pointToken.totalSupply() == GOV_SUPPLY + 1 * 10**18);
        assertEq(pointToken.balanceOf(address(galaxyOwner)), 1 * 10**18); // galaxyOwner gets correct amount of POINT

        // contributor claims POINT
        galaxyAsks.claim(1);
        vm.stopPrank();

        assert(pointToken.totalSupply() == GOV_SUPPLY + 1000 * 10**18);
        assertEq(pointToken.balanceOf(address(contributor)), 999 * 10**18); // contributor gets POINT

        // galaxy owner creates another ask and cancels it
        vm.startPrank(address(galaxyOwner));
        vm.expectEmit(true, true, false, false);
        emit AskCreated(2, address(galaxyOwner), 1, 1 * 10**18, 1 * 10**18);
        galaxyAsks.createAsk(1, 1 * 10**18, 1 * 10**18);
        vm.expectEmit(true, true, false, false);
        emit AskCanceled(2);
        galaxyAsks.cancelAsk(2);
        vm.stopPrank();
    }
}
