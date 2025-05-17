// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

interface IMPDexHandler { 

    function swap(address _in, uint256 _amountIn, address _out ) payable external returns (uint256 _amountOut);

}