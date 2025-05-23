// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

interface IMPOracle { 

    function getPrice(address _base) external returns (uint256 _price);

}