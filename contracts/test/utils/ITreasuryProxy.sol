pragma solidity 0.8.10;

interface ITreasuryProxy {
    function upgradeTo(address _impl) external returns (bool);

    function freeze() external returns (bool);
}
