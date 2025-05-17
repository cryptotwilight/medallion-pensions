
// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import {MPension} from "../structs/MPStructs.sol";


interface IMPensionVault { 

    function getPension() view external returns (MPension memory _mPension); 

    function getBalance() view external returns (uint256 _balance); 

    function contribute(uint256 _amount) payable external returns (uint256 _tx);

    function drawdown() external returns (uint256 _tx); 

    function close() external returns (uint256 _tx);

    function pull(uint256 treasuryId) external returns (uint256 _amount, uint256 _tx); 

    function push(uint256 treasuryId, uint256 _principal, uint256 _earnings) payable external returns (uint256 _tx);

}