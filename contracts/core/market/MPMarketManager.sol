// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import "../../interfaces/market/IMPMarketManager.sol";

import "../../interfaces/util/IRegister.sol"; 
import "../../interfaces/util/IVersion.sol"; 
import "../../interfaces/util/IMPTxManager.sol"; 

import "../../interfaces/util/IMPTxManager.sol";
import "../../interfaces/util/IMPBondManager.sol";  

import "../../structs/MPStructs.sol";

import "../../lib/MPLib.sol";

contract MarketManager is IMPMarketManager, IVersion { 

    string constant name       = "RESERVED_MP_MARKET_MANAGER"; 
    uint256 constant version  = 1; 

    address constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    string constant TX_MANAGER_CA   = "RESERVED_MP_TX_MANAGER";
    string constant BOND_MANAGER_CA = "RESERVED_BOND_MANAGER";
    string constant UNISWAP_CA      = "RESERVED_UNISWAP";

    address immutable self; 

    uint256 index; 

    IRegister register; 
    uint256 [] marketIds; 
    mapping(uint256=>bool) isKnownMarket;
    mapping(uint256=>Market) marketById;  
    mapping(uint256=>uint256[]) positionIdsByBondId; 
    mapping(uint256=>bool) hasMarketByBondId; 

    address [] allowedMarketTokens; 
    mapping(address=>bool) isAllowedMarketToken; 

    constructor(address _register)  { 
        register = IRegister(_register);
        self = address(this);
    }

    function getName() pure external returns (string memory _name) { 
        return name; 
    }

    function getVersion() pure external returns (uint256 _version){ 
        return version; 
    }

    function getAllowedMarketTokens() view external returns (address [] memory _erc20){
        return allowedMarketTokens; 
    }
    
    function getMarkets() view external returns (uint256 [] memory _marketIds){
        return marketIds; 
    }

    function getMarket(uint256 _marketId) view external returns (Market memory _market){
        return marketById[_marketId];
    }

    function hasOpenPositions(uint256 _marketBondId) view external returns (bool _hasOpenPositions){
        return positionIdsByBondId[_marketBondId].length != 0; 
    }

    function createMarket(  address _fromToken, 
                            address _toToken, 
                            uint256 _minDuration, 
                            uint256 _maxDuration, 
                            uint256 _minReturn, 
                            uint256 _maxReturn, 
                            RiskType _riskType,
                            uint256 _maxInvestmentSlots, 
                            uint256 _marketBondId, 
                            uint256 _maxMarketTerm) payable external returns (uint256 _marketId, uint256 _txId){
        
        SecurityBond memory bond_ = IMPBondManager(register.getAddress(BOND_MANAGER_CA)).getUserBond(BondType.MARKET, msg.sender);
        require(_marketBondId == bond_.id, "bond id mis-match");
        require(!hasMarketByBondId[bond_.id], "bond already set against market");

        _marketId = getIndex(); 
        marketIds.push(_marketId);
        isKnownMarket[_marketId] = true; 
        marketById[_marketId] = Market({
                                        id : _marketId,  
                                        owner : msg.sender,  
                                        riskType : _riskType, 
                                        fromToken : _fromToken, 
                                        toToken : _toToken, 
                                        minDuration : _minDuration,  
                                        maxDuration : _maxDuration,  
                                        minReturn : _minReturn,  
                                        maxReturn : _maxReturn,  
                                        maxSlots : _maxInvestmentSlots,  
                                        bondId : _marketBondId, 
                                        createDate : block.timestamp,  
                                        expiryDate : block.timestamp + _maxMarketTerm,  
                                        finalExitDate : block.timestamp + _maxMarketTerm + _maxDuration
                                      });
        return (_marketId, _txId); 
    }
    


    function openPosition(uint256 _marketId, uint256 _positionId, uint256 _amount) payable external returns (uint256 _txId){

    }

    function closePosition(uint256 _marketId, uint256 _positionId) external returns (uint256 _returnAmount, uint256 _txId){

    }

    function closeMarket(uint256 _marketId) external returns (uint256 _txId){

    }
    //=================================================== INTERNAL ====================================================================
    
    function getIndex() internal returns (uint256 _index){
        _index = index++; 
        return _index; 
    }

    function addTx(TxType _txType, ObjType _objType, uint256 _id, uint256 _amount, address _erc20) internal returns (uint256 _txId){
         return IMPTxManager(register.getAddress(TX_MANAGER_CA)).addTx(_txType, _objType, _id, self, _amount, _erc20); 
    }

}
