// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/finance/VestingWallet.sol";
import "./PointTreasury.sol";

contract Vesting is VestingWallet {
    uint64 constant SECONDS_IN_YEAR = 365 * 24 * 60 * 60;
    uint64 constant VESTING_DURATION = 8 * SECONDS_IN_YEAR;

    // start vesting in one year, vest for 7 years
    constructor(PointTreasury _treasury)
        VestingWallet(
            address(_treasury),
            uint64(block.timestamp),
            VESTING_DURATION
        )
    {}
}
