
// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

interface IVersion { 

    function getName() view external returns (string memory _name); 

    function getVersion() view external returns (uint256 _version); 

}