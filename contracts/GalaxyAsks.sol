/*
 ________  ________  ___  ________   _________        ________  ________  ________                                           
|\   __  \|\   __  \|\  \|\   ___  \|\___   ___\     |\   ___ \|\   __  \|\   __  \                                          
\ \  \|\  \ \  \|\  \ \  \ \  \\ \  \|___ \  \_|     \ \  \_|\ \ \  \|\  \ \  \|\  \                                         
 \ \   ____\ \  \\\  \ \  \ \  \\ \  \   \ \  \       \ \  \ \\ \ \   __  \ \  \\\  \                                        
  \ \  \___|\ \  \\\  \ \  \ \  \\ \  \   \ \  \       \ \  \_\\ \ \  \ \  \ \  \\\  \                                       
   \ \__\    \ \_______\ \__\ \__\\ \__\   \ \__\       \ \_______\ \__\ \__\ \_______\                                      
    \|__|     \|_______|\|__|\|__| \|__|    \|__|        \|_______|\|__|\|__|\|_______|                                      
                                                                                                                             
                                                                                                                             
                                                                                                                             
 ________  ________  ___       ________     ___    ___ ___    ___      ________  ________  ________  _________    ___    ___ 
|\   ____\|\   __  \|\  \     |\   __  \   |\  \  /  /|\  \  /  /|    |\   __  \|\   __  \|\   __  \|\___   ___\ |\  \  /  /|
\ \  \___|\ \  \|\  \ \  \    \ \  \|\  \  \ \  \/  / | \  \/  / /    \ \  \|\  \ \  \|\  \ \  \|\  \|___ \  \_| \ \  \/  / /
 \ \  \  __\ \   __  \ \  \    \ \   __  \  \ \    / / \ \    / /      \ \   ____\ \   __  \ \   _  _\   \ \  \   \ \    / / 
  \ \  \|\  \ \  \ \  \ \  \____\ \  \ \  \  /     \/   \/  /  /        \ \  \___|\ \  \ \  \ \  \\  \|   \ \  \   \/  /  /  
   \ \_______\ \__\ \__\ \_______\ \__\ \__\/  /\   \ __/  / /           \ \__\    \ \__\ \__\ \__\\ _\    \ \__\__/  / /    
    \|_______|\|__|\|__|\|_______|\|__|\|__/__/ /\ __\\___/ /             \|__|     \|__|\|__|\|__|\|__|    \|__|\___/ /     
                                           |__|/ \|__\|___|/                                                    \|___|/      
                                                                                                                             
                                                                                                                                                            ~~                        ~~
Author: James Geary
Credit: adapted from PartyBid by Anna Carroll
*/

// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import {IAzimuth} from "./IAzimuth.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract GalaxyAsks is Context {
    enum AskStatus {
        NONE,
        CREATED,
        APPROVED,
        CANCELED,
        ENDED
    }

    struct Ask {
        address owner;
        uint256 amount;
        uint256 pointAmount;
        uint256 totalContributedToParty;
        uint32 point;
        AskStatus status;
    }

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

    using Counters for Counters.Counter;
    Counters.Counter private askIds;
    uint256 public lastApprovedAskId;

    mapping(uint256 => Ask) asks;

    // ask id -> address -> total contributed
    mapping(uint256 => mapping(address => uint256)) totalContributed;

    // ask id -> whether user has claimed yet
    mapping(uint256 => mapping(address => bool)) public claimed;

    // example: seller values galaxy at 597 eth and asks for 1 point. so 1 point == 0.597 eth, and 596.403 ETH remain unallocated. contributions must be in 0.001 POINT equivalent increments, so 0.000597 ETH increments in this case.
    uint256 constant POINT_PER_GALAXY = 1000 * (10**18); // 1000 POINT are distributed for each galaxy sale
    uint256 constant SELLER_POINT_INCREMENT = 10**18; // seller can only ask for whole number of POINT and value galaxy in whole number of ETH
    uint256 constant SELLER_ETH_PER_POINT_INCREMENT = 10**15; // seller can only price 1 POINT in 0.001 ETH increments
    uint256 constant CONTRIBUTOR_POINT_INCREMENT = 10**15; // contributions must be valued in 0.001 POINT increments

    address public azimuth;
    address public ecliptic;
    address public multisig;
    address public pointToken;
    address public treasury;

    constructor(
        address _azimuth,
        address _ecliptic,
        address _multisig,
        address _pointToken,
        address _treasury
    ) {
        azimuth = _azimuth;
        ecliptic = _ecliptic;
        multisig = _multisig;
        pointToken = _pointToken;
        treasury = _treasury;
        askIds.increment();
    }

    modifier onlyGovernance() {
        require(_msgSender() == treasury || _msgSender() == multisig);
        _;
    }

    function setAzimuth(address _azimuth) public onlyGovernance {
        azimuth = _azimuth;
    }

    function setEcliptic(address _ecliptic) public onlyGovernance {
        ecliptic = _ecliptic;
    }

    function setMultisig(address _multisig) public onlyGovernance {
        multisig = _multisig;
    }

    function setPointToken(address _pointToken) public onlyGovernance {
        pointToken = _pointToken;
    }

    function setTreasury(address _treasury) public onlyGovernance {
        treasury = _treasury;
    }

    function swapGalaxy(uint32 _point) public {
        require(
            IERC721(ecliptic).ownerOf(uint256(_point)) == _msgSender(),
            "caller must own azimuth point"
        );
        require(
            IAzimuth(azimuth).getPointSize(_point) == IAzimuth.Size.Galaxy,
            "point must be a galaxy"
        );
        IERC721(ecliptic).safeTransferFrom(
            _msgSender(),
            address(treasury),
            uint256(_point)
        );
        IERC20(pointToken).transfer(_msgSender(), POINT_PER_GALAXY);
        emit GalaxySwapped(_point, _msgSender(), address(treasury));
    }

    // galaxy owner lists token for sale
    function createAsk(
        uint32 _point,
        uint256 _ethPerPoint, // eth value of 1*10**18 POINT, must be in 0.001 ETH increments
        uint256 _pointAmount // POINT for seller, must be in 1 POINT increments
    ) public {
        require(
            IERC721(ecliptic).ownerOf(uint256(_point)) == _msgSender(),
            "caller must own azimuth point"
        );
        require(
            IAzimuth(azimuth).getPointSize(_point) == IAzimuth.Size.Galaxy,
            "azimuth point must be a galaxy"
        );
        require(
            _pointAmount < POINT_PER_GALAXY,
            "_pointAmount must be less than POINT_PER_GALAXY"
        );
        require(
            _pointAmount % SELLER_POINT_INCREMENT == 0,
            "seller can only ask for whole number of POINT"
        );
        require(_ethPerPoint > 0, "eth per point must be greater than 0");
        require(
            _ethPerPoint % SELLER_ETH_PER_POINT_INCREMENT == 0,
            "eth per point must be in 0.001 ETH increments"
        );

        uint256 _amount = ((POINT_PER_GALAXY - _pointAmount) / 10**18) *
            _ethPerPoint; // amount unallocated ETH
        address owner = _msgSender();
        uint256 askId = askIds.current();
        asks[askId] = Ask(
            owner,
            _amount,
            _pointAmount,
            0,
            _point,
            AskStatus.CREATED
        );

        askIds.increment();
        emit AskCreated(askId, owner, _point, _amount, _pointAmount);
    }

    function cancelAsk(uint256 _askId) public {
        require(
            asks[_askId].status == AskStatus.CREATED ||
                asks[_askId].status == AskStatus.APPROVED,
            "ask must be created or approved"
        );
        require(
            _msgSender() == treasury ||
                _msgSender() == multisig ||
                _msgSender() == asks[_askId].owner ||
                _msgSender() ==
                IERC721(ecliptic).ownerOf(uint256(asks[_askId].point))
        );
        asks[_askId].status = AskStatus.CANCELED;
        emit AskCanceled(_askId);
    }

    function approveAsk(uint256 _askId) public {
        require(
            asks[_askId].status == AskStatus.CREATED,
            "ask must be in created state"
        );
        require(
            asks[lastApprovedAskId].status == AskStatus.NONE ||
                asks[lastApprovedAskId].status == AskStatus.CANCELED ||
                asks[lastApprovedAskId].status == AskStatus.ENDED,
            "there is a previously approved ask that is not canceled/ended."
        );
        require(
            IERC20(pointToken).balanceOf(address(this)) > POINT_PER_GALAXY,
            "GalaxyAsks needs at least 1000 POINT to approve an ask"
        );
        asks[_askId].status = AskStatus.APPROVED;
        lastApprovedAskId = _askId;
    }

    function contribute(uint256 _askId, uint256 _pointAmount) public payable {
        // if galaxy owner does not own token anymore, cancel ask and refund current contributor
        require(
            asks[_askId].status == AskStatus.APPROVED &&
                lastApprovedAskId == _askId,
            "ask must be in approved state"
        );
        if (
            asks[_askId].owner !=
            IERC721(ecliptic).ownerOf(uint256(asks[_askId].point))
        ) {
            asks[_askId].status = AskStatus.CANCELED;
            (bool success, ) = _msgSender().call{value: msg.value}("");
            require(success, "wallet failed to receive");
            return;
        }
        require(
            _pointAmount > 0 && _pointAmount % CONTRIBUTOR_POINT_INCREMENT == 0,
            "point amount must be greater than 0 and in increments of 0.001"
        );
        uint256 _ethPerPoint = asks[_askId].amount /
            (POINT_PER_GALAXY - asks[_askId].pointAmount);
        uint256 _amount = msg.value;
        require(
            _amount == _pointAmount * _ethPerPoint,
            "msg.value needs to match pointAmount"
        );
        require(
            _amount <=
                asks[_askId].amount - asks[_askId].totalContributedToParty,
            "cannot exceed asking price"
        );
        address _contributor = _msgSender();
        // add to contributor's total contribution
        totalContributed[_askId][_contributor] =
            totalContributed[_askId][_contributor] +
            _amount;
        // add to party's total contribution & emit event
        asks[_askId].totalContributedToParty =
            asks[_askId].totalContributedToParty +
            _amount;
        emit Contributed(
            _contributor,
            _askId,
            _amount,
            asks[_askId].amount - asks[_askId].totalContributedToParty
        );
        if (asks[_askId].totalContributedToParty == asks[_askId].amount) {
            settleAsk(_askId);
        }
    }

    function settleAsk(uint256 _askId) internal {
        require(asks[_askId].status == AskStatus.APPROVED);
        require(asks[_askId].amount == asks[_askId].totalContributedToParty);
        asks[_askId].status = AskStatus.ENDED;
        IERC721(ecliptic).transferFrom(
            asks[_askId].owner,
            treasury,
            uint256(asks[_askId].point)
        );
        (bool success, ) = asks[_askId].owner.call{value: asks[_askId].amount}(
            ""
        );
        require(success, "wallet failed to receive");
        IERC20(pointToken).transfer(
            asks[_askId].owner,
            asks[_askId].pointAmount
        );
        emit AskSettled(
            _askId,
            asks[_askId].owner,
            asks[_askId].point,
            asks[_askId].amount,
            asks[_askId].pointAmount
        );
    }

    function claim(uint256 _askId) public {
        require(
            asks[_askId].status == AskStatus.ENDED ||
                asks[_askId].status == AskStatus.CANCELED
        );
        require(totalContributed[_askId][_msgSender()] > 0);
        require(!claimed[_askId][_msgSender()]);
        claimed[_askId][_msgSender()] = true;
        if (asks[_askId].status == AskStatus.ENDED) {
            uint256 _pointAmount = (totalContributed[_askId][_msgSender()] /
                asks[_askId].amount) *
                (POINT_PER_GALAXY - asks[_askId].pointAmount);
            IERC20(pointToken).transfer(_msgSender(), _pointAmount);
        } else if (asks[_askId].status == AskStatus.CANCELED) {
            uint256 _ethAmount = totalContributed[_askId][_msgSender()];
            (bool success, ) = _msgSender().call{value: _ethAmount}("");
            require(success, "wallet failed to receive");
        }
    }
}
