// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import {Market, RiskType} from "../../structs/MPStructs.sol";

interface IMPMarketManager {
    
    function getAllowedMarketTokens() view external returns (address [] memory _erc20); 
    
    function getMarkets() view external returns (uint256 [] memory marketIds);

    function getMarket(uint256 _marketId) view external returns (Market memory _market);

    function createMarket(  address _fromToken, 
                            address _toToken, 
                            uint256 _minDuration, 
                            uint256 _maxDuration, 
                            uint256 _minReturn, 
                            uint256 _maxReturn, 
                            RiskType _riskType,
                            uint256 _maxInvestmentSlots, 
                            uint256 _marketBondId, 
                            uint256 _maxMarketTerm) payable external returns (uint256 _marketId, uint256 _txId);
    
    function hasOpenPositions(uint256 _marketBondId) view external returns (bool _hasOpenPositions); 

    function openPosition(uint256 _marketId, uint256 _positionId, uint256 _amount) payable external returns (uint256 _txId); 

    function closePosition(uint256 _marketId, uint256 _positionId) external returns (uint256 _returnAmount, uint256 _txId); 

    function closeMarket(uint256 _marketId) external returns (uint256 _txId);
    
}