pragma solidity 0.8.10;

contract TreasuryProxy {
    function upgradeTo(address _impl) external returns (bool) {
        return true;
    }

    function freeze() external returns (bool) {
        return true;
    }
}
