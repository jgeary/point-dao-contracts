// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "ds-test/test.sol";

import "../GalaxyAsks.sol";
import "../GalaxyLocker.sol";
import "../Point.sol";
import "../PointGovernor.sol";
import "../PointTreasury.sol";
import "../urbit/Azimuth.sol";
import "../urbit/Claims.sol";
import "../urbit/Ecliptic.sol";
import "../urbit/Polls.sol";
import "../urbit/TreasuryProxy.sol";
import "./utils/MockWallet.sol";
import "./utils/VM.sol";
import "./utils/WETH.sol";

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
    GalaxyLocker internal galaxyLocker;

    uint256 constant GOV_SUPPLY = 28444444444444444444444;

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
        pointGovernor = new PointGovernor(pointToken, pointTreasury);

        // deploy galaxy managers
        galaxyLocker = new GalaxyLocker(
            pointToken,
            azimuth,
            address(pointTreasury)
        );
        galaxyAsks = new GalaxyAsks(
            azimuth,
            address(multisig),
            pointToken,
            galaxyLocker,
            payable(address(pointTreasury))
        );

        // do initial mint and roles, renounce ownership
        pointToken.mintTreasuryAndDesignateRoles(
            address(pointTreasury),
            galaxyAsks,
            galaxyLocker
        );
        pointToken.renounceOwnership();
    }

    function test_SwapGalaxy() public {
        // none minted other than 10% for treasury
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
