// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import "../structs/MPStructs.sol"; 

interface IMedallionPensions { 

    function getFee(string memory _feeName) view external returns (uint256 _amount); 

    function getPension(uint256 _id) view external returns (MPension memory _pension); 

    function getPension() view external returns (MPension memory _pension); 

    function createPension(ProtoPension memory _pPension) payable external returns (address _vault, uint256 _txId);

}