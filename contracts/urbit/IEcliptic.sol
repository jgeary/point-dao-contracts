// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import {EclipticBase} from "./EclipticBase.sol";

interface IEcliptic {
    function setManagementProxy(uint32 _point, address _manager) external;

    function setSpawnProxy(uint16 _prefix, address _spawnProxy) external;

    function setVotingProxy(uint8 _galaxy, address _voter) external;

    function castDocumentVote(
        uint8 _galaxy,
        bytes32 _proposal,
        bool _vote
    ) external;

    function castUpgradeVote(
        uint8 _galaxy,
        EclipticBase _proposal,
        bool _vote
    ) external;
}
