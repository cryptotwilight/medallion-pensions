// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;


interface  IMPVaultFactory { 

    function createVault(uint256 _mPensionId) external returns (address _mPensionVault); 

}