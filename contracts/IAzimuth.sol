pragma solidity 0.8.10;

interface IAzimuth {
    enum Size {
        Galaxy, // = 0
        Star, // = 1
        Planet // = 2
    }

    function getPointSize(uint32 _point) external pure returns (Size _size);
}
