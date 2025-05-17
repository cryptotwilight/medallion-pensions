
// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;


interface IRegister { 

    function isKnown(address _address) view external returns (bool _isKnown); 

    function hasAddress(string memory name) view external returns (bool _hasAddress);

    function getAddress(string memory _name) view external returns (address _address); 

}