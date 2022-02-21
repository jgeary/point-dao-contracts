// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {DSTest} from "ds-test/test.sol";
import {VM} from "./utils/VM.sol";
import {MockWallet} from "./utils/MockWallet.sol";
import {Azimuth} from "./utils/Azimuth.sol";
import {Polls} from "./utils/Polls.sol";
import {Claims} from "./utils/Claims.sol";
import {Ecliptic} from "./utils/Ecliptic.sol";
import {TreasuryProxy} from "./utils/TreasuryProxy.sol";
import {GalaxyAsks} from "../GalaxyAsks.sol";
import {Point} from "../Point.sol";
import {PointGovernor} from "../PointGovernor.sol";
import {PointTreasury} from "../PointTreasury.sol";
import {WETH} from "./utils/WETH.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract GalaxyAsksTest is DSTest {
    VM internal vm;
    Azimuth internal azimuth;
    Polls internal polls;
    Claims internal claims;
    TreasuryProxy internal treasuryProxy;
    Ecliptic internal ecliptic;
    Point internal pointToken;
    PointGovernor internal pointGovernor;
    PointTreasury internal pointTreasury;
    WETH internal weth;
    MockWallet internal contributor;
    MockWallet internal galaxyOwner;
    MockWallet internal multisig;
    GalaxyAsks internal galaxyAsks;

    event AskCreated(
        uint256 askId,
        address owner,
        uint32 point,
        uint256 amount,
        uint256 pointAmount
    );

    event AskCanceled(uint256 askId);

    event GalaxySwapped(uint32 point, address owner, address treasury);

    event Contributed(
        address indexed contributor,
        uint256 askId,
        uint256 amount,
        uint256 remainingUnallocatedEth
    );

    event AskSettled(
        uint256 askId,
        address owner,
        uint32 point,
        uint256 amount,
        uint256 pointAmount
    );

    function setUp() public {
        // setup smart contract testing tools
        vm = VM(HEVM_ADDRESS);

        // deploy urbit contracts
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

        // mock wallets
        contributor = new MockWallet();
        galaxyOwner = new MockWallet();
        multisig = new MockWallet();

        // give galaxies to galaxyOwner
        ecliptic.createGalaxy(0, address(this));
        ecliptic.createGalaxy(1, address(this));
        ecliptic.createGalaxy(2, address(this));
        ecliptic.transferPoint(0, address(galaxyOwner), true);
        ecliptic.transferPoint(1, address(galaxyOwner), true);
        ecliptic.transferPoint(2, address(galaxyOwner), true);

        // deploy point governance contracts - PointTreasury owns PointGovernor and Point is the governance token.
        weth = new WETH(); // treasury needs to use weth instead of eth
        pointToken = new Point(); // openzeppelin erc20 vote token
        address[] memory proposers = new address[](1);
        proposers[0] = address(this);
        address[] memory executors = new address[](1);
        executors[0] = address(this);
        pointTreasury = new PointTreasury(
            86400, // one day timelock
            proposers,
            executors,
            address(weth)
        );
        pointToken.transfer(address(pointTreasury), 271_600 * 10**18); // give most POINT to treasury
        pointGovernor = new PointGovernor(pointToken, pointTreasury);

        // deploy GalaxyAsks and give it remaining POINT
        galaxyAsks = new GalaxyAsks(
            address(azimuth),
            address(ecliptic),
            address(multisig),
            address(pointToken),
            address(pointTreasury)
        );
        pointToken.transfer(address(galaxyAsks), 10_000 * 10**18); // give some POINT to GalaxyAsks
    }

    function test_SwapGalaxy() public {
        assertEq(pointToken.balanceOf(address(galaxyOwner)), 0);
        vm.startPrank(address(galaxyOwner));
        ecliptic.approve(address(galaxyAsks), 0);
        vm.expectEmit(false, false, false, true);
        emit GalaxySwapped(
            uint32(0),
            address(galaxyOwner),
            address(pointTreasury)
        );
        galaxyAsks.swapGalaxy(0);
        vm.stopPrank();

        assertEq(pointToken.balanceOf(address(galaxyOwner)), 1000 * 10**18);
        assertEq(ecliptic.ownerOf(0), address(pointTreasury));
    }

    function test_SuccessfulAskFlow() public {
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
        assertEq(ecliptic.ownerOf(0), address(pointTreasury)); // make sure point treasury gets galaxy
        assertEq(address(galaxyOwner).balance, 999 * 10**18); // galaxy owner gets ETH
        assertEq(pointToken.balanceOf(address(galaxyOwner)), 1 * 10**18); // galaxyOwner gets correct amount of POINT

        // contributor claims POINT
        galaxyAsks.claim(1);
        assertEq(pointToken.balanceOf(address(contributor)), 999 * 10**18); // contributor gets POINT
        vm.stopPrank();

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

    // TODO: test treasury can vote on urbit proposals
    // TODO: test every fail case imaginable
}
