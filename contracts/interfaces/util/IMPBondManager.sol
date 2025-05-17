
// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import {SecurityBond, BondType} from "../../structs/MPStructs.sol";

interface IMPBondManager { 

    function hasBond(BondType _type, address _user) view external returns (bool _hasBondType);

    function getUserBond(BondType _type, address _user) view external returns (SecurityBond memory _bond);
    
    function getBondById(uint256 _bondId) view external returns (SecurityBond memory _bond); 
    
    function placeBond(BondType _type, uint256 _amount, address _erc20) payable external returns (uint256 _bondId, uint256 _txId);

    function releaseBond(uint256 _bondId) external returns (uint256 _txId);
}