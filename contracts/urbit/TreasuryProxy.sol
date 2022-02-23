pragma solidity 0.8.10;

import {ITreasuryProxy} from "./ITreasuryProxy.sol";

contract TreasuryProxy is ITreasuryProxy {
    function upgradeTo(address _impl) external returns (bool) {
        return true;
    }

    function freeze() external returns (bool) {
        return true;
    }
}
