
// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import {Tx, TxType, ObjType} from "../../structs/MPStructs.sol";

interface IMPTxManager {  

    function getTx(uint256 _txId) view external returns (Tx memory _tx); 

    function getMPensionTx(uint256 _mPensionId) view external returns (uint256 []  memory _txIds); 

    function addTx(TxType _txType, ObjType _objType, uint256 _id, address location, uint256 _amount, address _erc20) external returns (uint256 _txId); 

}

